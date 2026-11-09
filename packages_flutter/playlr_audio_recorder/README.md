# playlr_audio_recorder

The microphone as a stream of PCM 16 bits samples, and a simple level bar, on
top of the [record](https://pub.dev/packages/record) package.

* `AudioStreamer().streamPcm16bits()` (`package:playlr_audio_recorder/streamer.dart`):
  a `Stream<Int16List>`; the recorder starts on listen (permission asked
  then) and stops when the subscription is cancelled.
* `WaveformProgressBar(audioData: ...)` (`package:playlr_audio_recorder/volume_widget.dart`):
  bars whose height is the level of a `Stream<List<double>>` of samples in
  `-1..1`.

## Getting started

Not on pub.dev, a git dependency:

```yaml
dependencies:
  playlr_audio_recorder:
    git:
      url: https://github.com/tekaly/playlr.git
      path: packages_flutter/playlr_audio_recorder
```

```dart
import 'dart:async';
import 'dart:typed_data';

import 'package:playlr_audio_recorder/streamer.dart';

/// Listens to the microphone until the returned subscription is cancelled.
StreamSubscription<Int16List> listenToMicrophone() {
  return AudioStreamer().streamPcm16bits().listen(
    (samples) {
      // 44100 Hz, 2 channels interleaved (record's defaults).
      print('${samples.length} samples');
    },
    onError: (Object error) {
      // 'Permission denied' when the user refused the microphone.
      print('error: $error');
    },
  );
}
```

### Platforms

What `record` supports, with its setup:

* Android: `<uses-permission android:name="android.permission.RECORD_AUDIO" />`
  in `AndroidManifest.xml`.
* iOS, macOS: `NSMicrophoneUsageDescription` in `Info.plist`; on macOS also the
  `com.apple.security.device.audio-input` entitlement.
* Web: a secure context (https or localhost).
* Linux, Windows: see the `record` package.

## Common mistakes

* Each `streamPcm16bits()` call is a new recorder: call it once and keep the
  stream, do not call it in `build()`.
* Cancel the subscription when done, the microphone runs until then.
* Feed `WaveformProgressBar` normalized samples (`sample / 32768`): raw int16
  values keep the bar at full height.
* The permission error is a `String` stream error: pass `onError`.

Agent skill: [playlr-audio-recorder-setup](skills/playlr-audio-recorder-setup/SKILL.md).
