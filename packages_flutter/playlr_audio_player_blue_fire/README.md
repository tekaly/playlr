# playlr_audio_player_blue_fire

The `AppAudioPlayer` of
[playlr_audio_player](../playlr_audio_player/README.md) implemented with
[audioplayers](https://pub.dev/packages/audioplayers) (the Blue Fire
package): `AppAudioPlayerBlueFire`. The audio always reaches audioplayers as
**bytes** (a download, a cached file, an asset); it cannot stream an url
(`playUri`/`loadUri` throw an `UnsupportedError`, use
`playlr_audio_player_just_audio` for that).

## Getting started

Not on pub.dev, add the git dependencies (the facade and this
implementation):

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

```dart
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:playlr_audio_player/player.dart';
import 'package:playlr_audio_player_blue_fire/player.dart';

/// One player for the whole app, seen as the abstraction everywhere else.
final AppAudioPlayer audioPlayer = AppAudioPlayerBlueFire();

void main() {
  runApp(
    Directionality(
      textDirection: TextDirection.ltr,
      child: GestureDetector(
        // A tap: fine with the browser autoplay policy.
        onTap: () async {
          var data = await rootBundle.load('assets/beep.mp3');
          // Returns once the song starts, not when it ends.
          await audioPlayer.playBytes(
            data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
          );
        },
        child: const Center(child: Text('Play')),
      ),
    ),
  );
}
```

`playSong(AppAudioPlayerSong(url))` reads the audio through the global cache
of `playlr_audio_player` (`initCacheDatabase` first, see its README).

## Platforms

Android, iOS, macOS, web and Windows: nothing to add, audioplayers brings its
platform packages. Linux: building needs the GStreamer development packages
(`sudo apt-get install libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev`,
plus `gstreamer1.0-plugins-good gstreamer1.0-plugins-bad` to decode).

## Pitfalls

- `await player.loaded` (the `SongAudioPlayer` returned by
  `loadBytes`/`playBytes`) completes once the native player prepared the
  bytes and throws when it refuses them; `playBytes` itself returns before.
- Linux: the bytes go through a temporary `.mp3` file of the system temp
  folder (6 rotating names, shared by every app using this package) and the
  duration comes late (polled every second): build the UI on `stateStream`.
- Web: the first play must follow a user gesture (browser autoplay policy).
- `flutter test` has no native player: every player call fails with a
  `MissingPluginException` (uncaught, the test fails). Test the app logic
  against the `AppAudioPlayer` abstraction.
- Pick one backend at startup and keep one instance (two native players
  fight for the audio session).

Package skill (for AI coding agents, `skills/`):
`playlr-audio-player-blue-fire-setup`. Install it in an app depending on it
with:

```bash
dart run skills@ get -p playlr_audio_player_blue_fire
```
