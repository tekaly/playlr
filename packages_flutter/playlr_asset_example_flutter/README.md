# playlr_asset_example_flutter

Flutter helpers for the [playlr_asset_example](../../packages/playlr_asset_example)
audio assets: converts an `AudioAssetExample` (or an `AudioAssetExampleClip`)
to an `AppAudioPlayerSong` playable by `playlr_audio_player`.

```yaml
  playlr_asset_example_flutter:
    git:
      url: https://github.com/tekaly/playlr.git
      path: packages_flutter/playlr_asset_example_flutter
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
await appAudioPlayer.playSong(audioAssetExample1.song);
```
