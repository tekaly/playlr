import 'package:flutter/foundation.dart';

import 'package:playlr_audio_player/player.dart';

import 'blue_fire_audio_player_impl.dart';

/// The [AppAudioPlayer] implemented with `package:audioplayers` (Blue Fire):
/// plays bytes (`playBytes`, `playSong` through the global cache) on Android,
/// iOS, macOS, web, Windows and Linux.
///
/// It cannot stream an url: `playUri`/`loadUri` throw an [UnsupportedError].
/// Create one for the app (or use [appAudioPlayerBlueFire]).
class AppAudioPlayerBlueFire extends AppAudioPlayer with AppAudioPlayerMixin {
  @override
  SongAudioPlayer newAudioPlayerInstanceFromBytes(Uint8List data) {
    SongAudioPlayerImpl impl;
    impl = BlueFireAudioPlayerImpl.fromBytes(data);
    return impl;
  }

  @override
  String get name => 'BlueFire';
}

/// A ready made [AppAudioPlayerBlueFire], for an app wanting one player.
final AppAudioPlayer appAudioPlayerBlueFire = AppAudioPlayerBlueFire();
