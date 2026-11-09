import 'dart:typed_data';

import 'package:record/record.dart' as rec;
import 'package:tekartik_common_utils/common_utils_import.dart';

/// AudioStreamer interface for streaming audio data
abstract class AudioStreamer {
  /// The microphone as PCM 16 bits samples (`record` defaults: 44100 Hz, 2
  /// channels interleaved).
  ///
  /// Nothing starts before the first listen (permission asked then); cancel
  /// the subscription to stop and release the recorder. A refused permission
  /// is the stream error `'Permission denied'`, then the stream is done. Call
  /// it once per recording: each call is a new recorder.
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
            controller?.add(pcm16Samples(uint8List));
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

/// The pcm16 (little-endian, the platform order) samples of [bytes].
///
/// [bytes] can be a view at any offset of a bigger buffer: a platform channel
/// gives the chunk as a view into its message, after the envelope bytes.
Int16List pcm16Samples(Uint8List bytes) {
  var length = bytes.lengthInBytes ~/ 2;
  if (bytes.offsetInBytes.isEven) {
    return bytes.buffer.asInt16List(bytes.offsetInBytes, length);
  }
  // An Int16List view needs an even offset: copy.
  return Uint8List.fromList(bytes).buffer.asInt16List(0, length);
}
