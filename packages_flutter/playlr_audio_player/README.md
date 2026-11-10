# playlr_audio_player

A small, backend independent audio player facade for Flutter (web, mobile,
desktop): one `AppAudioPlayer` for the app, songs played from bytes, a url,
a file or an asset, with the state and position as streams. The decoding is
done by an implementation package:
`playlr_audio_player_just_audio` (every platform) or
`playlr_audio_player_blue_fire`.

- `package:playlr_audio_player/player.dart`: `AppAudioPlayer`,
  `AppAudioPlayerSong`, `SongAudioPlayer`, `AppAudioPlayerState`, the
  `playFromTo`/`fadeIn`/`fadeOut` helpers.
- `package:playlr_audio_player/cache.dart`: `initCacheDatabase`, the global
  file cache `playSong` reads the audio through (urls downloaded once).

## Getting started

Not on pub.dev, add the git dependencies (the facade and one
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
import 'package:playlr_audio_player/cache.dart';
import 'package:playlr_audio_player/player.dart';
import 'package:playlr_audio_player_just_audio/player.dart';

/// One player for the whole app.
final AppAudioPlayer audioPlayer = AppAudioPlayerJustAudio();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Once, before the first playSong (not needed for playBytes).
  await initCacheDatabase(packageName: 'com.example.myplayer');
  runApp(const PlayButton());
}

class PlayButton extends StatelessWidget {
  const PlayButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: GestureDetector(
        // Returns once the song starts, not when it ends.
        onTap: () => audioPlayer.playSong(
          AppAudioPlayerSong('https://example.com/audio/song.mp3'),
        ),
        child: const Center(child: Text('Play')),
      ),
    );
  }
}
```

Platforms: the ones of the implementation. just_audio plays on Android,
iOS, macOS, the web, Linux and Windows (`just_audio_mpv` and
`just_audio_windows` come with `playlr_audio_player_just_audio`, Linux needs
the `mpv` program, see its README and skill). On Windows call
`sqfliteFfiInit()` before `initCacheDatabase` (the cache index is a sqflite
database).

## The cache

`playSong`/`loadSong` read the whole audio as bytes through the global cache:
an `http(s)` url is downloaded once (up to 100 files kept), an asset
(`AppAudioPlayerSong.asset(key)`) and a file (`AppAudioPlayerSong.file(path)`)
are read directly. On io it lives in the `file_cache` folder of the
application documents directory of `packageName` (or in `rootPath`), on the
web in the browser storage; `globalCacheOrNull!.clearCache()` empties it.
An app that already keeps its audio plays it with `playBytes(bytes)`, no
cache needed.

## Pitfalls

- One `AppAudioPlayer` for the app: it keeps the last 2 song players and
  disposes the older ones.
- `playSong`/`playUri` load before playing: a second call made before the
  first song is loaded plays both songs, the first one out of reach of
  `pause()`/`stop()`. Disable the play action while a song loads.
- `flutter test` cannot play audio (no native player: the calls fail with a
  `MissingPluginException`): keep the player calls in a thin layer.

Package skills (for AI coding agents, `skills/`):
`playlr-audio-player-playback` and `playlr-audio-player-cache`. Install them
in an app depending on it with:

```bash
dart run skills@ get -p playlr_audio_player
```
