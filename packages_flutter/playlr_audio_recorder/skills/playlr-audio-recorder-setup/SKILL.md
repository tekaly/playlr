---
name: playlr-audio-recorder-setup
description: 'Stream microphone audio in a Flutter app with playlr_audio_recorder - AudioStreamer, streamPcm16bits() (package:playlr_audio_recorder/streamer.dart) and the WaveformProgressBar level widget (package:playlr_audio_recorder/volume_widget.dart), on top of package:record (AudioRecorder, RecordConfig, AudioEncoder.pcm16bits). Use when recording or visualizing the microphone, when handling the Permission denied stream error, when converting Int16List pcm samples to a level or to a file, or when the waveform bar stays full height.'
metadata:
  author: tekartik
  package: playlr_audio_recorder
---

# playlr_audio_recorder: setup

`playlr_audio_recorder` is a thin layer over
[record](https://pub.dev/packages/record): `AudioStreamer.streamPcm16bits()`
gives the microphone as a `Stream<Int16List>` of PCM 16 bits samples (the
recorder is created, permission checked, started and disposed with the stream
subscription), and `WaveformProgressBar` paints a simple level bar from such a
stream.

## Contents
- [Dependency and platform setup](#dependency-and-platform-setup)
- [Guidelines](#guidelines)
- [Examples](#examples)

## Dependency and platform setup

The package is not on pub.dev, depend on it with git:

```yaml
dependencies:
  playlr_audio_recorder:
    git:
      url: https://github.com/tekaly/playlr.git
      path: packages_flutter/playlr_audio_recorder
    version: '>=0.0.1'
```

Microphone access is the app's responsibility (this is what `record` needs):

```xml
<!-- android/app/src/main/AndroidManifest.xml -->
<uses-permission android:name="android.permission.RECORD_AUDIO" />
```

- iOS/macOS: `NSMicrophoneUsageDescription` in `Info.plist`, plus the
  `com.apple.security.device.audio-input` entitlement on macOS.
- Web: a secure context (https or localhost) and a user gesture before the
  first recording.
- Check the `record` package for the platforms and minimum SDK versions that
  support `AudioEncoder.pcm16bits` streaming.

## Guidelines

- `AudioStreamer()` is a factory constructor of an abstract class: create one,
  then `streamPcm16bits()`.
- Nothing happens until you **listen**: the underlying `AudioRecorder` is
  created on the first listen, permission is checked
  (`record.hasPermission()`), and `startStream(RecordConfig(encoder:
  AudioEncoder.pcm16bits))` starts the microphone. Cancelling the subscription
  stops and disposes everything; there is no `stop()` method to call.
- Call `streamPcm16bits()` **once** per recording and keep the stream in a
  field: every call builds a new controller and a new recorder, so mapping the
  same getter twice in `build()` opens two microphones.
- The stream is single subscription and never completes on its own. Cancel it
  in `dispose()`/when the screen leaves, or the microphone keeps running.
- Permission refused is reported as a **stream error whose object is the
  `String` `'Permission denied'`** (not an exception, not a typed error), and
  the stream is then closed. Always pass `onError:` to `listen` (or
  `handleError`) and show something to the user.
- Each event is an `Int16List` view over the platform buffer: signed samples in
  `-32768..32767`. Divide by `32768` for a `-1..1` double. Keep a copy
  (`Int16List.fromList(...)`, a `BytesBuilder`) if you accumulate a take; do
  not hold on to the event list itself.
- The config is fixed: `RecordConfig(encoder: AudioEncoder.pcm16bits)` with the
  `record` defaults (44100 Hz, and 2 channels in record 6.x, interleaved). Do
  not assume mono when computing a duration from the sample count; check
  `value.length` against the expected rate. Needing another sample rate,
  channel count or a file output means using `package:record`
  (`AudioRecorder`, `startStream`, `start`, `stop`) directly.
- `WaveformProgressBar({required Stream<List<double>> audioData, int barCount =
  4, Color backgroundColor = Colors.grey, Color waveColor = Colors.white,
  double width = 100, double maxHeight = 200})` draws `barCount` identical bars
  whose height is the current level; the widget is a fixed `width` x
  `maxHeight` box, wrap it in a `SizedBox`/`Center` if the layout matters.
- Feed it **normalized** doubles (`sample / 32768`): the level is a moving
  average of the absolute values clipped to `0..1`, so raw int16 values make it
  saturate at full height forever. That is the usual cause of "the bar is
  always full".
- The level computation keeps module level state (a shared moving average
  window), so show a single `WaveformProgressBar` at a time; two of them
  interfere.
- `WaveformProgressBar` calls `setState` on every audio event: that is the
  recorder rate, several times per frame. Throttle the stream if the UI janks
  and do not put other expensive widgets in the same subtree.
- It does not handle stream errors: attach `handleError` before passing the
  stream, otherwise a permission error becomes an unhandled zone error.
- Tests: the `record` platform channels do not answer under `flutter test`.
  Keep the microphone behind your own interface and pump a
  `Stream<Int16List>`/`Stream<List<double>>` of your own in widget tests.

## Examples

### Listening to the microphone

```dart
import 'dart:async';
import 'dart:typed_data';

import 'package:playlr_audio_recorder/streamer.dart';

/// Owns one microphone stream: start() opens it, stop() releases it.
class MicRecorder {
  StreamSubscription<Int16List>? _subscription;

  bool get recording => _subscription != null;

  void start(void Function(Int16List samples) onSamples) {
    _subscription?.cancel();
    // The recorder starts here (on listen) and stops on cancel.
    _subscription = AudioStreamer().streamPcm16bits().listen(
      onSamples,
      onError: (Object error) {
        // error == 'Permission denied' when the user refused the microphone.
        print('recording error: $error');
        stop();
      },
    );
  }

  Future<void> stop() async {
    var subscription = _subscription;
    _subscription = null;
    await subscription?.cancel();
  }
}
```

### A level (0..1) out of the samples

```dart
import 'dart:math';
import 'dart:typed_data';

/// Rms level of a pcm 16 bits buffer, in 0..1.
double rmsLevel(Int16List samples) {
  if (samples.isEmpty) {
    return 0;
  }
  var sum = 0.0;
  for (var sample in samples) {
    var value = sample / 32768; // normalize
    sum += value * value;
  }
  return min(1, sqrt(sum / samples.length));
}
```

### A waveform screen

```dart
import 'package:flutter/material.dart';
import 'package:playlr_audio_recorder/streamer.dart';
import 'package:playlr_audio_recorder/volume_widget.dart';

/// Shows the microphone level while the screen is on.
class WaveformScreen extends StatefulWidget {
  const WaveformScreen({super.key});

  @override
  State<WaveformScreen> createState() => _WaveformScreenState();
}

class _WaveformScreenState extends State<WaveformScreen> {
  /// Built once: calling streamPcm16bits() again would open a second recorder.
  late final Stream<List<double>> _audioData = AudioStreamer()
      .streamPcm16bits()
      // Normalized samples, or the bar saturates at full height.
      .map((samples) => samples.map((sample) => sample / 32768).toList())
      // 'Permission denied' would otherwise be an unhandled error.
      .handleError((Object error) => debugPrint('mic error: $error'));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Waveform')),
      body: Center(
        child: WaveformProgressBar(
          audioData: _audioData,
          barCount: 4,
          backgroundColor: Colors.black12,
          waveColor: Colors.blue,
          width: 100,
          maxHeight: 200,
        ),
      ),
    );
  }
}
```

### Recording a take in memory

```dart
import 'dart:typed_data';

import 'package:playlr_audio_recorder/streamer.dart';

/// Records [duration] of pcm 16 bits samples (copied out of the events).
Future<Int16List> recordSamples(Duration duration) async {
  var samples = <int>[];
  var subscription = AudioStreamer().streamPcm16bits().listen(
    samples.addAll,
    onError: (Object error) => print('recording error: $error'),
  );
  await Future<void>.delayed(duration);
  await subscription.cancel(); // stops the microphone
  return Int16List.fromList(samples);
}
```
