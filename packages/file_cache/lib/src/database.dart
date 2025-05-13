import 'dart:typed_data';

import 'package:fs_shim/fs.dart';
import 'package:path/path.dart';
import 'package:sembast/timestamp.dart';
import 'package:tekartik_app_http/app_http.dart' as http;
import 'package:tekartik_file_cache/file_cache.dart';
import 'package:tekartik_file_cache/src/model.dart';

import 'import.dart';

var cvFileStore = CvStoreRef<String, DbFile>('file');

typedef DumpWriteLnFunction = void Function(String msg);
DumpWriteLnFunction? debugCacheWriteLn;

class FileCacheDatabaseOptions {
  final int fileCountMax;

  FileCacheDatabaseOptions({required this.fileCountMax});
}

class FileCacheDatabase {
  final FileSystem fs;
  final DatabaseFactory databaseFactory;
  late final HttpClientFactory httpClientFactory;
  final FileCacheDatabaseOptions options;

  // Root path
  final String? path;

  // Key is the generated path
  final _fetchLockMap = <String, Lock>{};
  Future<Database>? _database;

  FileCacheDatabase({
    required this.fs,
    required this.databaseFactory,
    required this.options,
    this.path,
    HttpClientFactory? httpClientFactory,
  }) {
    this.httpClientFactory = httpClientFactory ?? http.httpClientFactory;
    cvAddConstructor(DbFile.new);
  }

  Future<void> deleteDirectory(String path) async {
    try {
      dumpLine('deleting $path');
      await fs.directory(path).delete(recursive: true);
    } catch (e) {
      try {
        if (await fs.directory(path).exists()) {
          dumpLine('error clearing fie dir $path: $e');
        }
      } catch (e) {
        dumpLine('error checking for directory $path: $e');
      }
    }
  }

  Future<void> clearCache() async {
    await (await getDatabase()).close();
    _database = null;
    await deleteDirectory(filesPath);
    try {
      await databaseFactory.deleteDatabase(databasePath);
    } catch (e) {
      // print('error clearing db $e');
    }
    await deleteDirectory(dataPath);
  }

  void dumpLine(String line) {
    (debugCacheWriteLn ?? print)(line);
  }

  Future<void> dumpDirectory(String path) async {
    dumpLine('listing $path');
    var list = await fs.directory(path).list(recursive: true).toList();
    for (var file in list) {
      dumpLine('file: ${file.path}');
    }
  }

  Future<void> dumpCache() async {
    await dumpDirectory(path ?? '.');
  }

  late final databasePath = () {
    return join(dataPath, 'file_cache.db');
  }();

  Future<Database> getDatabase() async {
    if (_database != null) {
      return _database!;
    }
    var dbName = databasePath;
    return wrap(
      () async {
        _database = databaseFactory.openDatabase(dbName);
        return _database!;
      },
      prefix: 'db',
      details: dbName,
    );
  }

  Future<DbFile> getDbFile(String source) async {
    var db = await getDatabase();
    var record = cvFileStore.record(source);
    return await db.transaction((txn) async {
      var dbFile = await record.get(txn);
      if (dbFile == null) {
        dbFile =
            cvFileStore.record(source).cv()
              ..timestamp.v = Timestamp.now()
              ..fetched.v = false
              ..path.v = await cvFileStore.rawRef.generateKey(txn);
        await dbFile.put(txn);
      }
      return dbFile;
    });
  }

  Future<T> wrap<T>(
    Future<T> Function() action, {
    String? prefix,
    String? details,
  }) async {
    var debugWriteLn = debugCacheWriteLn;
    var sw = debugWriteLn == null ? null : (Stopwatch()..start());
    try {
      return await action();
    } finally {
      if (debugWriteLn != null) {
        dumpLine(
          '${prefix ?? ''} ${sw!.elapsedMilliseconds} ms${details == null ? '' : ' $details'}',
        );
      }
    }
  }

  Future<Uint8List> fetch(String source) async {
    return await wrap(
      () => httpClientFactory.newClient().readBytes(Uri.parse(source)),
      prefix: 'fetch',
      details: source,
    );
  }

  late final dataPath = () {
    var dataPart = 'data';
    if (path != null) {
      return join(path!, dataPart);
    }
    return dataPart;
  }();

  late final filesPath = () {
    var filesPart = 'file';
    if (path != null) {
      return join(path!, filesPart);
    }
    return filesPart;
  }();

  File fileFromPath(String path) {
    return fs.file(join(filesPath, path));
  }

  Future<void> cleanUp() async {
    var db = await getDatabase();
    if (await cvFileStore.rawRef.count(db) > options.fileCountMax) {
      var files = await cvFileStore
          .query(
            finder: Finder(
              filter: Filter.equals(dbFileModel.fetched.key, true),
              sortOrders: [SortOrder(dbFileModel.timestamp.key, false)],
              offset: options.fileCountMax,
            ),
          )
          .getRecords(db);
      for (var file in files) {
        var path = file.path.v!;
        try {
          await fileFromPath(path).delete();
        } catch (e) {
          // print('error $e deleting file $path');
        }
        await file.delete(db);
      }
    }
  }

  Uri? _sourceUri(String source) {
    return Uri.tryParse(source);
  }

  Future<Uint8List> getContent(String source) async {
    return wrap(
      () async {
        if (!isRunningAsJavascript) {
          // Handle io file if scheme is empty
          var uri = _sourceUri(source);
          // debugCacheWriteLn!('wrap $source ${uri?.scheme}');
          if (uri?.scheme.isEmpty ?? false) {
            return await fs.file(uri!.toFilePath()).readAsBytes();
          }
        }
        var dbFile = await getDbFile(source);
        var path = dbFile.path.v!;
        Future<Uint8List> doRead() async {
          return fileFromPath(path).readAsBytes();
        }

        if (dbFile.fetched.v != true) {
          Future<Uint8List> doFetch() async {
            var lock = _fetchLockMap[source] ??= Lock();
            try {
              return await lock.synchronized(() async {
                var dbFile = await getDbFile(source);
                if (dbFile.fetched.v != true) {
                  var content = await fetch(source);
                  try {
                    await fileFromPath(path).writeAsBytes(content, flush: true);
                  } catch (e) {
                    await fileFromPath(path).parent.create(recursive: true);
                    await fileFromPath(path).writeAsBytes(content, flush: true);
                  }
                  dbFile = cvFileStore.record(source).cv()..fetched.v = true;
                  await dbFile.put(await getDatabase(), merge: true);

                  // Cleanup
                  await cleanUp();

                  return content;
                }
                return await doRead();
              });
            } finally {
              _fetchLockMap.remove(source);
            }
          }

          return await doFetch();
        }
        return doRead();
      },
      prefix: 'get',
      details: source,
    );
  }
}
