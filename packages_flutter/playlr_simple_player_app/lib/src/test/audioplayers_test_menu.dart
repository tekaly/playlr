import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:playlr_simple_player_app/main_test_menu.dart';
// ignore: depend_on_referenced_packages
import 'package:tekartik_common_utils/common_utils_import.dart';
import 'package:tekartik_test_menu_flutter/test_menu_flutter.dart';

void menuAudioPlayers() {
  menu('audioplayers', () {
    AudioPlayer? audioPlayer;
    Future<void> startPlay(String url) async {
      await audioPlayer?.dispose();
      audioPlayer = AudioPlayer();
      await audioPlayer!.setSource(UrlSource(url));
      audioPlayer!.resume().unawait();
    }

    item('play local mp3', () async {
      var url = kIsWeb ? networkExample4Local.source : fileExample4Local.source;
      await startPlay(url);
    });
    item('play mp3', () async {
      var url = 'https://samplelib.com/lib/preview/mp3/sample-12s.mp3';
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
      audioPlayer?.resume().unawait();
    });
  });
}
