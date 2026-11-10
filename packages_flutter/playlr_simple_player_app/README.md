# playlr_simple_player_app

A test menu app (`tekartik_test_menu_flutter`) to try the playlr audio
player by hand on each platform: the `AppAudioPlayer` facade on both
implementations (`just_audio`, `audioplayers` / blue fire), the raw
`audioplayers` and `just_audio` players, the file cache and the
`playlr_audio_recorder` streamer. For a regular app built on the player, see
`playlr_player_example_app`.

## Run

The platform folders are not in git: create the ones you need once
(`--empty` keeps `lib/` and adds no template test), then run.

```bash
flutter create --empty --platforms=linux,web .
flutter run -d linux
flutter run -d chrome
```

On linux the `mpv` program (for `just_audio`) and the GStreamer packages
(for `audioplayers`) must be installed; on windows the cache needs
`sqfliteFfiInit()`, done at startup.

## Menu

- `key`: `player` (`just_audio`, the default, or any other value for blue
  fire) picks the implementation of the top level items, read at startup:
  restart after a change; `debugging` (`true`) traces the player events.
- `use JustAudio` / `use BlueFire`: the same items on one implementation
  (assets, local files, network songs, pause, resume, seek, positions).
- `audioplayers`, `just_audio`, `raw_just_audio`: the plugins without the
  facade.
- `cache`: fetch, dump and clear the file cache.
- `recorder`: the microphone streamer and a waveform screen.

The network items read public test files on third party hosts; the
"local file" items read the asset keys as paths (they play on the web,
through `assets/...`).
