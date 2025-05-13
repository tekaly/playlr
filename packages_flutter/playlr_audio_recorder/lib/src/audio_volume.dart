// ignore_for_file: public_member_api_docs

import 'dart:math';

List<double> window = []; // The moving average window
double currentVolume = 0.0; // The current volume level

// `calculateVolume` function calculates the volume of a list of audio samples.
// It uses a moving average over a window of samples to smooth out the volume changes.
// It also implements a decay mechanism to slowly reduce the volume when no samples are received.
//
// Parameters:
// - samples: The list of audio samples.
// - windowSize: The number of samples to use for the moving average.
// - sampleRate: The sample rate of the audio data (samples per second).
// - decayPerSecond: The amount the volume should decay per second (e.g., 0.5 for 50% decay).
double calculateVolume(
  List<double> samples,
  int windowSize,
  double sampleRate,
  double decayPerSecond,
) {
  // Static variables to persist state across calls

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
