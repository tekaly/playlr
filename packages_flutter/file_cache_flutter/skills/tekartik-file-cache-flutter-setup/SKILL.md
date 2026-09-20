---
name: tekartik-file-cache-flutter-setup
description: 'Set up the Flutter implementation of the tekartik file cache (tekartik_file_cache_flutter - FileCacheDatabaseFlutter, FileCacheDatabase, FileCacheDatabaseOptions, getContent, assetToSource, clearCache) - creating it once with the app documents directory and a sembast database factory, caching http content on device and on the web, reading asset: sources from the Flutter bundle, and faking it in widget tests. Use when a Flutter app downloads the same media or json repeatedly, or when wiring tekartik_file_cache into Flutter.'
metadata:
  author: tekartik
  package: tekartik_file_cache_flutter
---

# tekartik_file_cache_flutter: setup

`FileCacheDatabaseFlutter` is the Flutter `FileCacheDatabase` (see the
`tekartik-file-cache-database` skill for the cache semantics): it defaults the
file system to the one of `tekartik_app_flutter_fs` (io on mobile/desktop,
indexed db on the web) and it resolves `asset:` sources from the Flutter asset
bundle. `package:tekartik_file_cache_flutter/file_cache_flutter.dart`
re-exports the whole `tekartik_file_cache` API, so it is the only import
needed.

