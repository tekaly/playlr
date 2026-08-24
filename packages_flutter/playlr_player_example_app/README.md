# playlr_player_example_app

Simple multi-platform (web/desktop/mobile) player example app based on
`playlr_audio_player`.

## Menu

- **Playlist** — all the mp3 assets of `playlr_asset_example`, with
  previous/next/seek/shuffle/repeat, the next song starts automatically at the
  end of the current one.
- **Play one short song (5s)** — plays a single short song then goes back to
  the menu automatically.
- **Queue clips of 2 songs** — plays 2s in the middle of a song then 5s in the
  middle of another one (fade in/fade out included).

The player implementation can be changed at runtime from the ⋮ menu to compare
both implementations on the current platform.

## Which player implementation?

The audio content is always read as bytes (through `tekartik_file_cache`) and
fed to the implementation, so assets, files and urls behave the same way
everywhere.

| platform | implementation | notes |
| --- | --- | --- |
| web | `just_audio` | verified: real time position, clips, auto next |
| android/ios/macos | `just_audio` | endorsed implementations |
| windows | `just_audio` + `just_audio_windows` | `just_audio_windows` must be added by the app |
| linux | `audioplayers` (blue fire) | see below |

So `just_audio` alone is *almost* enough: it is the default everywhere except
on linux.

On linux `just_audio` needs `just_audio_mpv`, which delegates to `mpv_dart`.
That one is not reliable today:

- `mpv_dart` 0.0.1 ignores the requested ipc socket and always uses
  `/tmp/MPV_Dart.sock`, so two players (the audio player keeps a small pool)
  fight for the same socket and the second one dies with a `Broken pipe`;
- a freshly loaded track often stays in the `preparing` state forever, so it
  never plays.

`audioplayers` (gstreamer based on linux) has none of these issues and plays,
seeks and reports positions correctly, so it is the default there. Selecting
`just_audio` from the ⋮ menu on linux still works for a couple of songs (the
app then releases the previous mpv instance before loading the next song, see
`song_loader.dart`), but is not recommended.

## Two things to know when driving the player

- `resume()`/`play()` must **not** be awaited to know that playback started:
  with `just_audio` the returned future only completes at the end of the song.
- the duration (and the `ready` state) is only known once the source is
  loaded, so load, wait for the ready state, then resume — this is what
  `loadSongReady()` does.

## Run

```bash
flutter run -d chrome
flutter run -d linux
```
