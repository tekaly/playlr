import 'package:flutter/material.dart';
import 'package:playlr_audio_recorder/streamer.dart';
import 'package:playlr_audio_recorder/volume_widget.dart';
import 'package:playlr_simple_player_app/src/import.dart';
// ignore: depend_on_referenced_packages
import 'package:record/record.dart';
import 'package:tekartik_app_navigator_flutter/content_navigator.dart';
import 'package:tekartik_test_menu_flutter/test_menu_flutter.dart';

/// Displays the menu for audio recording and streaming features.
void menuRecorder() {
  item('audio streamer', () async {
    final record = AudioStreamer();
    var subscription = record.streamPcm16bits().listen((value) {
      // Do something with the stream
      write('Stream length: ${value.length}');
    });
    await sleep(5000);
    subscription.cancel().unawait();
  });
  item('waveform', () async {
    await ContentNavigator.pushBuilder<void>(
      buildContext!,
      builder: (_) => const WaveformScreen(),
    );
  });
  item('raw_recorder', () async {
    final record = AudioRecorder();

    // Check and request permission if needed
    if (await record.hasPermission()) {
      // Start recording to file
      /*
      await record.start(
        const RecordConfig(encoder: AudioEncoder.pcm16bits),
        path: 'aFullPath/myFile.m4a',
      );*/
      // ... or to stream
      final stream = await record.startStream(
        const RecordConfig(encoder: AudioEncoder.pcm16bits),
      );
      var count = 0;
      stream.listen((value) {
        // Do something with the stream
        write('${++count}: Stream length: ${value.length}');
      });

      await sleep(5000);
      write('Stopping recording...');
      // Stop recording...
      final path = await record.stop();
      write('Recording stopped. File path: $path');
      // ... or cancel it (and implicitly remove file/blob).
      await record.cancel();
    }
    record.dispose().unawait(); // As always
  });
}

/// A screen widget that displays a waveform visualization.
class WaveformScreen extends StatefulWidget {
  /// Creates a [WaveformScreen] widget.
  const WaveformScreen({super.key});

  @override
  State<WaveformScreen> createState() => _WaveformScreenState();
}

class _WaveformScreenState extends State<WaveformScreen> {
  var record = AudioStreamer();
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Waveform')),
      body: Center(
        child: Column(
          children: [
            const Text('Waveform'),
            WaveformProgressBar(
              audioData: record.streamPcm16bits().map((event) {
                // Convert the Int16List to a List<double>
                return event.map((e) => e.toDouble()).toList();
              }),
              barCount: 4,
              backgroundColor: Colors.grey,
              waveColor: Colors.white,
              width: 100,
              maxHeight: 200,
            ),
          ],
        ),
      ),
    );

    //body: const WaveformWidget(),
  }
}
