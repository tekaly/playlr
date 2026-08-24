import 'package:flutter/material.dart';
import 'package:playlr_asset_example_flutter/playlr_asset_example_flutter.dart';
import 'package:playlr_player_example_app/src/player/app_audio_player.dart';
import 'package:playlr_player_example_app/src/player/playlist_player.dart';
import 'package:playlr_player_example_app/src/screen/duration_text.dart';

/// Playlist of all the mp3 example assets.
class PlaylistScreen extends StatefulWidget {
  /// Playlist screen.
  const PlaylistScreen({super.key});

  @override
  State<PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends State<PlaylistScreen> {
  late final PlaylistPlayerController player;

  @override
  void initState() {
    super.initState();
    player = PlaylistPlayerController(
      audioPlayer: appAudioPlayer,
      assets: audioAssetExamples,
    );
  }

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Playlist')),
      body: ValueListenableBuilder(
        valueListenable: player.state,
        builder: (context, state, _) {
          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  itemCount: audioAssetExamples.length,
                  itemBuilder: (context, index) {
                    var asset = audioAssetExamples[index];
                    var current = asset == state.asset;
                    return ListTile(
                      selected: current,
                      leading: Icon(
                        current && state.playing
                            ? Icons.volume_up
                            : Icons.music_note,
                      ),
                      title: Text(asset.name),
                      subtitle: Text(formatDuration(asset.duration)),
                      onTap: () => player.playAt(index),
                    );
                  },
                ),
              ),
              const Divider(height: 1),
              _PlaylistPlayerControls(player: player, state: state),
            ],
          );
        },
      ),
    );
  }
}

class _PlaylistPlayerControls extends StatelessWidget {
  final PlaylistPlayerController player;
  final PlaylistPlayerState state;

  const _PlaylistPlayerControls({required this.player, required this.state});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              state.asset?.name ?? 'No song',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          if (state.error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                state.error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
                textAlign: TextAlign.center,
              ),
            ),
          if (state.loading)
            const LinearProgressIndicator()
          else
            StreamBuilder<Duration?>(
              stream: player.positionStream,
              builder: (context, snapshot) {
                var position = snapshot.data ?? Duration.zero;
                var duration = state.asset?.duration ?? Duration.zero;
                var max = duration.inMilliseconds.toDouble();
                var value = position.inMilliseconds.toDouble().clamp(
                  0,
                  max <= 0 ? 1 : max,
                );
                return Column(
                  children: [
                    Slider(
                      value: max <= 0 ? 0 : value.toDouble(),
                      max: max <= 0 ? 1 : max,
                      onChanged: max <= 0
                          ? null
                          : (value) => player.seek(
                              Duration(milliseconds: value.round()),
                            ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(formatDuration(position)),
                          Text(formatDuration(duration)),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: 'Shuffle',
                  isSelected: state.shuffle,
                  icon: const Icon(Icons.shuffle),
                  onPressed: player.toggleShuffle,
                ),
                IconButton(
                  iconSize: 36,
                  tooltip: 'Previous',
                  icon: const Icon(Icons.skip_previous),
                  onPressed: () => player.previous(),
                ),
                FilledButton(
                  onPressed: state.loading
                      ? null
                      : () {
                          if (state.asset == null) {
                            player.playAt(0);
                          } else if (state.playing) {
                            player.pause();
                          } else {
                            player.resume();
                          }
                        },
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(
                      state.playing ? Icons.pause : Icons.play_arrow,
                      size: 32,
                    ),
                  ),
                ),
                IconButton(
                  iconSize: 36,
                  tooltip: 'Next',
                  icon: const Icon(Icons.skip_next),
                  onPressed: () => player.next(),
                ),
                IconButton(
                  tooltip: 'Repeat all',
                  isSelected: state.repeatAll,
                  icon: const Icon(Icons.repeat),
                  onPressed: player.toggleRepeatAll,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
