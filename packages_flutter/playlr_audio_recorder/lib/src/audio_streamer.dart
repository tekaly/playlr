import 'dart:typed_data';
import 'package:record/record.dart' as rec;
import 'package:tekartik_common_utils/common_utils_import.dart';

/// AudioStreamer interface for streaming audio data
abstract class AudioStreamer {
  /// Starts streaming audio data in PCM 16 bits format (mono)
  Stream<Int16List> streamPcm16bits();

  /// Constructor
  factory AudioStreamer() {
    return _AudioStreamer();
  }
}

class _AudioStreamer implements AudioStreamer {
  @override
  Stream<Int16List> streamPcm16bits() {
    StreamController<Int16List>? controller;
    rec.AudioRecorder? recorder;
    StreamSubscription? subscription;

    Future<void> close() async {
      controller?.close().unawait();
      recorder?.stop().unawait();
      recorder?.dispose().unawait();
      subscription?.cancel().unawait();

      controller = null;
      recorder = null;
      subscription = null;
    }

    controller = StreamController<Int16List>(
      onListen: () async {
        recorder = rec.AudioRecorder();
        // Check and request permission if needed
        if ((await recorder?.hasPermission()) ?? false) {
          // Start recording to file

          final stream = await recorder?.startStream(
            const rec.RecordConfig(encoder: rec.AudioEncoder.pcm16bits),
          );
          subscription = stream?.listen((uint8List) {
            // Do something with the stream
            var int16List = Int16List.view(uint8List.buffer);
            controller?.add(int16List);
          });
        } else {
          controller?.addError('Permission denied');
          close().unawait();
        }
      },

      onPause: () {
        // Handle pause
      },
      onResume: () {
        // Handle resume
      },
      onCancel: () {
        // Handle cancel
        close();
      },
    );
    return controller!.stream;
  }
}
