import 'package:flutter/foundation.dart';
import 'package:synchronized/synchronized.dart';
// ignore: depend_on_referenced_packages
import 'package:tekartik_app_flutter_fs/fs.dart' as app;
import 'package:tekartik_app_flutter_sembast/sembast.dart';
import 'package:tekartik_file_cache_flutter/file_cache_flutter.dart';

export 'package:tekartik_file_cache_flutter/file_cache_flutter.dart';

/// Global cache database
FileCacheDatabase? globalCacheOrNull;
final _lock = Lock();

/// The folder of the cache in the application documents directory.
const _cacheFolderName = 'file_cache';

/// Initializes the cache database (if not already initialized) and sets
/// [globalCacheOrNull].
///
/// The cache lives in [rootPath] when set (its `data/` and `file/` sub
/// folders, deleted by `clearCache()`), otherwise on io in the `file_cache`
/// folder of the application documents directory of [packageName], on the
/// web in the browser storage.
Future<FileCacheDatabase> initCacheDatabase({
  String? rootPath,
  required String packageName,
}) async {
  if (globalCacheOrNull != null) {
    return globalCacheOrNull!;
  }
  return await _lock.synchronized(() async {
    if (globalCacheOrNull != null) {
      return globalCacheOrNull!;
    }
    var databaseFactory = getDatabaseFactory();
    var path = rootPath;
    app.FileSystem? fs;
    if (path == null) {
      if (!kIsWeb) {
        fs = app.fs;
        // A folder of its own: clearCache() deletes its data and file
        // folders.
        path = fs.path.join(
          (await fs.getApplicationDocumentsDirectory(
            packageName: packageName,
          )).path,
          _cacheFolderName,
        );
      }
    }
    var db = FileCacheDatabaseFlutter(
      databaseFactory: databaseFactory,
      options: FileCacheDatabaseOptions(fileCountMax: 100),
      path: path,
    );
    globalCacheOrNull = db;
    return db;
  });
}
