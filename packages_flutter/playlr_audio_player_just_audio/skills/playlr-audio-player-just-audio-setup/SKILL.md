---
name: playlr-audio-player-just-audio-setup
description: 'Set up the just_audio implementation of the playlr audio player (playlr_audio_player_just_audio - AppAudioPlayerJustAudio, appAudioPlayerJustAudio) in a Flutter app on web, Android, iOS, macOS, Linux (just_audio_mpv, mpv) and Windows (just_audio_windows) - dependencies, platform packages and system programs, creating the player, playing bytes or streaming an url (playUri/loadUri), waiting for loaded, wiring it to an app controller, debugging. Use when adding audio playback with playlr to an app, choosing between the just_audio and blue_fire implementations, or when playback fails on one platform.'
metadata:
  author: tekartik
  package: playlr_audio_player_just_audio
---

# playlr_audio_player_just_audio: setup

`AppAudioPlayerJustAudio` is the `AppAudioPlayer` (see the
`playlr-audio-player-playback` skill) implemented with `package:just_audio`.
Two ways in: **bytes** (`playBytes`, `playSong` through the global cache: a
`StreamAudioSource` built from a `Uint8List`, served to the native player by
just_audio's local proxy), the same code path for a download, a cached file
or an asset; or an **url streamed** by the native player (`playUri`/`loadUri`,
http `Range` requests when the server supports them, nothing downloaded
first).

## Contents
- [Dependencies](#dependencies)
- [Guidelines](#guidelines)
- [Examples](#examples)

## Dependencies

```yaml
dependencies:
  playlr_audio_player:
    git:
      url: https://github.com/tekaly/playlr.git
      path: packages_flutter/playlr_audio_player
  playlr_audio_player_just_audio:
    git:
      url: https://github.com/tekaly/playlr.git
      path: packages_flutter/playlr_audio_player_just_audio
```

The desktop backends `just_audio_mpv` (Linux) and `just_audio_windows`
(Windows) are dependencies of this package: flutter registers a federated
implementation found anywhere in the dependencies (checked on Linux: the
generated registrant calls `JustAudioMpv.registerWith()` with no app
dependency). Listing them in the app pubspec only pins their version.

Linux plays through the `mpv` program (it must be in the `PATH` of the
machine that plays); building needs the usual Flutter Linux packages:

```bash
sudo apt-get install mpv
sudo apt-get install clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev
```

(The GStreamer packages are for the blue_fire backend, `audioplayers_linux`.)

## Guidelines

- Instantiate the player once, at app level: `AppAudioPlayerJustAudio()` or the
  `appAudioPlayerJustAudio` singleton, typed as `AppAudioPlayer` so the rest of
  the app never imports just_audio. Only the composition root (app context,
  `main`) imports `package:playlr_audio_player_just_audio/player.dart`.
- Keep `just_audio` out of the app code: every control goes through the
  `AppAudioPlayer` API (`playBytes`, `playSong`, `pause`, `resume`, `seek`,
  `setPlaybackRate`, `setVolume`, `stateStream`, `positionStream`).
- Feed content as bytes with `playBytes(bytes)` when the app has them; use
  `playSong(AppAudioPlayerSong)` only with the global cache initialized
  (`initCacheDatabase`, see the `playlr-audio-player-cache` skill); stream a
  long or remote file with `playUri(uri)` (no cache, the web plays it like
  an audio element).
- `playBytes`/`playUri` return once playback started. To seek before
  playing, `loadBytes(bytes)` then `await song.loaded` (it throws a
  `PlayerException` when the source cannot be loaded); `loadUri` already
  waits for it.
- just_audio's `play()` (so `SongAudioPlayer.play()`, `AppAudioPlayer.play()`
  and `resume()`) completes when the song is paused, stopped or done, not
  when it starts: never `await` it before doing something else.
- The bytes are served to the native player with an `audio/mp3` content
  type: other formats may not play on iOS and macOS.
- On the web the first playback must follow a user gesture (browser autoplay
  policy): start playing from a tap handler, not from `initState`. A blocked
  autoplay shows up as a `preparing`/`ready` state that never turns `playing`.
- A Linux app that plays nothing usually lacks the `mpv` program.
- The alternative backend `playlr_audio_player_blue_fire` (audioplayers)
  exposes the same `AppAudioPlayer`; choose at startup and keep one instance.
- Debugging: `debugPlayerDumpWriteLn = print` (from `playlr_audio_player`)
  traces the just_audio playback and state events and the facade's state
  events; `debugJustAudioPlayer` (exported by `player.dart`) is not read.
- Widget tests: there is no native player under `flutter test`: `playBytes`
  returns, then every player call fails with a `MissingPluginException`
  (uncaught: the test fails; `loaded` throws it). Test the
  playlist/controller logic without the player and keep the player calls
  behind an interface or a thin layer.

## Examples

### Composition root

```dart
// app_context.dart
import 'package:playlr_audio_player/player.dart';
import 'package:playlr_audio_player_just_audio/player.dart';

class AppContext {
  /// The one player of the app, seen as the abstraction everywhere else.
  final AppAudioPlayer audioPlayer = AppAudioPlayerJustAudio();
}

late AppContext appContext;
```

```dart
// main.dart
import 'package:flutter/widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  appContext = AppContext();
  // Only when playSong(AppAudioPlayerSong) is used somewhere:
  // await initCacheDatabase(packageName: 'com.example.myapp');
  runApp(const MyApp());
}
```

### A controller on top of the player

```dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:playlr_audio_player/player.dart';

class PlayerController {
  final AppAudioPlayer player;
  final playing = ValueNotifier<bool>(false);
  late final StreamSubscription<AppAudioPlayerState> _subscription;

  PlayerController(this.player) {
    _subscription = player.stateStream.listen((state) {
      playing.value = state.playing;
      if (state.stateEnum == AppAudioPlayerStateEnum.completed) {
        onCompleted();
      }
    });
  }

  /// Called when the song ended on its own: play the next one.
  void onCompleted() {}

  Future<void> play(Uint8List bytes) => player.playBytes(bytes);
  Future<void> togglePlayPause() =>
      playing.value ? player.pause() : player.resume();

  Future<void> dispose() async {
    await _subscription.cancel();
    await player.stop();
  }
}
```

### Play/pause button

```dart
ValueListenableBuilder<bool>(
  valueListenable: controller.playing,
  builder: (context, playing, _) => IconButton(
    icon: Icon(playing ? Icons.pause : Icons.play_arrow),
    // A tap: fine with the web autoplay policy.
    onPressed: controller.togglePlayPause,
  ),
)
```

### Tracing a platform problem

```dart
import 'package:playlr_audio_player/player.dart';

void enablePlayerTracing() {
  // just_audio playback and state events, facade state events.
  debugPlayerDumpWriteLn = print;
}
```
