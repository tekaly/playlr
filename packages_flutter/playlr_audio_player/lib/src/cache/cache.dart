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

/// Initializes the cache database (if not already initialized).
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
        path = (await fs.getApplicationDocumentsDirectory(
          packageName: packageName,
        )).path;
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
