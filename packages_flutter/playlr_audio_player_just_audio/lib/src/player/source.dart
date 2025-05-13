import 'dart:typed_data';

import 'package:just_audio/just_audio.dart' as ja;

/// A [ja.StreamAudioSource] implementation for playing audio from a [Uint8List] buffer.
class JustAudioBytesSource extends ja.StreamAudioSource {
  /// The audio buffer to play.
  final Uint8List _buffer;

  /// Creates a [JustAudioBytesSource] with the given buffer.
  JustAudioBytesSource(this._buffer) : super(tag: 'JustAudioBytesSource');

  @override
  Future<ja.StreamAudioResponse> request([int? start, int? end]) async {
    // Returning the stream audio response with the parameters
    return ja.StreamAudioResponse(
      sourceLength: _buffer.length,
      contentLength: (start ?? 0) - (end ?? _buffer.length),
      offset: start ?? 0,
      stream: Stream.fromIterable([_buffer.sublist(start ?? 0, end)]),
      contentType: 'audio/mp3',
    );
  }
}
