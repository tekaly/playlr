---
name: playlr-audio-player-playback
description: 'Play audio in a Flutter app with the playlr AppAudioPlayer abstraction (playlr_audio_player) - play a song from bytes, a url, a file or an asset, pause/resume/seek, playback rate, volume, fades, clips (play from/to), state and position streams, chaining songs when one completes. Use when writing or debugging code that plays audio through AppAudioPlayer, AppAudioPlayerSong, SongAudioPlayer or an implementation such as playlr_audio_player_just_audio.'
metadata:
  author: tekartik
  package: playlr_audio_player
---

# playlr_audio_player: playing audio

`package:playlr_audio_player/player.dart` is a small, backend independent audio
player facade for Flutter (web, mobile, desktop). An app talks to one
`AppAudioPlayer`; the actual decoding is done by an implementation package
(`playlr_audio_player_just_audio` on every platform, `playlr_audio_player_blue_fire`
as an alternative), see their own skills for the setup.

## Contents
- [Key types](#key-types)
- [Guidelines](#guidelines)
- [Examples](#examples)

## Key types

| Type | Role |
|---|---|
| `AppAudioPlayer` | The app level player: loads a song, becomes the *current* player, exposes the streams of the current song. One instance per app. |
| `AppAudioPlayerSong` | A source string: an `http(s)` url, a file path (`AppAudioPlayerSong.file(path)`), an asset (`AppAudioPlayerSong.asset(key)`, i.e. `asset:<key>`). Resolved through the global cache, see the `playlr-audio-player-cache` skill. |
| `SongAudioPlayer` | The player of one song, returned by `playSong`/`playBytes`. Same control API as `AppAudioPlayer` (`AppOrSongAudioPlayer`), plus `dispose()`. |
| `AppAudioPlayerState` | `stateEnum` (`none`, `preparing`, `ready`, `completed`), `playing`, `duration`, `position` (extrapolated while playing). `isReady`, `isPreparing`, `isPausedAndReadyForLoading`. |
| `SongAudioPlayerExtension` | Helpers on any player: `forward(duration)`, `playFromTo(from:, to:, playbackRate:)`, `fadeIn()`, `fadeOut()`, `isPlayingSync()`. |

Control API (`AppOrSongAudioPlayer`): `play()`, `pause()`, `resume()`, `stop()`,
`seek(position)`, `setPlaybackRate(rate)`, `setVolume(volume)`,
`getCurrentPosition()`, `getCurrentPositionSync()`, `getDuration()`,
`positionStream`, `stateStream`, `stateValue`.

## Guidelines

- Create **one** `AppAudioPlayer` for the whole app (from an implementation
  package, e.g. `AppAudioPlayerJustAudio()` or the `appAudioPlayerJustAudio`
  singleton) and keep it in your app context. Never create one per song: the
  player manages its own pool of `SongAudioPlayer`s (the last 3 are kept,
  older ones are disposed).
- Pick the loading path that matches where the audio bytes come from:
  - `playBytes(Uint8List bytes)` / `loadBytes(bytes)` when the app already has
    the content (its own download, its own cache, an in-memory file). No
    global cache is involved. Prefer this in an app that manages its files.
  - `playSong(AppAudioPlayerSong song)` / `loadSong(song)` when the app only
    has a source string. The bytes are read through the global cache, which
    **must** have been initialized with `initCacheDatabase(...)` first;
    otherwise `loadSong` throws a `StateError` ("No global cache").
- `playSong`/`playBytes` stop the current song, start the new one and return
  **before** playback ends. To play a list, listen to `stateStream` and move on
  when `stateEnum == AppAudioPlayerStateEnum.completed` (see the queue
  example). Do not poll `getDuration()` to detect the end.
- Drive a seek bar from `positionStream` (about 10 updates per second while
  playing, `null` when nothing is loaded) and the `duration` of the last
  `stateStream` event; `getDuration()` returns null until the song is ready.
- `stop()` is final for the current `SongAudioPlayer`: to play the same song
  again call `playSong`/`playBytes` again rather than `play()` on a stopped
  player. Use `pause()`/`resume()` for a resumable pause.
- Re-apply `setPlaybackRate` and `setVolume` after each `playSong`/`playBytes`
  when the app keeps a non default rate or a mute state: loading a new source
  resets them on some backends. `setVolume(0)` is how to mute.
- Play a fragment of a file with `playFromTo(from: ..., to: ...)` on the player
  returned by `loadSong`/`loadBytes`: it waits for the song to be ready, seeks,
  fades in, fades out at `to`, pauses and completes. For a live player (a seek
  bar that must stay within a clip) implement the clip yourself: `seek(start)`
  after loading, watch `positionStream` and move on at the end mark (example
  below).
- Never hold a `SongAudioPlayer` beyond the current song: the pool disposes
  older ones. Keep the `AppAudioPlayer` and read `currentPlayer` when needed.
- `flutter test` cannot play audio: platform channels never answer, so a
  `playSong` awaited in a widget test hangs. Put the playback logic in a
  controller that can be unit tested without the player (queue, repeat, clip
  bounds) and keep the `AppAudioPlayer` calls in a thin layer.
- Debugging: set `debugPlayerDumpWriteLn = print` to trace the state events,
  `await player.dumpPosition()` prints the current position.

## Examples

### Play the bytes the app already has

```dart
import 'package:playlr_audio_player/player.dart';
import 'package:playlr_audio_player_just_audio/player.dart';

/// One player for the app.
final AppAudioPlayer audioPlayer = AppAudioPlayerJustAudio();

Future<void> playDownloadedSong(Uint8List bytes, {double rate = 1}) async {
  // Stops the current song, starts this one, returns right away.
  await audioPlayer.playBytes(bytes);
  if (rate != 1) {
    // Loading a source resets the rate on some backends: apply it after.
    await audioPlayer.setPlaybackRate(rate);
  }
}
```

### Play a url, a file or an asset through the cache

```dart
import 'package:flutter/widgets.dart';
import 'package:playlr_audio_player/cache.dart';
import 'package:playlr_audio_player/player.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Required once before any playSong/loadSong.
  await initCacheDatabase(packageName: 'com.example.myapp');
  runApp(const MyApp());
}

Future<void> playUrl(AppAudioPlayer player) =>
    player.playSong(AppAudioPlayerSong('https://example.com/song.mp3'));

Future<void> playAsset(AppAudioPlayer player) =>
    player.playSong(AppAudioPlayerSong.asset('assets/audio/intro.mp3'));

Future<void> playFile(AppAudioPlayer player, String path) =>
    player.playSong(AppAudioPlayerSong.file(path));
```

### Chain songs: move on when the current one completes

```dart
class SongQueue {
  final AppAudioPlayer player;
  final List<Uint8List> songs;
  var _index = -1;
  late final StreamSubscription<AppAudioPlayerState> _subscription;

  SongQueue(this.player, this.songs) {
    _subscription = player.stateStream.listen((state) {
      if (state.stateEnum == AppAudioPlayerStateEnum.completed) {
        // The song ended on its own.
        next();
      }
    });
  }

  Future<void> next() async {
    if (_index + 1 >= songs.length) {
      await player.stop();
      return;
    }
    _index++;
    await player.playBytes(songs[_index]);
  }

  Future<void> dispose() => _subscription.cancel();
}
```

### A seek bar on the position and duration streams

```dart
StreamBuilder<Duration?>(
  stream: player.positionStream,
  builder: (context, snapshot) {
    var position = snapshot.data ?? Duration.zero;
    // The duration comes with the state events (null until ready).
    var duration = player.stateValue.duration;
    var max = duration?.inMilliseconds.toDouble() ?? 0;
    return Slider(
      value: max <= 0 ? 0 : position.inMilliseconds.toDouble().clamp(0, max),
      max: max <= 0 ? 1 : max,
      onChanged: max <= 0
          ? null
          : (value) => player.seek(Duration(milliseconds: value.round())),
    );
  },
)
```

### Play only a fragment (clip) of a song

```dart
// One shot: waits for the end of the clip (fades in and out).
var songPlayer = await player.loadBytes(bytes);
await songPlayer.playFromTo(
  from: const Duration(seconds: 130, milliseconds: 789),
  to: const Duration(seconds: 132, milliseconds: 123),
);

// Live player: seek to the start after loading, stop at the end mark.
await player.playBytes(bytes);
await player.seek(clipStart);
final positionSubscription = player.positionStream.listen((position) {
  if (position != null && position >= clipEnd) {
    // The file plays on past the clip: move to the next song here.
    queue.next();
  }
});
```

### Pause/resume, mute, speed

```dart
Future<void> togglePlayPause(AppAudioPlayer player) async {
  if (player.stateValue.playing) {
    await player.pause();
  } else {
    await player.resume();
  }
}

Future<void> setMuted(AppAudioPlayer player, bool muted) =>
    player.setVolume(muted ? 0 : 1);

Future<void> setSpeed(AppAudioPlayer player, double rate) =>
    player.setPlaybackRate(rate); // 0.5, 1, 1.5, 2...
```
