---
name: tekartik-file-cache-database
description: 'Cache remote files on disk in a Dart app with tekartik_file_cache - FileCacheDatabase, FileCacheDatabaseOptions(fileCountMax), getContent, fetch, getDbFile, clearCache, cleanUp, dumpCache, DbFile, cvFileStore, dbFileModel, debugCacheWriteLn, assetToSource. Use when downloading the same http(s) content repeatedly (audio, images, json), when wiring the cache to a fs_shim file system and a sembast database factory, when inspecting or clearing what was cached, or when testing it with the memory file system and the memory http client.'
metadata:
  author: tekartik
  package: tekartik_file_cache
---

# tekartik_file_cache: a file cache database

`FileCacheDatabase` downloads a source url once, writes the bytes on a
[fs_shim](https://pub.dev/packages/fs_shim) file system and indexes them in a
[sembast](https://pub.dev/packages/sembast) database, so the next
`getContent(source)` reads the local file. It is pure Dart (io, web, memory);
Flutter apps use `tekartik_file_cache_flutter` (same API, plus `asset:` sources
read from the asset bundle).

## Contents
- [Dependency](#dependency)
- [What getContent does](#what-getcontent-does)
- [Guidelines](#guidelines)
- [Examples](#examples)

## Dependency

The package is not on pub.dev, depend on it with git:

```yaml
dependencies:
  tekartik_file_cache:
    git:
      url: https://github.com/tekaly/playlr.git
      path: packages/file_cache
    version: '>=0.0.1'
```

## What getContent does

`await cache.getContent(source)` returns the whole content as a `Uint8List`:

| Source | Behavior |
|---|---|
| `https://...`, `http://...` | Fetched once through the `HttpClientFactory`, written under `<path>/file/<generated key>`, indexed in the sembast database `<path>/data/file_cache.db`. Later calls read the local file. |
| `asset:<key>` | Never cached: `fetch()` is called every time (the base class does an http read, `tekartik_file_cache_flutter` reads the Flutter asset bundle). |
| a path or a `file:` uri | Read straight from the file system, not cached. VM/io only: on the web (`isRunningAsJavascript`) such a source goes through http, relative to the page. |

The cache is keyed by the **exact source string**.

## Guidelines

- Create one `FileCacheDatabase` per cache root and keep it (it lazily opens
  the database and holds a per source fetch lock):
  `FileCacheDatabase(fs: ..., databaseFactory: ..., options:
  FileCacheDatabaseOptions(fileCountMax: 100), path: ..., httpClientFactory:
  ...)`.
- `fs` (`package:fs_shim/fs_io.dart` `fileSystemIo`, `fs_memory.dart`
  `newFileSystemMemory()`) and `databaseFactory`
  (`package:sembast/sembast_io.dart` `databaseFactoryIo`, `sembast_memory.dart`
  `newDatabaseFactoryMemory()`) are required and must match the platform.
- `httpClientFactory` is optional: it defaults to `httpClientFactory` of
  `package:tekartik_app_http/app_http.dart` (io or browser, picked
  automatically). Pass `httpClientFactoryMemory` in tests.
- `path` is the cache root directory; everything lives under it
  (`dataPath` = `<path>/data`, `filesPath` = `<path>/file`,
  `databasePath` = `<path>/data/file_cache.db`). When `path` is null those are
  relative to the current directory: always pass an absolute application
  directory in a real app.
- `fileCountMax` is a hard cap enforced by `cleanUp()` after every new fetch:
  the fetched records are sorted by `timestamp` and everything beyond
  `fileCountMax` is deleted (file + record). An evicted source is simply
  fetched again on the next `getContent`, so keep `fileCountMax` well above the
  working set.
- Concurrent `getContent` calls for the same source share a single download (a
  `Lock` per source); different sources download in parallel.
- `getContent` holds the whole file in memory: fine for audio/images/json, not
  for very large files.
- Do not cache urls that change on each request (signed urls, cache busting
  query parameters): each variant becomes a new entry and evicts the others.
  Normalize the source string first.
- `await cache.clearCache()` closes the database, deletes the files directory,
  the database and the data directory; the instance stays usable (the database
  is reopened on the next call).
- Metadata: `await cache.getDbFile(source)` returns (and creates if missing) a
  `DbFile` with `path` (generated local file name), `fetched` (bool) and
  `timestamp` (sembast `Timestamp`) `CvField`s; `cache.fileFromPath(dbFile
  .path.v!)` gives the fs_shim `File`. Query the store with `cvFileStore` and
  `dbFileModel` (field keys) on `await cache.getDatabase()`.
- Debug: set `debugCacheWriteLn = print` (a `DumpWriteLnFunction`) to trace
  every db open, fetch and get with its duration; `await cache.dumpCache()`
  lists the cache directory.
- `assetToSource(key)` / `parseAssetOrNull(source)` (extension
  `FileCacheDatabaseAssetExt`) build and recognize `asset:` sources; they are
  only useful with the Flutter implementation.
- In a Flutter app do not build `FileCacheDatabase` directly: use
  `FileCacheDatabaseFlutter` (`tekartik_file_cache_flutter`), or
  `initCacheDatabase()` of `playlr_audio_player` when playing audio.
- Tests run fully offline with the memory file system, the memory database
  factory and `httpServerFactoryMemory`/`httpClientFactoryMemory`: no io, no
  network, nothing to clean up.

## Examples

### A cache on the file system (io)

```dart
import 'package:fs_shim/fs_io.dart' show fileSystemIo;
import 'package:sembast/sembast_io.dart';
import 'package:tekartik_file_cache/file_cache.dart';

Future<void> main() async {
  var cache = FileCacheDatabase(
    fs: fileSystemIo,
    databaseFactory: databaseFactoryIo,
    options: FileCacheDatabaseOptions(fileCountMax: 100),
    path: '.local/file_cache',
  );

  const source = 'https://example.com/media/song.mp3';
  // Downloaded and stored the first time...
  var content = await cache.getContent(source);
  print('${content.length} bytes');
  // ...read from the local file afterwards.
  content = await cache.getContent(source);
}
```

### Inspecting and clearing the cache

```dart
import 'package:tekartik_file_cache/file_cache.dart';

Future<void> inspect(FileCacheDatabase cache, String source) async {
  // Trace db/fetch/get durations.
  debugCacheWriteLn = print;

  var dbFile = await cache.getDbFile(source);
  print('fetched: ${dbFile.fetched.v} on ${dbFile.timestamp.v}');
  if (dbFile.fetched.v == true) {
    var file = cache.fileFromPath(dbFile.path.v!);
    print('local file ${file.path}, ${(await file.stat()).size} bytes');
  }

  await cache.dumpCache(); // lists the cache directory
  await cache.clearCache(); // files + database
}
```

### Listing the cached entries

```dart
import 'package:tekartik_app_cv_sembast/app_cv_sembast.dart';
import 'package:tekartik_file_cache/file_cache.dart';

/// Sources currently in the cache, most recent first.
Future<List<String>> cachedSources(FileCacheDatabase cache) async {
  var db = await cache.getDatabase();
  var records = await cvFileStore
      .query(
        finder: Finder(
          filter: Filter.equals(dbFileModel.fetched.key, true),
          sortOrders: [SortOrder(dbFileModel.timestamp.key, false)],
        ),
      )
      .getRecords(db);
  return records.map((record) => record.id).toList();
}
```

### Testing with the memory file system and a memory http server

```dart
import 'dart:typed_data';

import 'package:fs_shim/fs_memory.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:tekartik_app_http/app_http.dart';
import 'package:tekartik_file_cache/file_cache.dart';
import 'package:test/test.dart';

void main() {
  late HttpServer server;
  late FileCacheDatabase cache;
  var fetchCount = 0;

  setUp(() async {
    server = await httpServerFactoryMemory.bind(InternetAddress.anyIPv4, 1);
    server.listen((request) async {
      fetchCount++;
      request.response.add(Uint8List.fromList([1, 2, 3]));
      await request.response.close();
    });
    cache = FileCacheDatabase(
      fs: newFileSystemMemory(),
      databaseFactory: newDatabaseFactoryMemory(),
      httpClientFactory: httpClientFactoryMemory,
      options: FileCacheDatabaseOptions(fileCountMax: 2),
    );
  });
  tearDown(() async {
    await server.close(force: true);
  });

  test('content is fetched once', () async {
    var source = server.clientUri.toString();
    expect((await cache.getDbFile(source)).fetched.v, isFalse);
    expect(await cache.getContent(source), [1, 2, 3]);
    expect(await cache.getContent(source), [1, 2, 3]);
    expect((await cache.getDbFile(source)).fetched.v, isTrue);
    expect(fetchCount, 1);
  });
}
```
