import 'dart:io' as io;

import 'package:flutter/foundation.dart';
import 'package:playlr_player_example_app/src/player/app_audio_player.dart';

/// True for just_audio on linux, where only one mpv instance can live at a
/// time.
///
/// `just_audio_mpv` delegates to `mpv_dart` which (as of 0.0.1) ignores the
/// requested ipc socket and always uses `/tmp/MPV_Dart.sock`, so a second
/// concurrent instance breaks the first one (`Broken pipe`). The audio player
/// keeps a small pool of players, so the previous one must be released before
/// loading a new song.
bool needsSingleSongPlayer(AppAudioPlayer audioPlayer) =>
    !kIsWeb &&
    io.Platform.isLinux &&
    identical(audioPlayer, AppAudioPlayerImplementation.justAudio.player);

/// Releases the current song player if needed, see [needsSingleSongPlayer].
Future<void> releaseCurrentSongPlayer(AppAudioPlayer audioPlayer) async {
  await audioPlayer.stop();
  if (!needsSingleSongPlayer(audioPlayer)) {
    return;
  }
  var current = audioPlayer.currentPlayer;
  if (current != null && !current.disposed) {
    current.dispose();
    // Let the mpv process exit and free its ipc socket.
    await Future<void>.delayed(const Duration(milliseconds: 300));
  }
}

/// Loads [song] and waits until it is ready to play, without playing it.
///
/// The duration (and the ready state) is only known once the source is
/// loaded, and on some platforms (linux) resuming before that is a no-op, so
/// always wait for the ready state (with a [timeout] safety net) before
/// resuming.
Future<SongAudioPlayer> loadSongReady(
  AppAudioPlayer audioPlayer,
  AppAudioPlayerSong song, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  await releaseCurrentSongPlayer(audioPlayer);
  var songPlayer = await audioPlayer.loadSong(song);
  await songPlayer.pause();
  try {
    await songPlayer.stateStream
        .firstWhere((state) => state.isReady)
        .timeout(timeout, onTimeout: () => songPlayer.stateValue);
  } on StateError catch (_) {
    // The song player was disposed (replaced by a new song) while waiting.
  }
  return songPlayer;
}
