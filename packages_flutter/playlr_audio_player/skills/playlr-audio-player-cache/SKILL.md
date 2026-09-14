---
name: playlr-audio-player-cache
description: 'Set up and use the playlr audio content cache (package:playlr_audio_player/cache.dart, initCacheDatabase, globalCacheOrNull, FileCacheDatabase) that resolves AppAudioPlayerSong sources - http(s) urls cached on disk, asset: keys from the bundle, file paths - before playSong. Use when an app calls playSong/loadSong, when the player throws "No global cache", or when deciding between playSong and playBytes.'
metadata:
  author: tekartik
  package: playlr_audio_player
---

# playlr_audio_player: the audio content cache

`AppAudioPlayer.playSong(AppAudioPlayerSong)` never streams a url: it reads the
whole content as bytes through a global `FileCacheDatabase`
(`package:tekartik_file_cache_flutter`, re-exported by
`package:playlr_audio_player/cache.dart`) and hands the bytes to the backend.
The cache is what turns a source string into bytes; it has to exist before the
first `playSong`.

## Contents
- [How a source is resolved](#how-a-source-is-resolved)
- [Guidelines](#guidelines)
- [Examples](#examples)

## How a source is resolved

`globalCacheOrNull!.getContent(source)`:

| Source | Behavior |
|---|---|
| `https://...` / `http://...` | Fetched with the http client, written under `<path>/file/`, indexed in a sembast database under `<path>/data/`, kept up to `fileCountMax` files (100 by default, oldest evicted). Read from disk afterwards. |
| `asset:<key>` (`AppAudioPlayerSong.asset(key)`, `cache.assetToSource(key)`) | Read from the Flutter asset bundle (`rootBundle`), **not** cached. |
| A plain path or `file:` uri (`AppAudioPlayerSong.file(path)`), io only | Read from the file system directly, not cached. |
| A relative path on the web (`assets/<key>`) | Fetched over http from the web app origin (a bundled asset served by the app). |

`initCacheDatabase({required String packageName, String? rootPath})` creates
the database once (idempotent, lock protected) and sets `globalCacheOrNull`.
On io the default `rootPath` is the application documents directory of
`packageName`; on the web it is an idb backed file system.

## Guidelines

- Call `await initCacheDatabase(packageName: '<bundle id>')` once at startup,
  after `WidgetsFlutterBinding.ensureInitialized()` and before the first
  `playSong`/`loadSong`. `packageName` is the app bundle id (it names the
  documents directory), not the pub package name.
- On Windows call `sqfliteFfiInit()` (`package:sqflite_common_ffi`) before
  `initCacheDatabase`: the cache index is a sembast database on sqflite there.
- Do **not** set up this cache when the app already downloads and stores its
  audio (its own file cache, a synced database of bytes): read the bytes
  yourself and call `playBytes(bytes)` instead. Two caches of the same content
  is the anti-pattern.
- Build asset sources with `AppAudioPlayerSong.asset(key)` (or
  `globalCacheOrNull!.assetToSource(key)`) and declare the asset in
  `pubspec.yaml`; do not pass a bare asset key, it would be taken for a file
  path (io) or a relative url (web).
- Url sources are cached by their exact string: a signed url that changes on
  every request fills the cache; strip the volatile part or use `playBytes`.
- `await globalCacheOrNull!.clearCache()` empties the cache,
  `dumpCache()` lists it (debug). `debugCacheWriteLn` style tracing goes
  through `dumpLine`.
- The error `StateError: No global cache: call initCacheDatabase() first, or
  play the audio content with playBytes()/loadBytes()` means `playSong` ran
  before `initCacheDatabase` (or in a code path that should use `playBytes`).

## Examples

### App startup with the cache

```dart
import 'dart:io' as io;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:playlr_audio_player/cache.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const appPackageName = 'com.example.myplayer';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb && io.Platform.isWindows) {
    sqfliteFfiInit();
  }
  await initCacheDatabase(packageName: appPackageName);
  runApp(const MyApp());
}
```

### Sources

```dart
import 'package:playlr_audio_player/cache.dart';
import 'package:playlr_audio_player/player.dart';

// A bundled asset (declared in pubspec.yaml), read from the bundle.
var intro = AppAudioPlayerSong.asset('assets/audio/intro.mp3');
// Same thing through the cache helper.
var intro2 = AppAudioPlayerSong(
  globalCacheOrNull!.assetToSource('assets/audio/intro.mp3'),
);
// A url, downloaded once then read from disk.
var remote = AppAudioPlayerSong('https://example.com/audio/song.mp3');
// A file on the device (io).
var local = AppAudioPlayerSong.file('/storage/emulated/0/Music/song.mp3');
```

### Reading content without playing it

```dart
// The same resolution the player uses, for a waveform, a checksum...
var bytes = await globalCacheOrNull!.getContent(remote.source);
```

### An app with its own storage: skip the cache

```dart
// The app already keeps the audio files (downloaded from its backend).
var bytes = await myFileSystem.file(songPath).readAsBytes();
await audioPlayer.playBytes(bytes); // no initCacheDatabase needed
```
