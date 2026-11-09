import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:playlr_audio_recorder/src/volume_widget.dart';
import 'package:playlr_audio_recorder/streamer.dart';
import 'package:record/record.dart';

/// A record platform giving [chunks] as the stream, as views into a bigger
/// buffer like a platform channel does.
class _FakeRecordPlatform extends RecordPlatform {
  final List<Uint8List> chunks;

  _FakeRecordPlatform(this.chunks);

  @override
  Future<void> create(String recorderId) async {}

  @override
  Future<bool> hasPermission(String recorderId, {bool request = true}) async =>
      true;

  /// Given over and over (what comes before the first listen is dropped).
  @override
  Future<Stream<Uint8List>> startStream(
    String recorderId,
    RecordConfig config,
  ) async => Stream.periodic(
    const Duration(milliseconds: 10),
    (i) => chunks[i % chunks.length],
  );

  @override
  Stream<RecordState> onStateChanged(String recorderId) => const Stream.empty();

  @override
  Future<String?> stop(String recorderId) async => null;

  @override
  Future<void> cancel(String recorderId) async {}

  @override
  Future<void> dispose(String recorderId) async {}

  @override
  Future<bool> isRecording(String recorderId) async => false;

  @override
  Future<bool> isPaused(String recorderId) async => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// [samples] as little-endian pcm16 bytes at [offset] of a bigger buffer.
Uint8List _pcm16View(List<int> samples, int offset) {
  var buffer = Uint8List(offset + samples.length * 2 + 5)
    ..fillRange(0, offset, 0xAA);
  var data = buffer.buffer.asByteData();
  for (var i = 0; i < samples.length; i++) {
    data.setInt16(offset + i * 2, samples[i], Endian.little);
  }
  return buffer.buffer.asUint8List(offset, samples.length * 2);
}

/// The stream event is delivered in a microtask after the first frame: a
/// second one shows it.
Future<void> _pumpEvent(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
}

double _volume(WidgetTester tester, Key key) {
  var paint = tester.widget<CustomPaint>(
    find.descendant(of: find.byKey(key), matching: find.byType(CustomPaint)),
  );
  return (paint.painter! as WaveformPainter).volume;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the samples of a chunk given as a view at any offset', () async {
    // Odd offset (3: envelope, type, size bytes) and even offset. Kept for
    // the whole file: the recorder is stopped after the test.
    RecordPlatform.instance = _FakeRecordPlatform([
      _pcm16View([1, -2, 300], 3),
      _pcm16View([-32768, 32767], 4),
    ]);
    var chunks = await AudioStreamer().streamPcm16bits().take(2).toList();
    // Two chunks in a row: one of each.
    expect(
      chunks,
      unorderedEquals([
        [1, -2, 300],
        [-32768, 32767],
      ]),
    );
  });

  testWidgets('each level bar has its own level', (tester) async {
    var loud = StreamController<List<double>>();
    var silent = StreamController<List<double>>();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Column(
          children: [
            WaveformProgressBar(
              key: const Key('loud'),
              audioData: loud.stream,
              maxHeight: 50,
            ),
            WaveformProgressBar(
              key: const Key('silent'),
              audioData: silent.stream,
              maxHeight: 50,
            ),
          ],
        ),
      ),
    );
    loud.add(List.filled(100, 1.0));
    await _pumpEvent(tester);
    silent.add(List.filled(10, 0.0));
    await _pumpEvent(tester);
    expect(_volume(tester, const Key('loud')), greaterThan(0.5));
    expect(_volume(tester, const Key('silent')), 0);
    await loud.close();
    await silent.close();
  });

  testWidgets('a new stream is followed', (tester) async {
    var first = StreamController<List<double>>.broadcast();
    var second = StreamController<List<double>>.broadcast();
    // The same bar given a new stream (MaterialApp would not rebuild its
    // home).
    Widget bar(Stream<List<double>> stream) => Directionality(
      textDirection: TextDirection.ltr,
      child: WaveformProgressBar(
        key: const Key('bar'),
        audioData: stream,
        maxHeight: 50,
      ),
    );
    await tester.pumpWidget(bar(first.stream));
    await tester.pumpWidget(bar(second.stream));
    second.add(List.filled(100, 1.0));
    await _pumpEvent(tester);
    expect(_volume(tester, const Key('bar')), greaterThan(0.5));
    await first.close();
    await second.close();
  });
}
