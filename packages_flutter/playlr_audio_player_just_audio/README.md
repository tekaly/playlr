# playlr_audio_player_just_audio

The `AppAudioPlayer` of
[playlr_audio_player](../playlr_audio_player/README.md) implemented with
[just_audio](https://pub.dev/packages/just_audio):
`AppAudioPlayerJustAudio`. It plays bytes (`playBytes`, `playSong` through
the global cache) and streams an url (`playUri`/`loadUri`, http `Range`
requests when the server supports them), on Android, iOS, macOS, web, Linux
and Windows.

## Getting started

Not on pub.dev, add the git dependencies (the facade and this
implementation):

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

```dart
import 'package:flutter/widgets.dart';
import 'package:playlr_audio_player/player.dart';
import 'package:playlr_audio_player_just_audio/player.dart';

/// One player for the whole app, seen as the abstraction everywhere else.
final AppAudioPlayer audioPlayer = AppAudioPlayerJustAudio();

void main() {
  runApp(
    Directionality(
      textDirection: TextDirection.ltr,
      child: GestureDetector(
        // A tap: fine with the browser autoplay policy. Streams the url and
        // returns once it started, not when it ends.
        onTap: () => audioPlayer.playUri(
          Uri.parse('https://example.com/audio/song.mp3'),
        ),
        child: const Center(child: Text('Play')),
      ),
    ),
  );
}
```

## Platforms

Android, iOS, macOS and the web: nothing to add. Linux and Windows use
`just_audio_mpv` and `just_audio_windows`, both dependencies of this package:
an app does not need to list them (flutter registers a federated
implementation found in the dependencies), listing them only pins their
version. On Linux the `mpv` program must be installed on the machine that
plays (`sudo apt-get install mpv`), besides the usual Flutter Linux build
packages (`clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev`).

## Pitfalls

- `playBytes`/`playUri` return once playback started. `await song.loaded`
  (the `SongAudioPlayer` of `loadBytes`/`loadUri`) waits for the source and
  throws when it cannot be loaded (`loadUri` already waits).
- just_audio's `play()` completes when the song is paused, stopped or done:
  do not `await` `play()`/`resume()` before doing something else.
- Bytes are served to the native player as `audio/mp3`: other formats may
  not play on iOS and macOS.
- Web: the first play must follow a user gesture (browser autoplay policy).
- `flutter test` has no native player: every player call fails with a
  `MissingPluginException` (uncaught, the test fails). Test the app logic
  against the `AppAudioPlayer` abstraction.

Package skill (for AI coding agents, `skills/`):
`playlr-audio-player-just-audio-setup`. Install it in an app depending on it
with:

```bash
dart run skills@ get -p playlr_audio_player_just_audio
```
