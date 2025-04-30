import 'package:playlr_audio_recorder/streamer.dart';
import 'package:playlr_simple_player_app/src/import.dart';
// ignore: depend_on_referenced_packages
import 'package:record/record.dart';
import 'package:tekartik_test_menu_flutter/test_menu_flutter.dart';

void menuRecorder() {
  item('audio streamer', () async {
    final record = AudioStreamer();
    var subscription = record.streamPcm16bits().listen((value) {
      // Do something with the stream
      write('Stream length: ${value.length}');
    });
    await sleep(5000);
    subscription.cancel();
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
    record.dispose(); // As always
  });
}