## Contents
- [Dependencies](#dependencies)
- [Guidelines](#guidelines)
- [Examples](#examples)

## Dependencies

Neither package is on pub.dev, depend on them with git. The database factory
comes from the app, not from this package:

```yaml
dependencies:
  tekartik_file_cache_flutter:
    git:
      url: https://github.com/tekaly/playlr.git
      path: packages_flutter/file_cache_flutter
    version: '>=0.0.1'
  # Provides getDatabaseFactory() for mobile, desktop and web.
  tekartik_app_flutter_sembast:
    git:
      url: https://github.com/tekartik/app_flutter_utils.dart
      path: app_sembast
    version: '>=0.1.0'
```

## Guidelines

- Warm the cache up at startup if you want to: `await getFileCache()` right
  after `WidgetsFlutterBinding.ensureInitialized()` in `main()`, so the first
  `getContent` does not pay for the database open.
- Create the cache **once** for the whole app (it opens a sembast database and
  keeps a per source download lock) and hand it around, or keep it in a
  memoized future; never build one per widget or per request.
- `FileCacheDatabaseFlutter({FileSystem? fs, required DatabaseFactory
  databaseFactory, required FileCacheDatabaseOptions options, String? path,
  HttpClientFactory? httpClientFactory})`: only `databaseFactory` and
  `options` are mandatory.
- Leave `fs` null: the default is `fs` of
  `package:tekartik_app_flutter_fs/fs.dart`, which is io on
  Android/iOS/macOS/Linux/Windows and an idb backed file system on the web.
- `databaseFactory`: `getDatabaseFactory(packageName: <bundle id>)` from
  `package:tekartik_app_flutter_sembast/sembast.dart`. `packageName` matters on
  Linux and Windows (it names the data directory) and is ignored elsewhere.
- `path` is the cache root. On io pass
  `(await fs.getApplicationDocumentsDirectory(packageName: <bundle id>)).path`
  (extension of `tekartik_app_flutter_fs`); on the web pass null, the idb file
  system is already private to the app origin. Never hardcode a posix path.
- `options: FileCacheDatabaseOptions(fileCountMax: 100)` caps the number of
  cached files; the oldest fetched entries are deleted after each new download.
- `await cache.getContent(source)` returns the whole content as a `Uint8List`:
  an http(s) url is downloaded once and read from the file system afterwards, a
  source built with `cache.assetToSource('assets/x.mp3')` (i.e. `asset:<key>`)
  is read from `rootBundle` **every time and never cached**, and on io a plain
  path or a `file:` uri is read directly.
- Declare the assets in the app `pubspec.yaml` (`flutter: assets:`) before
  using `asset:` sources, and pass the same key as
  `rootBundle.load`/`AssetImage` (`assets/audio/beep.mp3`).
- `getContent` holds the whole file in memory: use it for audio, images and
  json, not for multi hundred MB downloads.
- Playing audio? Do not create this cache yourself: `playlr_audio_player`
  already builds one with `initCacheDatabase(packageName: ...)` and exposes it
  as `globalCacheOrNull`.
- `await cache.clearCache()` (settings screen, sign out) deletes the files and
  the database; the instance stays usable. `debugCacheWriteLn = print` traces
  every fetch/read with its duration, `await cache.dumpCache()` lists the
  cache directory.
- Widget tests: `getApplicationDocumentsDirectory` needs the path_provider
  platform channel, which is not answered under `flutter test`. Build the cache
  with an in memory file system (`fsMemory` of `tekartik_app_flutter_fs`) and
  `databaseFactoryMemory` instead, or keep the cache behind an interface your
  widgets receive.
- Http downloads on the web go through the browser: the server must send CORS
  headers. If a url fails only on the web, check CORS before the cache.

## Examples

### Creating the app cache once

```dart
// lib/file_cache.dart
import 'package:flutter/foundation.dart';
import 'package:tekartik_app_flutter_fs/fs.dart' as app_fs;
import 'package:tekartik_app_flutter_sembast/sembast.dart';
import 'package:tekartik_file_cache_flutter/file_cache_flutter.dart';

const appPackageName = 'com.example.myapp';

Future<FileCacheDatabase>? _cacheFuture;

/// The one file cache of the app.
Future<FileCacheDatabase> getFileCache() => _cacheFuture ??= _openFileCache();

Future<FileCacheDatabase> _openFileCache() async {
  String? path;
  if (!kIsWeb) {
    // Application documents directory, per platform.
    path = (await app_fs.fs.getApplicationDocumentsDirectory(
      packageName: appPackageName,
    )).path;
  }
  return FileCacheDatabaseFlutter(
    databaseFactory: getDatabaseFactory(packageName: appPackageName),
    options: FileCacheDatabaseOptions(fileCountMax: 100),
    path: path,
  );
}
```

### A widget reading through the cache

```dart
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:tekartik_file_cache_flutter/file_cache_flutter.dart';

/// Displays an image downloaded once and kept on the device.
class CachedImage extends StatelessWidget {
  final FileCacheDatabase cache;
  final String source;

  const CachedImage({super.key, required this.cache, required this.source});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      // In a real widget, keep this future in initState/a State field.
      future: cache.getContent(source),
      builder: (context, snapshot) {
        var bytes = snapshot.data;
        if (snapshot.hasError) {
          return const Icon(Icons.broken_image);
        }
        if (bytes == null) {
          return const CircularProgressIndicator();
        }
        return Image.memory(bytes);
      },
    );
  }
}
```

### Sources: url, asset, device file

```dart
import 'dart:typed_data';

import 'package:tekartik_file_cache_flutter/file_cache_flutter.dart';

Future<void> sources(FileCacheDatabase cache) async {
  // Downloaded once, then read from disk.
  Uint8List remote = await cache.getContent(
    'https://example.com/media/cover.jpg',
  );

  // 'asset:assets/audio/beep.mp3': read from the bundle, not cached.
  var assetSource = cache.assetToSource('assets/audio/beep.mp3');
  Uint8List bundled = await cache.getContent(assetSource);
  print(cache.parseAssetOrNull(assetSource)); // assets/audio/beep.mp3

  // A file on the device (io only), read directly.
  Uint8List local = await cache.getContent('/storage/emulated/0/a.mp3');
}
```

### Settings screen: clear the cache

```dart
import 'package:flutter/material.dart';
import 'package:tekartik_file_cache_flutter/file_cache_flutter.dart';

Widget clearCacheTile(FileCacheDatabase cache) => ListTile(
  title: const Text('Clear the cache'),
  onTap: () async {
    debugCacheWriteLn = print; // trace what happens
    await cache.clearCache();
  },
);
```

### In a widget test: no path_provider, no network

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:tekartik_app_flutter_fs/fs.dart' as app_fs;
import 'package:tekartik_app_flutter_sembast/sembast.dart';
import 'package:tekartik_file_cache_flutter/file_cache_flutter.dart';

void main() {
  test('asset content is read from the bundle', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    var cache = FileCacheDatabaseFlutter(
      fs: app_fs.fsMemory,
      databaseFactory: databaseFactoryMemory,
      options: FileCacheDatabaseOptions(fileCountMax: 10),
      path: '.cache',
    );
    var bytes = await cache.getContent(
      cache.assetToSource('assets/audio/beep.mp3'),
    );
    expect(bytes, isNotEmpty);
  });
}
```
