import 'package:flutter/foundation.dart';
import 'package:playlr_audio_player/player.dart';

import '../import.dart';
import 'just_audio_audio_player_impl.dart';

/// App audio player implementation using the JustAudio package.
class AppAudioPlayerJustAudio extends AppAudioPlayer with AppAudioPlayerMixin {
  /// Creates a new audio player instance from bytes using JustAudio.
  @override
  SongAudioPlayer newAudioPlayerInstanceFromBytes(Uint8List data) {
    SongAudioPlayerImpl impl;
    impl = JustAudioPlayerImpl.fromBytes(data);
    return impl;
  }

  /// The name of the audio player implementation.
  @override
  String get name => 'JustAudio';
}

/// Singleton instance of [AppAudioPlayerJustAudio].
final AppAudioPlayer appAudioPlayerJustAudio = AppAudioPlayerJustAudio();
