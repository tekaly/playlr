import 'package:flutter/foundation.dart';
import 'package:synchronized/synchronized.dart';
// ignore: depend_on_referenced_packages
import 'package:tekartik_app_flutter_fs/fs.dart' as app;
import 'package:tekartik_file_cache_flutter/file_cache_flutter.dart';

import 'package:tekartik_app_flutter_sembast/sembast.dart';
export 'package:tekartik_file_cache_flutter/file_cache_flutter.dart';

FileCacheDatabase? globalCacheOrNull;
final _lock = Lock();
Future<FileCacheDatabase> initCacheDatabase(
    {required String packageName}) async {
  if (globalCacheOrNull != null) {
    return globalCacheOrNull!;
  }
  return await _lock.synchronized(() async {
    if (globalCacheOrNull != null) {
      return globalCacheOrNull!;
    }
    var databaseFactory = getDatabaseFactory();
    String? path;
    app.FileSystem? fs;
    if (!kIsWeb) {
      fs = app.fs;
      path =
          (await fs.getApplicationDocumentsDirectory(packageName: packageName))
              .path;
    }
    var db = FileCacheDatabaseFlutter(
        databaseFactory: databaseFactory,
        options: FileCacheDatabaseOptions(fileCountMax: 100),
        path: path);
    globalCacheOrNull = db;
    return db;
  });
}
