import 'dart:async';

import 'package:flutter/material.dart';
import 'package:playlr_asset_example_flutter/playlr_asset_example_flutter.dart';
import 'package:playlr_player_example_app/src/player/app_audio_player.dart';
import 'package:playlr_player_example_app/src/player/clip_queue_player.dart';
import 'package:playlr_player_example_app/src/screen/duration_text.dart';

/// Plays a queue of clips: 2s in the middle of a song then 5s in the middle
/// of another one.
class ClipQueueScreen extends StatefulWidget {
  /// Clip queue screen.
  const ClipQueueScreen({super.key});

  @override
  State<ClipQueueScreen> createState() => _ClipQueueScreenState();
}

class _ClipQueueScreenState extends State<ClipQueueScreen> {
  late final ClipQueuePlayerController player;

  @override
  void initState() {
    super.initState();
    player = ClipQueuePlayerController(
      audioPlayer: appAudioPlayer,
      clips: audioAssetExampleClips,
    );
    unawaited(player.play());
  }

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Clip queue')),
      body: ValueListenableBuilder(
        valueListenable: player.state,
        builder: (context, state, _) {
          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  itemCount: player.clips.length,
                  itemBuilder: (context, index) {
                    var clip = player.clips[index];
                    var current = index == state.index;
                    return ListTile(
                      selected: current,
                      leading: Icon(
                        current
                            ? (state.loading
                                  ? Icons.hourglass_top
                                  : Icons.volume_up)
                            : Icons.music_note,
                      ),
                      title: Text(clip.asset.name),
                      subtitle: Text(
                        '${clip.duration.inSeconds}s'
                        ' from ${formatDuration(clip.from)}'
                        ' to ${formatDuration(clip.to)}',
                      ),
                      trailing: current
                          ? StreamBuilder<Duration?>(
                              stream: player.positionStream,
                              builder: (context, snapshot) => Text(
                                formatDuration(snapshot.data ?? Duration.zero),
                              ),
                            )
                          : null,
                    );
                  },
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Text(state.done ? 'Done' : 'Playing...'),
                    FilledButton.icon(
                      onPressed: state.done
                          ? () => unawaited(player.play())
                          : null,
                      icon: const Icon(Icons.replay),
                      label: const Text('Play again'),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
