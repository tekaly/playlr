// ignore_for_file: public_member_api_docs

import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'audio_volume.dart';

class WaveformProgressBar extends StatefulWidget {
  final Stream<List<double>> audioData;
  final Color backgroundColor;
  final Color waveColor;
  final double width;
  final int barCount;
  final double maxHeight;

  const WaveformProgressBar({
    required this.audioData,
    super.key,
    this.barCount = 4,
    this.backgroundColor = Colors.grey,
    this.waveColor = Colors.white,
    this.width = 100,
    this.maxHeight = 200,
  });

  @override
  WaveformProgressBarState createState() => WaveformProgressBarState();
}

class WaveformProgressBarState extends State<WaveformProgressBar> {
  late StreamSubscription<List<double>> _audioSubscription;
  double _currentVolume = 0.0;
  final double _sampleRate = 44100;
  final double _decay = 0.5;
  final int _windowSize = 100;

  /// This bar's own moving average.
  final _meter = AudioVolumeMeter();

  /// The volume shown, from 0 to 1.
  @visibleForTesting
  double get currentVolume => _currentVolume;

  void _listen() {
    _audioSubscription = widget.audioData.listen((audioList) {
      setState(() {
        // Calculate the volume from the audio data
        _currentVolume = _meter.calculateVolume(
          audioList,
          _windowSize,
          _sampleRate,
          _decay,
        );
      });
    });
  }

  @override
  void initState() {
    super.initState();
    _listen();
  }

  @override
  void didUpdateWidget(covariant WaveformProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.audioData != widget.audioData) {
      // A new stream (a new recording): follow it.
      unawaited(_audioSubscription.cancel());
      _listen();
    }
  }

  @override
  void dispose() {
    unawaited(_audioSubscription.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width,
      height: widget.maxHeight,
      decoration: BoxDecoration(color: widget.backgroundColor),
      child: CustomPaint(
        painter: WaveformPainter(
          waveColor: widget.waveColor,
          volume: _currentVolume,
          barCount: widget.barCount,
          maxHeight: widget.maxHeight,
        ),
      ),
    );
  }
}

class WaveformPainter extends CustomPainter {
  final Color waveColor;
  final double volume;
  final int barCount;
  final double maxHeight;

  WaveformPainter({
    required this.waveColor,
    required this.volume,
    required this.barCount,
    required this.maxHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final barWidth = size.width / barCount;
    for (var i = 0; i < barCount; i++) {
      final barHeight = volume * maxHeight;
      final barX = i * barWidth;
      final barRect = Rect.fromLTWH(
        barX,
        (maxHeight - barHeight) / 2,
        barWidth / 2,
        barHeight,
      );
      final barPaint = Paint()..color = waveColor;
      canvas.drawRect(barRect, barPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
