import 'dart:async';

// ignore: depend_on_referenced_packages
import 'package:audioplayers_platform_interface/audioplayers_platform_interface.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playlr_audio_player_blue_fire/src/player/blue_fire_audio_player_impl.dart';

/// No native player: events are sent by the test.
class _FakeAudioplayersPlatform extends AudioplayersPlatformInterface {
  final _events = <String, StreamController<AudioEvent>>{};

  StreamController<AudioEvent> _eventController(String playerId) =>
      _events[playerId] ??= StreamController<AudioEvent>.broadcast();

  /// Send a native event for [playerId].
  void addEvent(String playerId, AudioEvent event) =>
      _eventController(playerId).add(event);

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
  }) async {
    addEvent(
      playerId,
      const AudioEvent(eventType: AudioEventType.prepared, isPrepared: true),
    );
  }

  @override
  Future<void> setSourceUrl(
    String playerId,
    String url, {
    bool? isLocal,
    String? mimeType,
  }) async {
    addEvent(
      playerId,
      const AudioEvent(eventType: AudioEventType.prepared, isPrepared: true),
    );
  }

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
  });
}
