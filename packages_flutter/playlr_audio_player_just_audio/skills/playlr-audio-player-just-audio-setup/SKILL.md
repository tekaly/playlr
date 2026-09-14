---
name: playlr-audio-player-just-audio-setup
description: 'Set up the just_audio implementation of the playlr audio player (playlr_audio_player_just_audio - AppAudioPlayerJustAudio, appAudioPlayerJustAudio) in a Flutter app on web, Android, iOS, macOS, Linux (just_audio_mpv) and Windows (just_audio_windows) - dependencies, platform packages and system libraries, creating the player, wiring it to an app controller, debugging. Use when adding audio playback with playlr to an app, choosing between the just_audio and blue_fire implementations, or when playback fails on one platform.'
metadata:
  author: tekartik
  package: playlr_audio_player_just_audio
---

# playlr_audio_player_just_audio: setup

`AppAudioPlayerJustAudio` is the `AppAudioPlayer` (see the
`playlr-audio-player-playback` skill) implemented with `package:just_audio`.
The content always reaches just_audio as **bytes** (a `StreamAudioSource`
built from a `Uint8List`), never as a url: the same code path plays a download,
a cached file, an asset or a url on every platform, and the browser's own
media cache or CORS rules never get in the way.

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
  # Desktop backends, added by the app (federated plugins, registered
  # automatically once they are in the app pubspec).
  just_audio_mpv: ">=0.1.7" # Linux
  just_audio_windows: ">=0.2.3" # Windows
```

Linux needs the system packages just_audio_mpv relies on:

```bash
sudo apt-get install mpv
sudo apt-get install clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev
sudo apt-get install libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev
sudo apt-get install gstreamer1.0-plugins-good gstreamer1.0-plugins-bad
```

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
  (`initCacheDatabase`, see the `playlr-audio-player-cache` skill).
- On the web the first playback must follow a user gesture (browser autoplay
  policy): start playing from a tap handler, not from `initState`. A blocked
  autoplay shows up as a `preparing`/`ready` state that never turns `playing`.
- Linux and Windows only work when the app itself lists `just_audio_mpv` /
  `just_audio_windows` in its pubspec (the plugin registrant is generated for
  the app, not for this package). A Linux app that plays nothing usually
  lacks `mpv`.
- The alternative backend `playlr_audio_player_blue_fire` (audioplayers)
  exposes the same `AppAudioPlayer`; choose at startup and keep one instance.
- Debugging: `debugJustAudioPlayer = true` (exported by `player.dart`) traces
  the just_audio playback events; `debugPlayerDumpWriteLn = print` (from
  `playlr_audio_player`) traces the facade's state events.
- Widget tests: the just_audio platform channels never answer under
  `flutter test`, so any awaited `playBytes`/`playSong` hangs. Test the
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
import 'package:playlr_audio_player_just_audio/player.dart';

void enablePlayerTracing() {
  debugJustAudioPlayer = true; // just_audio events
  debugPlayerDumpWriteLn = print; // facade state events
}
```
