import 'package:flutter/material.dart';
import 'package:playlr_asset_example_flutter/playlr_asset_example_flutter.dart';
import 'package:playlr_player_example_app/src/player/app_audio_player.dart';
import 'package:playlr_player_example_app/src/screen/clip_queue_screen.dart';
import 'package:playlr_player_example_app/src/screen/playlist_screen.dart';
import 'package:playlr_player_example_app/src/screen/short_song_screen.dart';

/// Main menu, one item per example.
class MainMenuScreen extends StatelessWidget {
  /// Main menu.
  const MainMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Playlr player example'),
        actions: [
          ValueListenableBuilder(
            valueListenable: appAudioPlayerImplementation,
            builder: (context, implementation, _) {
              return PopupMenuButton<AppAudioPlayerImplementation>(
                tooltip: 'Player implementation',
                icon: const Icon(Icons.more_vert),
                initialValue: implementation,
                onSelected: (value) =>
                    appAudioPlayerImplementation.value = value,
                itemBuilder: (context) => [
                  for (var value in AppAudioPlayerImplementation.values)
                    PopupMenuItem(value: value, child: Text(value.name)),
                ],
              );
            },
          ),
        ],
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.queue_music),
            title: const Text('Playlist'),
            subtitle: Text(
              'Play the ${audioAssetExamples.length} mp3 example assets',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) => const PlaylistScreen(),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.music_note),
            title: const Text('Play one short song (5s)'),
            subtitle: const Text('Goes back automatically when done'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) => const ShortSongScreen(),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.playlist_play),
            title: const Text('Queue clips of 2 songs'),
            subtitle: Text(
              audioAssetExampleClips
                  .map(
                    (clip) =>
                        '${clip.duration.inSeconds}s of ${clip.asset.name}',
                  )
                  .join(' then '),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) => const ClipQueueScreen(),
              ),
            ),
          ),
          const Divider(),
          ValueListenableBuilder(
            valueListenable: appAudioPlayerImplementation,
            builder: (context, implementation, _) {
              return ListTile(
                leading: const Icon(Icons.settings),
                title: const Text('Player implementation'),
                subtitle: Text(implementation.name),
              );
            },
          ),
        ],
      ),
    );
  }
}
