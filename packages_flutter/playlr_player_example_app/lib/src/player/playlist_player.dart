import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:playlr_asset_example_flutter/playlr_asset_example_flutter.dart';
import 'package:playlr_player_example_app/src/player/app_audio_player.dart';
import 'package:playlr_player_example_app/src/player/song_loader.dart';

/// State exposed by [PlaylistPlayerController].
class PlaylistPlayerState {
  /// Current asset or null.
  final AudioAssetExample? asset;

  /// True while loading.
  final bool loading;

  /// True when playing.
  final bool playing;

  /// True when shuffle is on.
  final bool shuffle;

  /// True when repeat all is on.
  final bool repeatAll;

  /// Set when the current song could not be loaded or played.
  final String? error;

  /// Playlist state.
  const PlaylistPlayerState({
    this.asset,
    this.loading = false,
    this.playing = false,
    this.shuffle = false,
    this.repeatAll = true,
    this.error,
  });

  /// Copy with, [error] is cleared unless specified.
  PlaylistPlayerState copyWith({
    AudioAssetExample? asset,
    bool? loading,
    bool? playing,
    bool? shuffle,
    bool? repeatAll,
    String? error,
  }) => PlaylistPlayerState(
    asset: asset ?? this.asset,
    loading: loading ?? this.loading,
    playing: playing ?? this.playing,
    shuffle: shuffle ?? this.shuffle,
    repeatAll: repeatAll ?? this.repeatAll,
    error: error,
  );

  @override
  String toString() =>
      '$asset loading $loading playing $playing${error == null ? '' : ' error $error'}';
}

/// Plays a list of assets one after the other, with previous/next, shuffle
/// and repeat all.
class PlaylistPlayerController {
  /// The audio player implementation.
  final AppAudioPlayer audioPlayer;

  /// The playlist.
  final List<AudioAssetExample> assets;

  /// Observable state.
  final state = ValueNotifier<PlaylistPlayerState>(const PlaylistPlayerState());

  /// Position of the current song.
  Stream<Duration?> get positionStream => audioPlayer.positionStream;

  /// Order of the playlist (indexes in [assets]), shuffled or not.
  var _order = <int>[];
  var _orderIndex = 0;
  var _playRequestId = 0;
  StreamSubscription<AppAudioPlayerState>? _stateSubscription;

  /// Playlist player.
  PlaylistPlayerController({required this.audioPlayer, required this.assets}) {
    _order = List.generate(assets.length, (index) => index);
    _stateSubscription = audioPlayer.stateStream.listen((playerState) {
      if (playerState.stateEnum == AppAudioPlayerStateEnum.completed) {
        unawaited(next());
      } else {
        state.value = state.value.copyWith(
          playing: playerState.playing,
          error: state.value.error,
        );
      }
    });
  }

  /// Current asset or null.
  AudioAssetExample? get currentAsset =>
      _order.isEmpty ? null : assets[_order[_orderIndex]];

  /// Plays the asset at [index] in [assets].
  Future<void> playAt(int index) async {
    var orderIndex = _order.indexOf(index);
    if (orderIndex < 0) {
      return;
    }
    _orderIndex = orderIndex;
    await _playCurrent();
  }

  Future<void> _playCurrent() async {
    var asset = currentAsset;
    if (asset == null) {
      return;
    }
    var requestId = ++_playRequestId;
    state.value = state.value.copyWith(asset: asset, loading: true);
    try {
      var songPlayer = await loadSongReady(audioPlayer, asset.song);
      if (requestId != _playRequestId) {
        // A newer request superseded this one.
        return;
      }
      if (!songPlayer.stateValue.isReady) {
        // Never got ready (this happens with just_audio on linux), don't
        // pretend we are playing.
        state.value = state.value.copyWith(
          loading: false,
          playing: false,
          error: 'Could not load ${asset.name}',
        );
        return;
      }
      // Not awaited: on some implementations (just_audio) the resume future
      // only completes at the end of the song.
      unawaited(songPlayer.resume());
      state.value = state.value.copyWith(loading: false, playing: true);
    } catch (e) {
      if (requestId == _playRequestId) {
        state.value = state.value.copyWith(
          loading: false,
          playing: false,
          error: '$e',
        );
      }
    }
  }

  /// Next song, stops at the end of the playlist unless repeat all is on.
  Future<void> next() async {
    if (_orderIndex + 1 < _order.length) {
      _orderIndex++;
    } else if (state.value.repeatAll) {
      _orderIndex = 0;
    } else {
      await audioPlayer.stop();
      state.value = state.value.copyWith(playing: false);
      return;
    }
    await _playCurrent();
  }

  /// Previous song.
  Future<void> previous() async {
    if (_orderIndex > 0) {
      _orderIndex--;
    } else if (state.value.repeatAll) {
      _orderIndex = _order.length - 1;
    }
    await _playCurrent();
  }

  /// Toggle shuffle, the current song remains the current one.
  void toggleShuffle() {
    var shuffle = !state.value.shuffle;
    var currentIndex = _order.isEmpty ? null : _order[_orderIndex];
    _order = List.generate(assets.length, (index) => index);
    if (shuffle) {
      _order.shuffle(Random());
    }
    if (currentIndex != null) {
      _orderIndex = max(0, _order.indexOf(currentIndex));
    }
    state.value = state.value.copyWith(shuffle: shuffle);
  }

  /// Toggle repeat all.
  void toggleRepeatAll() {
    state.value = state.value.copyWith(repeatAll: !state.value.repeatAll);
  }

  /// Pause.
  Future<void> pause() => audioPlayer.pause();

  /// Resume, not awaiting the end of the song.
  Future<void> resume() async {
    unawaited(audioPlayer.resume());
  }

  /// Seek in the current song.
  Future<void> seek(Duration position) => audioPlayer.seek(position);

  /// Duration of the current song.
  Future<Duration?> getDuration() => audioPlayer.getDuration();

  /// Stop and release.
  Future<void> dispose() async {
    _playRequestId++;
    await _stateSubscription?.cancel();
    try {
      await audioPlayer.stop();
    } catch (_) {}
    state.dispose();
  }
}
