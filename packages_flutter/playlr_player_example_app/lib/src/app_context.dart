import 'dart:io' as io;

import 'package:flutter/foundation.dart';
import 'package:playlr_audio_player/cache.dart';
// ignore: depend_on_referenced_packages
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Application (bundle) name, used for the cache location.
const appPackageName = 'com.tekartik.playlr.playerexample';

/// Initializes what the app needs before running: the file cache used by the
/// player to read the audio content (asset, file or url) as bytes.
Future<void> initAppContext() async {
  if (!kIsWeb && io.Platform.isWindows) {
    sqfliteFfiInit();
  }
  await initCacheDatabase(packageName: appPackageName);
}
