import 'dart:io' as io;

import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:playlr_audio_player/cache.dart';
import 'package:playlr_audio_player/player.dart';
import 'package:playlr_audio_player_blue_fire/player.dart';
import 'package:playlr_audio_player_just_audio/player.dart';
import 'package:playlr_simple_player_app/src/asset/assets.dart';
import 'package:playlr_simple_player_app/src/cache/cache.dart';
import 'package:playlr_simple_player_app/src/import.dart';
import 'package:playlr_simple_player_app/src/test/audioplayers_test_menu.dart';
import 'package:playlr_simple_player_app/src/test/just_audio_test_menu.dart';
// ignore: depend_on_referenced_packages
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tekartik_test_menu_flutter/test_menu_flutter.dart';

var assetSongExample1 =
    AppAudioPlayerSong(globalCacheOrNull!.assetToSource(assetAudioExample1));
var networkExample1 = AppAudioPlayerSong(
    'https://media.howob.com/audio_test/sample-9s-mono.mp3'
    //'https://firebasestorage.googleapis.com/v0/b/tekartik-free-dev.appspot.com/o/test%2Fexpected%2Ftest.json?alt=media'
    );

var networkExampleGood2 = AppAudioPlayerSong(
    'https://media.howob.com/audio_test/soundhelix_song_1_30s.mp3');

var networkExampleGood6 = AppAudioPlayerSong(
    'https://media.howob.com/audio_test/free_test_data_15s.mp3.mp3');
var networkExampleMidiGood7 =
    AppAudioPlayerSong('https://media.howob.com/audio_test/pop.mid');
var networkExample3Cors = AppAudioPlayerSong(
    'https://samplelib.com/lib/preview/mp3/sample-12s.mp3'
    //'https://firebasestorage.googleapis.com/v0/b/tekartik-free-dev.appspot.com/o/test%2Fexpected%2Ftest.json?alt=media'
    );

AppAudioPlayerSong localFileSong(String path) =>
    AppAudioPlayerSong(join(kIsWeb ? 'assets/assets' : 'assets', path));

var localGood2 = localFileSong('audio/soundhelix_song_1_30s.mp3');
var localGood3 = localFileSong('audio/free_test_data_15s.mp3');
var localMidi = localFileSong('audio/pop.mid');
var networkExample4Local =
    AppAudioPlayerSong('assets/assets/audio/example1.mp3');
var fileExample4Local = AppAudioPlayerSong('assets/audio/example1.mp3');
var networkExample2Missing = AppAudioPlayerSong(
    'https://firebasestorage.googleapis.com/v0/b/tekartik-free-dev.appspot.com/o/dummy/test%2Fexpected%2Ftest.json?alt=media');

var appAudioPlayer = appAudioPlayerJustAudio;

Future<void> main() async {
  await mainTestMenu();
}

