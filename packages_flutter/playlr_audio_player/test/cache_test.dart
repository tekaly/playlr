import 'dart:io' as io;

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:playlr_audio_player/cache.dart';
// ignore: depend_on_referenced_packages
import 'package:tekartik_app_flutter_fs/fs.dart' as app;

void main() {
  // getApplicationDocumentsDirectory needs no plugin on linux (and windows,
  // where the cache database needs sqfliteFfiInit() first).
  var skip = io.Platform.isLinux
      ? null
      : 'linux only (path_provider plugin, sqflite ffi setup)';
  group('initCacheDatabase', () {
    test('clearCache keeps the files of the documents directory', () async {
      var packageName =
          'tekaly.playlr_audio_player.test_${DateTime.now().microsecondsSinceEpoch}';
      var documents = await app.fs.getApplicationDocumentsDirectory(
        packageName: packageName,
      );
      // documents is <userAppDataPath>/<packageName>/data
      var appRoot = io.Directory(dirname(documents.path));
      // Files of the app, next to the cache
      var appFiles = [
        io.File(join(documents.path, 'data', 'app.json')),
        io.File(join(documents.path, 'file', 'note.txt')),
      ];
      try {
        for (var file in appFiles) {
          await file.create(recursive: true);
          await file.writeAsString('kept');
        }
        globalCacheOrNull = null;
        var cache = await initCacheDatabase(packageName: packageName);
        await cache.getDatabase();
        await cache.clearCache();
        for (var file in appFiles) {
          expect(file.existsSync(), isTrue, reason: file.path);
        }
        // The cache lives in a folder of its own.
        expect(cache.path, isNot(documents.path));
        expect(isWithin(documents.path, cache.path!), isTrue);
      } finally {
        globalCacheOrNull = null;
        if (appRoot.existsSync()) {
          await appRoot.delete(recursive: true);
        }
      }
    }, timeout: const Timeout(Duration(seconds: 30)));
  }, skip: skip);
}
