import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:playlr_asset_example_flutter/playlr_asset_example_flutter.dart';
import 'package:playlr_audio_player/player.dart';
import 'package:playlr_player_example_app/src/player/playlist_player.dart';

/// A song player that is ready right away, playing when resumed.
class _FakeSongPlayer extends SongAudioPlayerImpl with SongAudioPlayerMixin {
  final String label;
  var playing = false;

  _FakeSongPlayer(this.label) {
    _addState();
  }

  void _addState() {
    if (!disposed) {
      stateSink.add(
        AppAudioPlayerState(
          stateEnum: AppAudioPlayerStateEnum.ready,
          playing: playing,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  @override
  Future<void> resume() async {
    playing = true;
    _addState();
  }

  @override
  Future<void> play() => resume();

  @override
  Future<void> pause() async {
    playing = false;
    _addState();
  }

  @override
  Future<void> stop() => pause();

  @override
  void dispose() {
    playing = false;
    super.dispose();
  }

  @override
  Future<Duration?> getCurrentPosition() async => Duration.zero;

  @override
  Future<Duration?> getDuration() async => const Duration(seconds: 5);

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> setPlaybackRate(double rate) async {}

  @override
  Future<void> setVolume(double volume) async {}

  @override
  String toString() => 'Fake($label)';
}

/// An audio player whose song loading takes [loadDelays] per source.
class _FakeAppAudioPlayer extends AppAudioPlayer {
  final Map<String, Duration> loadDelays;
  final players = <_FakeSongPlayer>[];

  _FakeAppAudioPlayer(this.loadDelays);

  @override
  String get name => 'fake';

  @override
  SongAudioPlayer newAudioPlayerInstanceFromBytes(Uint8List data) {
    var player = _FakeSongPlayer(utf8.decode(data));
    players.add(player);
    return player;
  }

  @override
  Future<SongAudioPlayer> loadSong(AppAudioPlayerSong song) async {
    await Future<void>.delayed(loadDelays[song.source] ?? Duration.zero);
    return loadBytes(Uint8List.fromList(utf8.encode(song.source)));
  }
}

void main() {
  test('the last song tapped plays, the controls reach it', () async {
    var slow = audioAssetExamples[0];
    var fast = audioAssetExamples[1];
    var audioPlayer = _FakeAppAudioPlayer({
      // Not in the cache yet: slow to load.
      slow.song.source: const Duration(milliseconds: 300),
    });
    var controller = PlaylistPlayerController(
      audioPlayer: audioPlayer,
      assets: audioAssetExamples,
    );
    try {
      // A tap on the slow song then, while it loads, on the fast one.
      var first = controller.playAt(0);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      var second = controller.playAt(1);
      await Future.wait([first, second]);
      // Let the state events reach the controller.
      await Future<void>.delayed(const Duration(milliseconds: 50));

      List<String> playing() => audioPlayer.players
          .where((player) => player.playing)
          .map((player) => player.label)
          .toList();
      expect(controller.state.value.asset, fast);
      expect(playing(), [fast.song.source]);
      expect(
        (audioPlayer.currentPlayer as _FakeSongPlayer?)?.label,
        fast.song.source,
      );
      expect(controller.state.value.playing, isTrue);

      await controller.pause();
      expect(playing(), isEmpty);
    } finally {
      await controller.dispose();
    }
  }, timeout: const Timeout(Duration(seconds: 30)));
}
