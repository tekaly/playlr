import 'dart:io' as io;

import 'package:flutter/foundation.dart';
import 'package:playlr_audio_player/player.dart';
import 'package:playlr_audio_player_blue_fire/player.dart';
import 'package:playlr_audio_player_just_audio/player.dart';

export 'package:playlr_audio_player/player.dart';

/// The audio player implementations available in this example app.
enum AppAudioPlayerImplementation {
  /// just_audio, the default on every platform.
  ///
  /// Needs `just_audio_mpv` on linux and `just_audio_windows` on windows,
  /// both added as direct dependencies of the app.
  justAudio,

  /// audioplayers (blue fire), kept as an alternative to compare.
  audioPlayers,
}

/// Display name of an implementation.
extension AppAudioPlayerImplementationExtension
    on AppAudioPlayerImplementation {
  /// Display name.
  String get name => switch (this) {
    AppAudioPlayerImplementation.justAudio => 'just_audio',
    AppAudioPlayerImplementation.audioPlayers => 'audioplayers (blue fire)',
  };

  /// The matching player.
  AppAudioPlayer get player => switch (this) {
    AppAudioPlayerImplementation.justAudio => appAudioPlayerJustAudio,
    AppAudioPlayerImplementation.audioPlayers => appAudioPlayerBlueFire,
  };
}

/// The best implementation for the current platform.
///
/// just_audio covers web, android, ios, macos and windows (windows through
/// `just_audio_windows`).
///
/// On linux just_audio needs `just_audio_mpv`, which delegates to `mpv_dart`,
/// and that one is not reliable: it ignores the requested ipc socket and
/// always uses `/tmp/MPV_Dart.sock` so two players fight for the same socket,
/// and a freshly loaded track often stays in the preparing state forever.
/// audioplayers (gstreamer based on linux) has none of these issues, so it is
/// the default there.
AppAudioPlayerImplementation get defaultAppAudioPlayerImplementation =>
    (!kIsWeb && io.Platform.isLinux)
    ? AppAudioPlayerImplementation.audioPlayers
    : AppAudioPlayerImplementation.justAudio;

/// The implementation currently selected in the app (from the main menu).
final appAudioPlayerImplementation = ValueNotifier(
  defaultAppAudioPlayerImplementation,
);

/// The current audio player.
AppAudioPlayer get appAudioPlayer => appAudioPlayerImplementation.value.player;
