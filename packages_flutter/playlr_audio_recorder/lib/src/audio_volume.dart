// ignore_for_file: public_member_api_docs

import 'dart:math';

/// The volume of a stream of samples: a moving average of their absolute
/// values. One per level bar (each bar keeps its own window).
class AudioVolumeMeter {
  /// The moving average window.
  final window = <double>[];

  /// The current volume level.
  var currentVolume = 0.0;

  // `calculateVolume` calculates the volume of a list of audio samples.
  // It uses a moving average over a window of samples to smooth out the
  // volume changes, then applies a decay factor.
  //
  // Parameters:
  // - samples: The list of audio samples.
  // - windowSize: The number of samples to use for the moving average.
  // - sampleRate: The sample rate of the audio data (samples per second).
  // - decayPerSecond: The amount the volume should decay per second (e.g.,
  //   0.5 for 50% decay).
  double calculateVolume(
    List<double> samples,
    int windowSize,
    double sampleRate,
    double decayPerSecond,
  ) {
    // Add new samples to the window
    for (var sample in samples) {
      window.add(sample.abs());
      if (window.length > windowSize) {
        window.removeAt(0); // Remove the oldest sample if the window is full
      }
    }

    // If no samples in the window, decay the volume and return 0.0
    if (window.isEmpty) {
      currentVolume = 0;
      return 0.0;
    }

    // Calculate the average of the absolute values in the window
    var sumOfAbsoluteValues = 0.0;
    for (var sample in window) {
      sumOfAbsoluteValues += sample;
    }
    var averageOfAbsoluteValues = sumOfAbsoluteValues / window.length;

    // Smoothly adjust the current volume
    currentVolume = averageOfAbsoluteValues;

    // decay
    currentVolume *= pow((1 - decayPerSecond), 0.01 * 10); //0.01 = 10ms

    // Clip the volume to be between 0 and 1
    return min(1.0, max(0.0, currentVolume));
  }
}
