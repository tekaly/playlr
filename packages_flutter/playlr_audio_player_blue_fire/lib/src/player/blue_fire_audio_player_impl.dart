import 'dart:io' as io;

import 'package:flutter/foundation.dart';
import 'package:path/path.dart';

import 'package:audioplayers/audioplayers.dart';
// ignore: implementation_imports
import 'package:playlr_audio_player/src/import.dart';
// ignore: implementation_imports
import 'package:playlr_audio_player/src/player/player.dart';

var linuxIndex = 0;

var debugBlueFireAudioPlayer = false; // devWarning(true);

class BlueFireAudioPlayerImpl extends SongAudioPlayerImpl
    with SongAudioPlayerMixin {
  late final AudioPlayer audioPlayer;

  bool get useIo => !kIsWeb && io.Platform.isLinux;
  // io only for now
  late final Future _ioSourceReady;
  // saved duration.
  Duration? _duration;
  var _initialDurationRead = false;
  var _stopped = false;
  // Stopped or completed.
  bool get _active {
    switch (audioPlayer.state) {
      case PlayerState.playing:
      case PlayerState.paused:
        return true;
      // Ok for stopped as it is what happen after load
      case PlayerState.stopped:
        return !_stopped;
      default:
        return false;
    }
  }

  void _updateDuration() {
    stateSink.add(AppAudioPlayerState(
        stateEnum: stateValue.stateEnum,
        playing: stateValue.playing,
        duration: _duration,
        position: getCurrentPositionSync()));
  }

  void triggerDurationGetter() {
    if (!_initialDurationRead) {
      _initialDurationRead = true;
      () async {
        // Perform until it succeeds every seconds
        // on linux we don't seem to get the info until too late
        while (_active) {
          // We don't seem to get the duration right
          _duration = await audioPlayer.getDuration();
          // devPrint('$this getting duration $_duration');
          if ((_duration ?? Duration.zero) != Duration.zero) {
            _updateDuration();

            break;
          }
          await sleep(1000);
        }
      }();
    }
  }

  BlueFireAudioPlayerImpl.fromBytes(Uint8List bytes) {
    if (debugBlueFireAudioPlayer) {
      // ignore: avoid_print
      print('$this BlueFireAudioPlayerImpl.fromBytes(${bytes.length})');
    }
    audioPlayer = AudioPlayer();
    audioPlayer.onPlayerStateChanged.listen((e) {
      if (debugPlayerDumpWriteLn != null) {
        debugPlayerDumpWriteLn!(
            '$this onPlayerStateChanged $e${disposed ? ' [disposed]' : ''}');
      }
      if (!disposed) {
        return;
      }
      var playing = false;
      var stateEnum = AppAudioPlayerStateEnum.none;
      switch (e) {
        case PlayerState.stopped:
        case PlayerState.disposed:
          break;
        case PlayerState.playing:
          stateEnum = AppAudioPlayerStateEnum.ready;
          playing = true;
          break;
        case PlayerState.paused:
          stateEnum = AppAudioPlayerStateEnum.ready;
          break;
        case PlayerState.completed:
          stateEnum = AppAudioPlayerStateEnum.completed;
          break;
      }

      stateSink.add(AppAudioPlayerState(
          stateEnum: stateEnum,
          playing: playing,
          duration: _duration,
          position: getCurrentPositionSync()));

      triggerDurationGetter();
    });

    audioPlayer.onDurationChanged.listen((duration) {
      if (debugPlayerDumpWriteLn != null) {
        debugPlayerDumpWriteLn!(
            '$this onDurationChanged $duration${disposed ? ' [disposed]' : ''}');
      }
      if (!disposed) {
        return;
      }
      _duration = duration;
      _updateDuration();
    });

    audioPlayer.onPositionChanged.listen((e) {
      if (debugPlayerDumpWriteLn != null) {
        debugPlayerDumpWriteLn!('$this onPositionChanged $e');
      }
      positionSink.add(e);
    });
    if (useIo) {
      _ioSourceReady = () async {
        // 5 temp files
        if (linuxIndex > 5) {
          linuxIndex = 0;
        }
        var fileName = 'n80mPvPfWQWCTih6Ah2x${++linuxIndex}.mp3';
        if (debugPlayerDumpWriteLn != null) {
          debugPlayerDumpWriteLn!('file $fileName');
        }
        var file = join(io.Directory.systemTemp.path, fileName);
        await io.File(file).writeAsBytes(bytes);
        await audioPlayer.setSourceDeviceFile(file);
        triggerDurationGetter();
      }();
    } else {
      try {
        audioPlayer.setSource(BytesSource(bytes));
      } catch (e) {
        if (kDebugMode) {
          print('error setting source bytes $e');
        }
        rethrow;
      }
    }
  }

  @override
  Future<void> resume() async {
    _stopped = false;
    if (useIo) {
      await _ioSourceReady;
    }
    await audioPlayer.resume();
  }

  @override
  Future<void> play() async {
    _stopped = false;
    if (useIo) {
      await _ioSourceReady;
    }
    await audioPlayer.resume();
  }

  @override
  void dispose() {
    super.dispose();
    _stopped = true;
    audioPlayer.dispose();
  }

  @override
  Future<Duration?> getCurrentPosition() {
    return audioPlayer.getCurrentPosition();
  }

  @override
  Future<void> pause() => audioPlayer.pause();

  @override
  Future<void> stop() => audioPlayer.stop();

  @override
  Future<void> seek(Duration position) => audioPlayer.seek(position);

  @override
  Future<Duration?> getDuration() => audioPlayer.getDuration();

  @override
  String toString() => 'BlueFire${super.toString()}';
}
