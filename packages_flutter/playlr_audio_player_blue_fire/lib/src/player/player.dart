import 'package:flutter/foundation.dart';

import 'package:playlr_audio_player/player.dart';

import 'blue_fire_audio_player_impl.dart';

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

final AppAudioPlayer appAudioPlayerBlueFire = AppAudioPlayerBlueFire();
