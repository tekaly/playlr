import 'package:flutter/foundation.dart';
import 'package:playlr_audio_player/player.dart';

import '../import.dart';
import 'just_audio_audio_player_impl.dart';

/// The [AppAudioPlayer] implemented with `package:just_audio`: plays bytes
/// (`playBytes`, `playSong` through the global cache) and streams an url
/// (`playUri`/`loadUri`) on Android, iOS, macOS, web, Linux (mpv) and Windows.
///
/// Create one for the app (or use [appAudioPlayerJustAudio]).
class AppAudioPlayerJustAudio extends AppAudioPlayer with AppAudioPlayerMixin {
  /// Creates a new audio player instance from bytes using JustAudio.
  @override
  SongAudioPlayer newAudioPlayerInstanceFromBytes(Uint8List data) {
    SongAudioPlayerImpl impl;
    impl = JustAudioPlayerImpl.fromBytes(data);
    return impl;
  }

  /// Creates a new audio player instance streaming [uri] using JustAudio.
  @override
  SongAudioPlayer newAudioPlayerInstanceFromUri(Uri uri) =>
      JustAudioPlayerImpl.fromUri(uri);

  /// The name of the audio player implementation.
  @override
  String get name => 'JustAudio';
}

/// A ready made [AppAudioPlayerJustAudio], for an app wanting one player.
final AppAudioPlayer appAudioPlayerJustAudio = AppAudioPlayerJustAudio();
