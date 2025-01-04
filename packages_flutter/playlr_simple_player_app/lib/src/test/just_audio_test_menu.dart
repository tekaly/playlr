import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:playlr_audio_player_just_audio/player.dart';
import 'package:playlr_simple_player_app/main_test_menu.dart';
import 'package:playlr_simple_player_app/src/cache/cache.dart';

// ignore: depend_on_referenced_packages
import 'package:tekartik_common_utils/common_utils_import.dart';
import 'package:tekartik_test_menu_flutter/test_menu_flutter.dart';

void menuJustAudio() {
  menu('just_audio', () {
    // quick play test
    item('play local mp3 file', () async {
      await initCache();
      if (!kIsWeb) {
        await appAudioPlayerJustAudio.playSong(fileExample4Local);
      } else {
        await appAudioPlayerJustAudio.playSong(networkExample4Local);
      }
    });
  });
  menu('raw_just_audio', () {
    AudioPlayer? audioPlayer;
    Future<void> startPlay(String url) async {
      await audioPlayer?.dispose();
      audioPlayer = AudioPlayer();
      await audioPlayer!.setAudioSource(AudioSource.uri(Uri.parse(url)));
      audioPlayer!.play().unawait();
    }

    item('play mp3', () async {
      var url = 'https://samplelib.com/lib/preview/mp3/sample-12s.mp3';
      await startPlay(url);
    });

    item('local mp3', () async {
      var url = networkExample4Local.source;
      await startPlay(url);
    });

    item('play midi', () async {
      var midiUrl =
          // 'sample1.mid';
          'https://firebasestorage.googleapis.com/v0/b/tekartik-free-dev.appspot.com/o/test%2Fmidi%2Fsample1.mid?alt=media&token=0edfa882-cbe9-41fc-a6c7-39bfa041410c';
      await startPlay(midiUrl);
    });
    item('stop', () async {
      await audioPlayer?.stop();
    });
    item('resume', () async {
      audioPlayer?.play().unawait();
    });
  });
}
