import 'dart:async';

import 'package:flutter/material.dart';
import 'package:playlr_asset_example_flutter/playlr_asset_example_flutter.dart';
import 'package:playlr_player_example_app/src/player/app_audio_player.dart';
import 'package:playlr_player_example_app/src/player/song_loader.dart';
import 'package:playlr_player_example_app/src/screen/duration_text.dart';

/// The short song played by this screen.
const shortSongAsset = audioAssetExampleShortSong5s;

/// Plays one short song then goes back to the previous screen.
class ShortSongScreen extends StatefulWidget {
  /// Short song screen.
  const ShortSongScreen({super.key});

  @override
  State<ShortSongScreen> createState() => _ShortSongScreenState();
}

class _ShortSongScreenState extends State<ShortSongScreen> {
  final _audioPlayer = appAudioPlayer;
  SongAudioPlayer? _songPlayer;
  var _disposed = false;

  @override
  void initState() {
    super.initState();
    unawaited(_play());
  }

  Future<void> _play() async {
    try {
      var songPlayer = _songPlayer = await loadSongReady(
        _audioPlayer,
        shortSongAsset.song,
      );
      if (_disposed) {
        return;
      }
      setState(() {});
      // Plays the whole song, completes at the end of it.
      try {
        await songPlayer.playFromTo();
      } on StateError catch (_) {
        // The song player was disposed while playing.
      }
    } finally {
      if (!_disposed && mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_audioPlayer.stop());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var songPlayer = _songPlayer;
    return Scaffold(
      appBar: AppBar(title: const Text('Short song')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.music_note,
              size: 96,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              shortSongAsset.name,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 24),
            if (songPlayer == null)
              const CircularProgressIndicator()
            else
              StreamBuilder<Duration?>(
                stream: songPlayer.positionStream,
                builder: (context, snapshot) {
                  var position = snapshot.data ?? Duration.zero;
                  var max = shortSongAsset.duration.inMilliseconds.toDouble();
                  return Column(
                    children: [
                      SizedBox(
                        width: 240,
                        child: LinearProgressIndicator(
                          value: (position.inMilliseconds / max).clamp(0, 1),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${formatDuration(position)}'
                        ' / ${formatDuration(shortSongAsset.duration)}',
                      ),
                    ],
                  );
                },
              ),
            const SizedBox(height: 24),
            const Text('Going back automatically when done'),
          ],
        ),
      ),
    );
  }
}
