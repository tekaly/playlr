import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart' show PlayerException;
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';
import 'package:playlr_audio_player_just_audio/src/player/just_audio_audio_player_impl.dart';

/// No native player: a source loads right away.
class _FakeJustAudioPlatform extends JustAudioPlatform {
  /// The error of the native player when a source is loaded.
  Object? loadError;

  @override
  Future<AudioPlayerPlatform> init(InitRequest request) async =>
      _FakeAudioPlayerPlatform(request.id, loadError: loadError);

  @override
  Future<DisposePlayerResponse> disposePlayer(
    DisposePlayerRequest request,
  ) async => DisposePlayerResponse();

  @override
  Future<DisposeAllPlayersResponse> disposeAllPlayers(
    DisposeAllPlayersRequest request,
  ) async => DisposeAllPlayersResponse();
}

class _FakeAudioPlayerPlatform extends AudioPlayerPlatform {
  final _events = StreamController<PlaybackEventMessage>.broadcast();

  final Object? loadError;

  _FakeAudioPlayerPlatform(super.id, {this.loadError});

  @override
  Stream<PlaybackEventMessage> get playbackEventMessageStream => _events.stream;

  @override
  Future<LoadResponse> load(LoadRequest request) async {
    var error = loadError;
    if (error != null) {
      throw error;
    }
    const duration = Duration(seconds: 3);
    // just_audio waits for the loading state to pass.
    scheduleMicrotask(() {
      _events.add(
        PlaybackEventMessage(
          processingState: ProcessingStateMessage.ready,
          updateTime: DateTime.now(),
          updatePosition: Duration.zero,
          bufferedPosition: duration,
          duration: duration,
          icyMetadata: null,
          currentIndex: 0,
          androidAudioSessionId: null,
        ),
      );
    });
    return LoadResponse(duration: duration);
  }

  @override
  Future<PlayResponse> play(PlayRequest request) async => PlayResponse();

  @override
  Future<PauseResponse> pause(PauseRequest request) async => PauseResponse();

  @override
  Future<SetVolumeResponse> setVolume(SetVolumeRequest request) async =>
      SetVolumeResponse();

  @override
  Future<SetSpeedResponse> setSpeed(SetSpeedRequest request) async =>
      SetSpeedResponse();

  @override
  Future<SetPitchResponse> setPitch(SetPitchRequest request) async =>
      SetPitchResponse();

  @override
  Future<SetSkipSilenceResponse> setSkipSilence(
    SetSkipSilenceRequest request,
  ) async => SetSkipSilenceResponse();

  @override
  Future<SetLoopModeResponse> setLoopMode(SetLoopModeRequest request) async =>
      SetLoopModeResponse();

  @override
  Future<SetShuffleModeResponse> setShuffleMode(
    SetShuffleModeRequest request,
  ) async => SetShuffleModeResponse();

  @override
  Future<SeekResponse> seek(SeekRequest request) async => SeekResponse();

  @override
  Future<DisposeResponse> dispose(DisposeRequest request) async {
    await _events.close();
    return DisposeResponse();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _FakeJustAudioPlatform platform;
  setUp(() {
    platform = _FakeJustAudioPlatform();
    JustAudioPlatform.instance = platform;
  });

  group('JustAudioPlayerImpl', () {
    test('loaded', () async {
      var player = JustAudioPlayerImpl.fromUri(
        Uri.parse('https://example.com/song.mp3'),
      );
      await player.loaded;
      expect(await player.getDuration(), const Duration(seconds: 3));
      player.dispose();
      await pumpEventQueue();
    }, timeout: const Timeout(Duration(seconds: 10)));
    test('loaded, once done, completes in the zone that awaits it', () async {
      var player = JustAudioPlayerImpl.fromUri(
        Uri.parse('https://example.com/song.mp3'),
      );
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
    test('a refused source fails loaded, again later', () async {
      platform.loadError = PlatformException(code: '404', message: 'not found');
      var player = JustAudioPlayerImpl.fromUri(
        Uri.parse('https://example.com/missing.mp3'),
      );
      await expectLater(player.loaded, throwsA(isA<PlayerException>()));
      await expectLater(player.loaded, throwsA(isA<PlayerException>()));
      player.dispose();
      await pumpEventQueue();
    }, timeout: const Timeout(Duration(seconds: 10)));
  });
}
