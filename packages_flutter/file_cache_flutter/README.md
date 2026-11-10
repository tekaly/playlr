# tekartik_file_cache_flutter

A download cache for Flutter apps: `getContent(url)` downloads a file once,
keeps it on the device and reads it from there afterwards; the oldest files
are dropped past a maximum count. Also reads `asset:` sources from the
Flutter bundle. Built on `tekartik_file_cache` (whose API it re-exports).

Platforms: Android, iOS, macOS, Linux, Windows (files on disk), web (files
in IndexedDB, downloads through the browser: the server must send CORS
headers).

## Getting started

```yaml
dependencies:
  tekartik_file_cache_flutter:
    git:
      url: https://github.com/tekaly/playlr.git
      path: packages_flutter/file_cache_flutter
  # The database factory and the app folders.
  tekartik_app_flutter_sembast:
    git:
      url: https://github.com/tekartik/app_flutter_utils.dart
      path: app_sembast
  tekartik_app_flutter_fs:
    git:
      url: https://github.com/tekartik/app_flutter_utils.dart
      path: app_fs
```

Create the cache once for the app, in a folder of its own:

```dart
import 'package:flutter/foundation.dart';
import 'package:tekartik_app_flutter_fs/fs.dart' as app_fs;
import 'package:tekartik_app_flutter_sembast/sembast.dart';
import 'package:tekartik_file_cache_flutter/file_cache_flutter.dart';

const appPackageName = 'com.example.myapp';

Future<FileCacheDatabase>? _cache;

/// The file cache of the app, created on first use.
Future<FileCacheDatabase> getFileCache() => _cache ??= () async {
  String? path;
  if (!kIsWeb) {
    var documents = await app_fs.fs.getApplicationDocumentsDirectory(
      packageName: appPackageName,
    );
    // Its own folder: clearCache() deletes the data/ and file/ folders of
    // path.
    path = app_fs.fs.path.join(documents.path, 'file_cache');
  }
  return FileCacheDatabaseFlutter(
    databaseFactory: getDatabaseFactory(packageName: appPackageName),
    options: FileCacheDatabaseOptions(fileCountMax: 100),
    path: path,
  );
}();

Future<Uint8List> cover() async =>
    (await getFileCache()).getContent('https://example.com/cover.jpg');
```

## Sources

- `https://...`: downloaded once (keyed by the exact string), then read
  from the device; fetched again if its file is gone.
- `cache.assetToSource('assets/beep.mp3')` (`asset:assets/beep.mp3`): read
  from the Flutter bundle each time, never cached (declare the asset in the
  app `pubspec.yaml`).
- A file of the device (io only): pass `Uri.file(path).toString()`, read
  directly, not cached.

## Pitfalls

- One cache per app (a sembast database and a download lock per source),
  never one per widget.
- The database opens on the first `getContent`, not when the cache is
  created.
- `getContent` returns the whole content in memory: fine for images, audio,
  json; not for huge downloads.
- A raw path with `#` or `?` (or a Windows path) is not a valid source:
  use `Uri.file(path).toString()`.
- `clearCache()` deletes the files and the database; the cache stays
  usable.
- Widget tests: no path_provider; build it with `fs: app_fs.fsMemory` and
  `databaseFactoryMemory` (see the skill).

More in the [package skill](skills/tekartik-file-cache-flutter-setup/SKILL.md)
and the `tekartik-file-cache-database` skill of `tekartik_file_cache`.
