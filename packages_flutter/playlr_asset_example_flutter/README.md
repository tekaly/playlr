# playlr_asset_example_flutter

Flutter helpers for the [playlr_asset_example](../../packages/playlr_asset_example)
audio assets: converts an `AudioAssetExample` (or an `AudioAssetExampleClip`)
to an `AppAudioPlayerSong` playable by `playlr_audio_player`.

Not on pub.dev, add the git dependencies (with the player facade and one
implementation):

```yaml
dependencies:
  playlr_asset_example_flutter:
    git:
      url: https://github.com/tekaly/playlr.git
      path: packages_flutter/playlr_asset_example_flutter
  playlr_audio_player:
    git:
      url: https://github.com/tekaly/playlr.git
      path: packages_flutter/playlr_audio_player
  playlr_audio_player_just_audio:
    git:
      url: https://github.com/tekaly/playlr.git
      path: packages_flutter/playlr_audio_player_just_audio
```

The assets themselves live in `playlr_asset_example`, an app using them must
declare them:

```yaml
flutter:
  assets:
    - packages/playlr_asset_example/audio/short_song_5s.mp3
    - packages/playlr_asset_example/audio/example1_8s.mp3
    - packages/playlr_asset_example/audio/free_test_data_15s.mp3
    - packages/playlr_asset_example/audio/soundhelix_song_30s.mp3
    - packages/playlr_asset_example/audio/pop.mid
```

(a `packages/<name>/<dir>/` directory entry is not supported by flutter, each
asset must be listed)

## Usage

```dart
import 'package:playlr_asset_example_flutter/playlr_asset_example_flutter.dart';
import 'package:playlr_audio_player/cache.dart';
import 'package:playlr_audio_player/player.dart';

/// Plays the 8 s example, read from the bundle (no cache involved).
Future<void> playExample(AppAudioPlayer player) async {
  await player.playBytes(await audioAssetExample1.loadBytes());
}

/// Plays a clip of an example through the global cache of
/// playlr_audio_player (`playSong` throws a `StateError` without it).
Future<void> playClip(AppAudioPlayer player) async {
  await initCacheDatabase(packageName: 'com.example.player');
  var clip = audioAssetExampleClips.first;
  var song = await player.loadSong(clip.song);
  await song.playFromTo(from: clip.from, to: clip.to);
}
```

`audioAssetExampleSongs` lists the mp3 examples as songs, in playlist order;
`clip.song` is the whole song, `from`/`to` give the clip bounds. The player
itself comes from `playlr_audio_player_just_audio` or
`playlr_audio_player_blue_fire`.
