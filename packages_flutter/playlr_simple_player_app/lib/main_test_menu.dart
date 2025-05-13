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
import 'package:tekartik_app_dev_menu/dev_menu.dart';
import 'package:tekartik_test_menu_flutter/test_menu_flutter.dart';

import 'src/menu_recorder.dart';

/// Key-value pair for debugging configuration.
var kvDebugging = 'debugging'.kvFromVar();

/// Indicates whether debugging is enabled.
bool get debugging {
  return parseBool(kvDebugging.value) ?? false;
}

/// Key-value pair for player configuration.
var kvPlayer = 'player'.kvFromVar();

/// Indicates whether the player is using JustAudio.
bool get isJustAudio {
  return kvPlayer.value == 'just_audio' || kvPlayer.value == null;
}

/// Example audio player song using an asset.
var assetSongExample1 = AppAudioPlayerSong(
  globalCacheOrNull!.assetToSource(assetAudioExample1),
);

/// Example audio player song using a network source.
var networkExample1 = AppAudioPlayerSong(
  'https://media.howob.com/audio_test/sample-9s-mono.mp3',
);

/// Example audio player song using a good network source.
var networkExampleGood2 = AppAudioPlayerSong(
  'https://media.howob.com/audio_test/soundhelix_song_1_30s.mp3',
);

/// Example audio player song using another good network source.
var networkExampleGood6 = AppAudioPlayerSong(
  'https://media.howob.com/audio_test/free_test_data_15s.mp3.mp3',
);

/// Example audio player song using a MIDI network source.
var networkExampleMidiGood7 = AppAudioPlayerSong(
  'https://media.howob.com/audio_test/pop.mid',
);

/// Example audio player song using a network source with CORS.
var networkExample3Cors = AppAudioPlayerSong(
  'https://samplelib.com/lib/preview/mp3/sample-12s.mp3',
);

/// Creates an audio player song from a local file path.
AppAudioPlayerSong localFileSong(String path) =>
    AppAudioPlayerSong(join(kIsWeb ? 'assets/assets' : 'assets', path));

/// Example audio player song using a local file.
var localGood2 = localFileSong('audio/soundhelix_song_1_30s.mp3');

/// Another example audio player song using a local file.
var localGood3 = localFileSong('audio/free_test_data_15s.mp3');

/// Example audio player song using a local MIDI file.
var localMidi = localFileSong('audio/pop.mid');

/// Example audio player song using a local network source.
var networkExample4Local = AppAudioPlayerSong(
  'assets/assets/audio/example1.mp3',
);

/// Example audio player song using a local file source.
var fileExample4Local = AppAudioPlayerSong('assets/audio/example1.mp3');

/// Example audio player song using a missing network source.
var networkExample2Missing = AppAudioPlayerSong(
  'https://firebasestorage.googleapis.com/v0/b/tekartik-free-dev.appspot.com/o/dummy/test%2Fexpected%2Ftest.json?alt=media',
);

/// The application audio player instance.
var appAudioPlayer =
    isJustAudio ? appAudioPlayerJustAudio : appAudioPlayerBlueFire;

/// Main entry point for the test menu.
Future<void> main() async {
  await mainTestMenu();
}

/// Initializes and displays the main test menu.
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
      debugBlueFireAudioPlayer = debugging;
      debugJustAudioPlayer = debugging;
      if (debugging) {
        debugPlayerDumpWriteLn = write;
      }

      debugCacheWriteLn = write;
      write('debugging $debugging');
      if (debugPlayerDumpWriteLn != null) {
        debugPlayerDumpWriteLn!('Dumper on');
      }
      write('using ${isJustAudio ? 'just_audio' : 'blue_fire'}');
    });
    keyValuesMenu('key', [kvDebugging, kvPlayer]);
    item('toggle impl debugging', () {
      var debugging = !debugBlueFireAudioPlayer;
      debugBlueFireAudioPlayer = debugging;
      write('debugging $debugging');
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
        await db.getContent(db.assetToSource(assetAudioExample1));
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

    item('play asset speed x2', () async {
      await initCache();
      var player = await appAudioPlayer.loadSong(assetSongExample1);
      await player.playFromTo(playbackRate: 2);

      write('done');
    });
    item('play asset', () async {
      await initCache();
      await appAudioPlayer.stop();
      await appAudioPlayer.stateStream.firstWhere((state) {
        write('waiting for ready $state');
        return state.isPausedAndReadyForLoading;
      });
      write('ready');
      var completer = Completer<void>();
      var subscription = appAudioPlayer.stateStream.listen((state) {
        write('#state $state');
        if (state.stateEnum == AppAudioPlayerStateEnum.completed) {
          completer.complete();
        }
      });
      write('playing song');
      try {
        await appAudioPlayer.playSong(assetSongExample1);
        write('waiting for state');
        await completer.future;
      } finally {
        subscription.cancel().unawait();
      }
    });
    item('load, seek then play asset', () async {
      await initCache();
      var player = await appAudioPlayer.loadSong(assetSongExample1);

      await player.stateStream.firstWhere((state) {
        write('waiting for ready $state');
        return state.isReady;
      });
      write('ready');
      write('seeking');
      await player.seek(const Duration(seconds: 3));
      await player.fadeIn();

      /// important to resume after a seek
      await player.resume();
      write('play done');
    });
    item('load then play from 5s to 7s', () async {
      await initCache();
      var player = await appAudioPlayer.loadSong(assetSongExample1);
      await player.playFromTo(
        from: const Duration(seconds: 5),
        to: const Duration(seconds: 7),
      );

      write('done');
    });
    item('load then play from 6s to the end', () async {
      await initCache();
      var player = await appAudioPlayer.loadSong(assetSongExample1);
      await player.playFromTo(from: const Duration(seconds: 6));

      write('done');
    });
    item('stop', () async {
      await appAudioPlayer.stop();
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
    void appAudioPlayerMenu(
      AppAudioPlayer appAudioPlayer, {
      String? name,
      @Deprecated('dev only') bool? solo,
    }) {
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
          await appAudioPlayer.playSong(networkExample2Missing);
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
          await appAudioPlayer.dumpPosition();
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

    appAudioPlayerMenu(
      appAudioPlayerJustAudio,
      name: 'use JustAudio (default just_audio)',
    );
    appAudioPlayerMenu(
      appAudioPlayerBlueFire,
      name: 'use BlueFire (legacy audioplayers)',
    );
    menu('recorder', () {
      menuRecorder();
    });
  }, showConsole: true);
}
