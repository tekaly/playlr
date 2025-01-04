import 'package:flutter/foundation.dart';
import 'package:playlr_audio_player/player.dart';

import '../import.dart';
import 'just_audio_audio_player_impl.dart';

class AppAudioPlayerJustAudio extends AppAudioPlayer with AppAudioPlayerMixin {
  @override
  SongAudioPlayer newAudioPlayerInstanceFromBytes(Uint8List data) {
    SongAudioPlayerImpl impl;
    impl = JustAudioPlayerImpl.fromBytes(data);
    return impl;
  }

  @override
  String get name => 'JustAudio';
}

final AppAudioPlayer appAudioPlayerJustAudio = AppAudioPlayerJustAudio();