Future<void> mainTestMenu() async {
  if (!kIsWeb && io.Platform.isWindows) {
    sqfliteFfiInit();
  }
  await initCache();
  appAudioPlayer.stateStream.listen((state) {
    write('#state $state');
  });
  appAudioPlayer.positionStream.listen((position) {
    // write('#position $position');
  });
  mainMenuFlutter(() {
    enter(() async {
      //debugPlayerDumpWriteLn = devWarning(write);
      debugCacheWriteLn = write;
      if (debugPlayerDumpWriteLn != null) {
        debugPlayerDumpWriteLn!('Dumper on');
      }
    });
    menuAudioPlayers();
    menuJustAudio();
    menu('cache', () {
      enter(() async {
        await initCache();
      });
      leave(() {
        //stateSubscription?.cancel();
      });
      item('example', () async {
        var db = await initCache();
        var content = await db.getContent(
          'https://firebasestorage.googleapis.com/v0/b/tekartik-free-dev.appspot.com/o/test%2Fexpected%2Ftest.json?alt=media',
        );
        write(utf8.decode(content));
      });
      item('fetch asset', () async {
        var db = await initCache();
        await db.getContent(
          db.assetToSource(assetAudioExample1),
        );
      });
      item('dump cache asset', () async {
        var db = await initCache();
        await db.dumpCache();
      });
      item('clear cache', () async {
        var db = await initCache();
        await db.clearCache();
      });
    });

    item('play asset', () async {
      await initCache();
      await appAudioPlayer.playSong(assetSongExample1);
    });
    // quick play test
    item('play local mp3 file', () async {
      await initCache();
      if (!kIsWeb) {
        await appAudioPlayer.playSong(fileExample4Local);
      } else {
        await appAudioPlayer.playSong(networkExample4Local);
      }
    });
    // quick play test
    item('play midi file', () async {
      await appAudioPlayer.playSong(localMidi);
    });

    // quick play test
    item('play network midi file', () async {
      await appAudioPlayer.playSong(networkExampleMidiGood7);
    });
    appAudioPlayerMenu(AppAudioPlayer appAudioPlayer,
        {String? name, @Deprecated("dev only") bool? solo}) {
      // print('player $appAudioPlayer solo $solo');
      menu(name ?? 'use default ($appAudioPlayer)', () {
        enter(() {
          write('using player $appAudioPlayer');
        });
        item('play asset', () async {
          await initCache();
          await appAudioPlayer.playSong(assetSongExample1);
        });
        item('play local mp3', () async {
          if (!kIsWeb) {
            await appAudioPlayer.playSong(fileExample4Local);
          } else {
            await appAudioPlayer.playSong(networkExample4Local);
          }
        });

        item('play local 2', () async {
          await appAudioPlayer.playSong(localGood2);
        });
        item('play local 3', () async {
          await appAudioPlayer.playSong(localGood3);
        });

        item('play midi file', () async {
          await appAudioPlayer.playSong(localMidi);
        });
        item('load local mp3', () async {
          if (!kIsWeb) {
            await appAudioPlayer.loadSong(fileExample4Local);
          } else {
            await appAudioPlayer.loadSong(networkExample4Local);
          }
        });

        item('play network 1', () async {
          await appAudioPlayer.playSong(networkExample1);
        });
        item('play network 2 missing', () async {
          await appAudioPlayer.playSong(
            networkExample2Missing,
          );
        });
        item('play network 3 cors', () async {
          await appAudioPlayer.playSong(networkExample3Cors);
        });
        item('pause', () async {
          await appAudioPlayer.pause();
        });
        item('stop', () async {
          await appAudioPlayer.stop();
        });
        item('resume', () async {
          appAudioPlayer.resume().unawait();
        });
        item('play', () async {
          await appAudioPlayer.play();
        });
        item('dumpPosition', () async {
          appAudioPlayer.dumpPositionSync();
          appAudioPlayer.dumpPosition();
          write(await appAudioPlayer.getCurrentPosition());
        });
        item('dumpDuration', () async {
          write(await appAudioPlayer.getDuration());
        });
        item('dump position state', () async {
          write('${await appAudioPlayer.positionStream.first}');
        });
        item('dump status state', () async {
          write('${await appAudioPlayer.stateStream.first}');
        });
        item('forward 3s', () async {
          await appAudioPlayer.forward(const Duration(seconds: 3));
        });
        item('backward 3s', () async {
          await appAudioPlayer.forward(const Duration(seconds: -3));
        });
        item('toggle extra write', () {
          if (debugPlayerDumpWriteLn == null) {
            debugPlayerDumpWriteLn = write;
          } else {
            debugPlayerDumpWriteLn = null;
          }
        });
        // ignore: deprecated_member_use
      }, solo: solo);
    }

    appAudioPlayerMenu(appAudioPlayerJustAudio,
        name: 'use JustAudio (default just_audio)');
    appAudioPlayerMenu(appAudioPlayerBlueFire,
        name: 'use BlueFire (legacy audioplayers)');
  }, showConsole: true);
}
