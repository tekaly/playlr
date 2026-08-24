import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:playlr_asset_example_flutter/playlr_asset_example_flutter.dart';
import 'package:playlr_player_example_app/src/player/app_audio_player.dart';
import 'package:playlr_player_example_app/src/player/song_loader.dart';

/// State exposed by [ClipQueuePlayerController].
class ClipQueuePlayerState {
  /// Index of the clip being played, -1 when not started.
  final int index;

  /// True while the clip is being loaded.
  final bool loading;

  /// True once the whole queue has been played.
  final bool done;

  /// Clip queue state.
  const ClipQueuePlayerState({
    this.index = -1,
    this.loading = false,
    this.done = false,
  });

  /// Copy with.
  ClipQueuePlayerState copyWith({int? index, bool? loading, bool? done}) =>
      ClipQueuePlayerState(
        index: index ?? this.index,
        loading: loading ?? this.loading,
        done: done ?? this.done,
      );
}

/// Plays a queue of clips (a part of a song) one after the other.
///
/// Each clip is loaded then played from its start to its end position, with a
/// fade in/fade out handled by `playFromTo`.
class ClipQueuePlayerController {
  /// The audio player implementation.
  final AppAudioPlayer audioPlayer;

  /// The clips to play, in order.
  final List<AudioAssetExampleClip> clips;

  /// Observable state.
  final state = ValueNotifier<ClipQueuePlayerState>(
    const ClipQueuePlayerState(),
  );

  /// Position in the current clip song.
  Stream<Duration?> get positionStream => audioPlayer.positionStream;

  var _playRequestId = 0;
  var _disposed = false;

  /// Clip queue player.
  ClipQueuePlayerController({required this.audioPlayer, required this.clips});

  /// Plays the whole queue, the future completes at the end of the last clip
  /// (or when a new play request or a dispose supersedes it).
  Future<void> play() async {
    var requestId = ++_playRequestId;
    for (var i = 0; i < clips.length; i++) {
      var clip = clips[i];
      state.value = state.value.copyWith(index: i, loading: true, done: false);
      var player = await loadSongReady(audioPlayer, clip.song);
      if (requestId != _playRequestId) {
        return;
      }
      state.value = state.value.copyWith(loading: false);
      try {
        await player.playFromTo(from: clip.from, to: clip.to);
      } on StateError catch (_) {
        // The song player was disposed while playing, we are superseded.
        return;
      }
      if (requestId != _playRequestId) {
        return;
      }
    }
    await audioPlayer.stop();
    if (requestId != _playRequestId || _disposed) {
      return;
    }
    state.value = state.value.copyWith(done: true);
  }

  /// Stop and release.
  Future<void> dispose() async {
    _disposed = true;
    _playRequestId++;
    try {
      await audioPlayer.stop();
    } catch (_) {}
    state.dispose();
  }
}
