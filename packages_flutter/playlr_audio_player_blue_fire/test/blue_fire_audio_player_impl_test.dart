import 'dart:async';

import 'package:audioplayers_platform_interface/audioplayers_platform_interface.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playlr_audio_player_blue_fire/src/player/blue_fire_audio_player_impl.dart';

/// No native player: events are sent by the test.
class _FakeAudioplayersPlatform extends AudioplayersPlatformInterface {
  final _events = <String, StreamController<AudioEvent>>{};

  /// When false, a source is prepared only when the test calls [prepare].
  var autoPrepare = true;

  /// The error the native side reports when a source is set.
  Object? sourceError;

  StreamController<AudioEvent> _eventController(String playerId) =>
      _events[playerId] ??= StreamController<AudioEvent>.broadcast();

  /// Send a native event for [playerId].
  void addEvent(String playerId, AudioEvent event) =>
      _eventController(playerId).add(event);

  /// The native player of [playerId] is ready to play its source.
  void prepare(String playerId) => addEvent(
    playerId,
    const AudioEvent(eventType: AudioEventType.prepared, isPrepared: true),
  );

  void _sourceSet(String playerId) {
    var error = sourceError;
    if (error != null) {
      _eventController(playerId).addError(error);
    } else if (autoPrepare) {
      prepare(playerId);
    }
  }

  @override
  Stream<AudioEvent> getEventStream(String playerId) =>
      _eventController(playerId).stream;

  @override
  Future<void> create(String playerId) async {}

  @override
  Future<void> dispose(String playerId) async {}

  @override
  Future<void> emitError(String playerId, String code, String message) async {}

  @override
  Future<void> emitLog(String playerId, String message) async {}

  @override
  Future<int?> getCurrentPosition(String playerId) async => null;

  /// Never known when asked, only through events.
  @override
  Future<int?> getDuration(String playerId) async => null;

  @override
  Future<void> pause(String playerId) async {}

  @override
  Future<void> release(String playerId) async {}

  @override
  Future<void> resume(String playerId) async {}

  @override
  Future<void> seek(String playerId, Duration position) async {}

  @override
  Future<void> setAudioContext(
    String playerId,
    AudioContext audioContext,
  ) async {}

  @override
  Future<void> setBalance(String playerId, double balance) async {}

  @override
  Future<void> setPlaybackRate(String playerId, double playbackRate) async {}

  @override
  Future<void> setPlayerMode(String playerId, PlayerMode playerMode) async {}

  @override
  Future<void> setReleaseMode(String playerId, ReleaseMode releaseMode) async {}

  @override
  Future<void> setSourceBytes(
    String playerId,
    Uint8List bytes, {
    String? mimeType,
  }) async => _sourceSet(playerId);

  @override
  Future<void> setSourceUrl(
    String playerId,
    String url, {
    bool? isLocal,
    String? mimeType,
  }) async => _sourceSet(playerId);

  @override
  Future<void> setVolume(String playerId, double volume) async {}

  @override
  Future<void> stop(String playerId) async {}
}

class _FakeGlobalAudioplayersPlatform
    implements GlobalAudioplayersPlatformInterface {
  @override
  Future<void> emitGlobalError(String code, String message) async {}

  @override
  Future<void> emitGlobalLog(String message) async {}

  @override
  Stream<GlobalAudioEvent> getGlobalEventStream() => const Stream.empty();

  @override
  Future<void> init() async {}

  @override
  Future<void> setGlobalAudioContext(AudioContext ctx) async {}
}

/// Bytes source set directly (no temp file).
class _BytesPlayer extends BlueFireAudioPlayerImpl {
  _BytesPlayer() : super.fromBytes(Uint8List.fromList([1, 2, 3]));

  @override
  bool get useIo => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _FakeAudioplayersPlatform platform;
  setUp(() {
    platform = _FakeAudioplayersPlatform();
    AudioplayersPlatformInterface.instance = platform;
    GlobalAudioplayersPlatformInterface.instance =
        _FakeGlobalAudioplayersPlatform();
    // Linux sets the bytes through a temp file (path_provider)
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  AudioEvent durationEvent(Duration duration) =>
      AudioEvent(eventType: AudioEventType.duration, duration: duration);

  group('BlueFireAudioPlayerImpl', () {
    test('duration event', () async {
      var player = _BytesPlayer();
      await pumpEventQueue();
      expect(player.stateValue.duration, isNull);
      platform.addEvent(
        player.audioPlayer.playerId,
        durationEvent(const Duration(seconds: 3)),
      );
      await pumpEventQueue();
      expect(player.stateValue.duration, const Duration(seconds: 3));
      player.dispose();
      await pumpEventQueue();
    });
    test('duration event after dispose', () async {
      var player = _BytesPlayer();
      await pumpEventQueue();
      player.dispose();
      // Sent before the native player is disposed: ignored
      platform.addEvent(
        player.audioPlayer.playerId,
        durationEvent(const Duration(seconds: 3)),
      );
      await pumpEventQueue();
      expect(player.disposed, isTrue);
    });
    test('loaded completes once the source is prepared', () async {
      platform.autoPrepare = false;
      var player = _BytesPlayer();
      var loaded = false;
      unawaited(player.loaded.then((_) => loaded = true));
      await pumpEventQueue();
      expect(loaded, isFalse, reason: 'source not prepared yet');
      platform.prepare(player.audioPlayer.playerId);
      await player.loaded;
      expect(loaded, isTrue);
      player.dispose();
      await pumpEventQueue();
    }, timeout: const Timeout(Duration(seconds: 10)));
    test('a refused source fails loaded, nothing uncaught', () async {
      platform.sourceError = PlatformException(
        code: 'AndroidAudioError',
        message: 'unsupported format',
      );
      var player = _BytesPlayer();
      await expectLater(player.loaded, throwsA(isA<PlatformException>()));
      await pumpEventQueue();
      player.dispose();
      await pumpEventQueue();
    }, timeout: const Timeout(Duration(seconds: 10)));
    test('loaded, once done, completes in the zone that awaits it', () async {
      var player = _BytesPlayer();
      await player.loaded;
      // The fake async zone of a widget test, the player loaded in runAsync.
      fakeAsync((async) {
        var done = false;
        player.loaded.then((_) => done = true);
        async.flushMicrotasks();
        expect(done, isTrue);
      });
      player.dispose();
      await pumpEventQueue();
    }, timeout: const Timeout(Duration(seconds: 10)));
  });
}
