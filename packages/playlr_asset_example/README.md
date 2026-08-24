# playlr_asset_example

Example (audio) assets shared by the playlr example apps.

```yaml
  playlr_asset_example:
    git:
      url: https://github.com/tekaly/playlr.git
      path: packages/playlr_asset_example
```

The assets live in `lib/audio` so they are referenced using the
`packages/playlr_asset_example/audio/<file>` flutter asset key.

A flutter app using them must declare them in its `pubspec.yaml`:

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

See `playlr_asset_example_flutter` for the flutter helpers (asset and clip to
`AppAudioPlayerSong` conversion).
