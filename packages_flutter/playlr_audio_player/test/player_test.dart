import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:playlr_audio_player/player.dart';

/// Player without a platform: records the volume and the calls.
class _FakeSongPlayer extends SongAudioPlayerImpl with SongAudioPlayerMixin {
  final calls = <String>[];
  var volume = 1.0;
  var _playing = false;
  var _position = Duration.zero;
  final _duration = const Duration(seconds: 10);

  void _emit() {
    stateSink.add(
      AppAudioPlayerState(
        stateEnum: AppAudioPlayerStateEnum.ready,
        playing: _playing,
        duration: _duration,
        position: _position,
      ),
    );
  }

  /// Simulates the playback reaching [position].
  void reach(Duration position) {
    _position = position;
    positionSink.add(position);
  }

  _FakeSongPlayer() {
    _emit();
  }

  @override
  Future<Duration?> getCurrentPosition() async => _position;

  @override
  Future<Duration?> getDuration() async => _duration;

  @override
  Future<void> pause() async {
    calls.add('pause');
    _playing = false;
    _emit();
  }

  @override
  Future<void> play() async {
    calls.add('play');
    _playing = true;
    _emit();
  }

  @override
  Future<void> resume() => play();

  @override
  Future<void> seek(Duration position) async {
    calls.add('seek');
    reach(position);
  }

  @override
  Future<void> setPlaybackRate(double rate) async {}

  @override
  Future<void> setVolume(double volume) async {
    this.volume = volume;
  }

  @override
  Future<void> stop() async {
    calls.add('stop');
    _playing = false;
    _emit();
  }
}

class _FakeAppAudioPlayer extends AppAudioPlayer {
  @override
  String get name => 'fake';

  @override
  SongAudioPlayer newAudioPlayerInstanceFromBytes(Uint8List data) =>
      _FakeSongPlayer();
}

void main() {
  group('playFromTo', () {
    test('the volume is back once the clip ended', () async {
      var appPlayer = _FakeAppAudioPlayer();
      var player =
          appPlayer.loadBytes(Uint8List.fromList([1, 2, 3])) as _FakeSongPlayer;
      var done = appPlayer.playFromTo(
        from: const Duration(seconds: 1),
        to: const Duration(seconds: 2),
      );
      // Past the fade in, then the end of the clip.
      await Future<void>.delayed(const Duration(milliseconds: 700));
      expect(player.volume, 1);
      player.reach(const Duration(seconds: 2));
      await done;
      expect(player.calls.last, 'pause');
      // A later resume (no fade in) must be heard.
      expect(player.volume, 1);
      await appPlayer.resume();
      expect(player.volume, 1);
    }, timeout: const Timeout(Duration(seconds: 10)));
  });
}
