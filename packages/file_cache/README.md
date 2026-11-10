# tekartik_file_cache

A cache of downloaded files: `FileCacheDatabase.getContent(source)` fetches a
url once, writes the bytes in a [fs_shim](https://pub.dev/packages/fs_shim)
file system and indexes them in a [sembast](https://pub.dev/packages/sembast)
database; the next calls read the local file. The oldest fetched files are
evicted beyond `fileCountMax`. Pure Dart (io, web, memory). Flutter apps use
`tekartik_file_cache_flutter` (same API, plus `asset:` sources read from the
asset bundle).

## Getting started

Not on pub.dev, add it as a git dependency:

```yaml
dependencies:
  tekartik_file_cache:
    git:
      url: https://github.com/tekaly/playlr.git
      path: packages/file_cache
```

```dart
import 'package:fs_shim/fs_io.dart';
import 'package:path/path.dart';
import 'package:sembast/sembast_io.dart';
import 'package:tekartik_file_cache/file_cache.dart';

Future<void> main() async {
  var cache = FileCacheDatabase(
    fs: fileSystemIo,
    databaseFactory: databaseFactoryIo,
    options: FileCacheDatabaseOptions(fileCountMax: 100),
    // Absolute: everything lives under it.
    path: absolute('.local', 'file_cache'),
  );
  var source = 'https://tekartik-test-fixtures.web.app/http/connected.json';
  var bytes = await cache.getContent(source); // fetched
  bytes = await cache.getContent(source); // read from the local file
  print('${bytes.length} bytes');
}
```

Offline example (memory file system, database and http server):
[example/main.dart](example/main.dart).

## Platforms

- io: `fileSystemIo` and a sembast io (or sqflite) factory.
- Web (dart2js and dart2wasm): the fs_shim IndexedDB file system and
  sembast_web; the server must allow CORS.
- Memory (tests): `newFileSystemMemory()`, `newDatabaseFactoryMemory()` and
  `httpClientFactoryMemory`.

## What to use

- `FileCacheDatabase(fs:, databaseFactory:, options:, path:,
  httpClientFactory:)`: one per cache folder, kept (it holds a per source
  lock). `path` holds `data/file_cache.db` and the `file/` folder.
- `getContent(source)`: the bytes, fetched the first time.
- `getDbFile(source)` (`DbFile`: `path`, `fetched`, `timestamp`),
  `fileFromPath(path)`, `clearCache()`, `dumpCache()`,
  `debugCacheWriteLn = print` (traces with durations).

## Sources

- `http://` and `https://` urls: cached, keyed by the exact string (do not
  cache signed or cache busting urls).
- A path or a `file:` uri on io: read from the file system, not cached.
  Pass a `file:` uri (`Uri.file(path).toString()`): a Windows path
  (`C:\...`) is taken for a url and a path holding `#` or `?` throws.
- A source without scheme on the web is a url relative to the page (dart2js
  and dart2wasm alike since 2026-11-10).
- `asset:<key>` (`assetToSource(key)`): never cached; only the Flutter
  implementation reads it (from the asset bundle).

## Common pitfalls

- Use an absolute `path`: a relative one is resolved against the current
  directory by the file system but against its own folder by some database
  factories.
- The whole content is in memory: fine for audio, images and json, not for
  huge files.
- `fileCountMax` evicts the oldest fetched files: keep it above the working
  set, an evicted source is simply fetched again.
- A cached file deleted outside the cache is fetched again on the next
  `getContent` (since 2026-11-10; before, every call failed).

Agent skill:
[tekartik-file-cache-database](skills/tekartik-file-cache-database/SKILL.md).
