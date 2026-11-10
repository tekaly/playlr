---
name: playlr-audio-player-blue-fire-setup
description: 'Set up the audioplayers (blue_fire) implementation of the playlr audio player (playlr_audio_player_blue_fire - AppAudioPlayerBlueFire, appAudioPlayerBlueFire, debugBlueFireAudioPlayer) in a Flutter app on Android, iOS, macOS, web, Windows and Linux - dependency, creating the player, playBytes/playSong, waiting for loaded, state and position streams, no url streaming, Linux temp file and duration caveats, debugging. Use when adding audio playback with playlr, when choosing between the blue_fire and just_audio backends, or when playback or duration misbehaves on one platform.'
metadata:
  author: tekartik
  package: playlr_audio_player_blue_fire
---

# playlr_audio_player_blue_fire: setup

`AppAudioPlayerBlueFire` is the `AppAudioPlayer` of `playlr_audio_player` (see
the `playlr-audio-player-playback` skill) implemented with
`package:audioplayers` (the Blue Fire package). The content always reaches
audioplayers as **bytes**: the same code path plays a download, a cached file
or an asset on every platform, no url is ever handed to the native player
(`playUri`/`loadUri` throw an `UnsupportedError`: streaming an url needs the
just_audio backend).

## Contents
- [Dependencies](#dependencies)
- [Guidelines](#guidelines)
- [Examples](#examples)

## Dependencies

Neither package is on pub.dev, depend on them with git:

```yaml
dependencies:
  playlr_audio_player:
    git:
      url: https://github.com/tekaly/playlr.git
      path: packages_flutter/playlr_audio_player
  playlr_audio_player_blue_fire:
    git:
      url: https://github.com/tekaly/playlr.git
      path: packages_flutter/playlr_audio_player_blue_fire
```

`audioplayers` brings its own platform implementations (android, darwin, web,
windows, linux), so nothing else goes in the app pubspec. On Linux the
GStreamer development packages that `audioplayers_linux` builds against must be
installed on the build machine.

## Guidelines

- Instantiate the player once, at app level: `AppAudioPlayerBlueFire()` (or the
  ready made `appAudioPlayerBlueFire` singleton) typed as `AppAudioPlayer`, so
  the rest of the app never imports this package nor `audioplayers`.
  `player.name` is `'BlueFire'`, handy in a debug/about screen.
- Only the composition root imports
  `package:playlr_audio_player_blue_fire/player.dart`; every control goes
  through the `AppAudioPlayer` API: `playBytes`, `playSong`, `loadBytes`,
  `loadSong`, `play`, `pause`, `resume`, `stop`, `seek`, `setVolume`,
  `setPlaybackRate`, `getDuration`, `getCurrentPosition`, `stateStream`,
  `positionStream`, `stateValue`.
- Prefer `playBytes(bytes)` when the app already has the content;
  `playSong(AppAudioPlayerSong)` requires the global cache
  (`initCacheDatabase`, see the `playlr-audio-player-cache` skill) and throws a
  `StateError` otherwise.
- Do not reach for `audioplayers` types (`AudioPlayer`, `BytesSource`,
  `PlayerState`) in the app: the implementation owns them and disposes them.
  Each `playBytes`/`loadBytes` creates a new underlying `AudioPlayer`; the
  facade keeps a pool of 2 and disposes the older ones.
- `playBytes` returns before the native player has the source. To seek or
  read the song before it plays, `await song.loaded` on the `SongAudioPlayer`
  that `loadBytes`/`playBytes` returns: it completes once audioplayers
  prepared the bytes and throws (a `PlatformException`) when the native
  player refuses them (an unsupported format).
- **Linux**: the bytes are written to a temporary `.mp3` file in the system
  temp directory (6 rotating names, the same for every app using this
  package, never deleted) and played with `setSourceDeviceFile`; everywhere
  else a `BytesSource` is used directly (audioplayers itself goes through a
  temp file on iOS and macOS). So on Linux expect a file on disk, two apps
  playing at once can overwrite each other's file, and do not assume a non
  mp3 container plays.
- **Duration**: on Linux it is not available immediately; the implementation
  polls `getDuration()` every second until it is non zero, so
  `AppAudioPlayerState.duration` (and `state.isReady`) can stay null/false for
  a moment after the play started. Build the UI on the state stream instead of
  reading the duration once.
- **Web**: the first playback must follow a user gesture (browser autoplay
  policy). Start from a tap handler, not from `initState`; a blocked play shows
  up as a state that never turns `playing`.
- Backend choice: `playlr_audio_player_just_audio` exposes the same
  `AppAudioPlayer`. Pick one at startup and keep a single instance; do not run
  both (two native players fighting for the audio session).
- Debugging: `debugBlueFireAudioPlayer = true` (exported by `player.dart`)
  prints the player creation, and `debugPlayerDumpWriteLn = print` (from
  `playlr_audio_player`) traces every state, duration and position event of
  the facade.
- Widget tests: there is no native player under `flutter test`: `playBytes`
  returns, then every player call fails with a `MissingPluginException`
  (uncaught: the test fails; `loaded` throws it). Test the
  playlist/controller logic against the `AppAudioPlayer` abstraction (a fake)
  and keep the real player in the composition root.

## Examples

### Composition root

```dart
// lib/app_context.dart
import 'package:playlr_audio_player/player.dart';
import 'package:playlr_audio_player_blue_fire/player.dart';

class AppContext {
  /// The one player of the app, seen as the abstraction everywhere else.
  final AppAudioPlayer audioPlayer = AppAudioPlayerBlueFire();
}

late AppContext appContext;

void initAppContext() {
  appContext = AppContext();
  // appContext.audioPlayer.name is 'BlueFire' (debug/about screen).
}
```

### Playing content the app already has

```dart
import 'dart:typed_data';

import 'package:playlr_audio_player/player.dart';

/// Plays [bytes] (a whole audio file) and returns once playback started.
Future<void> playContent(AppAudioPlayer player, Uint8List bytes) async {
  var song = await player.playBytes(bytes);
  await song.setVolume(0.8);
}
```

### Starting a song at a position

```dart
import 'dart:async';
import 'dart:typed_data';

import 'package:playlr_audio_player/player.dart';

/// Loads [bytes], seeks to [position] once the source is ready, then plays.
Future<void> playFrom(
  AppAudioPlayer player,
  Uint8List bytes,
  Duration position,
) async {
  var song = player.loadBytes(bytes);
  // Throws when the native player refuses the bytes.
  await song.loaded;
  await song.seek(position);
  // Not awaited: on just_audio play() completes when the song ends.
  unawaited(song.play());
}
```

### Playing a source through the global cache

```dart
import 'package:flutter/widgets.dart';
import 'package:playlr_audio_player/cache.dart';
import 'package:playlr_audio_player/player.dart';
import 'package:playlr_audio_player_blue_fire/player.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Needed by playSong/loadSong only.
  await initCacheDatabase(packageName: 'com.example.myapp');

  AppAudioPlayer player = AppAudioPlayerBlueFire();
  // A url, downloaded once and cached, or an asset of the bundle.
  await player.playSong(AppAudioPlayerSong('https://example.com/song.mp3'));
  await player.playSong(AppAudioPlayerSong.asset('assets/audio/beep.mp3'));
}
```

### A play/pause button on the state stream

`package:material_ui/material_ui.dart` (`material_ui: ">=1.5.0"` in the app
dependencies) rather than `package:flutter/material.dart`, deprecated on the
Flutter beta channel.

```dart
import 'package:material_ui/material_ui.dart';
import 'package:playlr_audio_player/player.dart';

/// Play/pause and progress, driven by the player state.
class PlayerBar extends StatelessWidget {
  final AppAudioPlayer player;

  const PlayerBar({super.key, required this.player});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppAudioPlayerState>(
      stream: player.stateStream,
      initialData: player.stateValue,
      builder: (context, snapshot) {
        var state = snapshot.data!;
        var duration = state.duration;
        return Row(
          children: [
            IconButton(
              icon: Icon(state.playing ? Icons.pause : Icons.play_arrow),
              // A tap: fine with the web autoplay policy.
              onPressed: () =>
                  state.playing ? player.pause() : player.resume(),
            ),
            if (duration != null)
              Expanded(
                child: LinearProgressIndicator(
                  value: duration.inMilliseconds == 0
                      ? 0
                      : state.position.inMilliseconds /
                            duration.inMilliseconds,
                ),
              ),
          ],
        );
      },
    );
  }
}
```

### Reacting to the end of a song

```dart
import 'dart:async';

import 'package:playlr_audio_player/player.dart';

/// Calls [onCompleted] when a song ends on its own.
StreamSubscription<AppAudioPlayerState> onSongCompleted(
  AppAudioPlayer player,
  void Function() onCompleted,
) {
  return player.stateStream.listen((state) {
    if (state.stateEnum == AppAudioPlayerStateEnum.completed) {
      onCompleted();
    }
  });
}
```

### Tracing a platform problem

```dart
import 'package:playlr_audio_player/player.dart';
import 'package:playlr_audio_player_blue_fire/player.dart';

void enablePlayerTracing() {
  debugBlueFireAudioPlayer = true; // player creation
  debugPlayerDumpWriteLn = print; // state, duration and position events
}
```
