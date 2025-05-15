import 'dart:io' as io;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
// ignore: implementation_imports
import 'package:playlr_audio_player/src/import.dart';
// ignore: implementation_imports
import 'package:playlr_audio_player/src/player/player.dart';

/// Index for temporary files on Linux.
var linuxIndex = 0;

/// Enables or disables debug output for BlueFire audio player.
var debugBlueFireAudioPlayer = false; // devWarning(true);

/// Implementation of [SongAudioPlayerImpl] using the BlueFire audioplayers package.
class BlueFireAudioPlayerImpl extends SongAudioPlayerImpl
    with SongAudioPlayerMixin {
  /// The underlying audioplayers [AudioPlayer] instance.
  late final AudioPlayer audioPlayer;

  /// Whether to use IO (Linux) specific implementation.
  bool get useIo => !kIsWeb && io.Platform.isLinux;

  /// Future that completes when the IO source is ready.
  late final Future _ioSourceReady;

  /// Saved duration of the audio.
  Duration? _duration;

  /// Whether the initial duration has been read.
  var _initialDurationRead = false;

  /// Whether the player has been stopped.
  var _stopped = false;

  /// Whether the player is active (not stopped or completed).
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

  /// Updates the duration in the player state.
  void _updateDuration() {
    stateSink.add(
      AppAudioPlayerState(
        stateEnum: stateValue.stateEnum,
        playing: stateValue.playing,
        duration: _duration,
        position: getCurrentPositionSync(),
      ),
    );
  }

  /// Triggers the duration getter to update the duration.
  void triggerDurationGetter() {
    if (!_initialDurationRead) {
      _initialDurationRead = true;
      () async {
        // Perform until it succeeds every seconds
        // on linux we don't seem to get the info until too late
        while (_active) {
          // We don't seem to get the duration right
          _duration = await audioPlayer.getDuration();
          if (debugPlayerDumpWriteLn != null) {
            debugPlayerDumpWriteLn!('$this triggerDurationGetter $_duration');
          }
          if ((_duration ?? Duration.zero) != Duration.zero) {
            _updateDuration();

            break;
          }
          await sleep(1000);
        }
      }();
    }
  }

  /// Creates a [BlueFireAudioPlayerImpl] from a byte buffer.
  BlueFireAudioPlayerImpl.fromBytes(Uint8List bytes) {
    if (debugBlueFireAudioPlayer) {
      // ignore: avoid_print
      print('$this BlueFireAudioPlayerImpl.fromBytes(${bytes.length})');
    }
    audioPlayer = AudioPlayer();
    audioPlayer.onPlayerStateChanged.listen((e) {
      if (debugPlayerDumpWriteLn != null) {
        debugPlayerDumpWriteLn!(
          '$this onPlayerStateChanged $e${disposed ? ' [disposed]' : ''}',
        );
      }
      if (disposed) {
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

      stateSink.add(
        AppAudioPlayerState(
          stateEnum: stateEnum,
          playing: playing,
          duration: _duration,
          position: getCurrentPositionSync(),
        ),
      );

      triggerDurationGetter();
    });

    audioPlayer.onDurationChanged.listen((duration) {
      if (debugPlayerDumpWriteLn != null) {
        debugPlayerDumpWriteLn!(
          '$this onDurationChanged $duration${disposed ? ' [disposed]' : ''}',
        );
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
      if (disposed) {
        return;
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

  /// Resumes playback.
  @override
  Future<void> resume() async {
    _stopped = false;
    if (useIo) {
      await _ioSourceReady;
    }
    await audioPlayer.resume();
  }

  /// Sets the playback rate.
  @override
  Future<void> setPlaybackRate(double rate) async {
    if (debugPlayerDumpWriteLn != null) {
      debugPlayerDumpWriteLn!('$this setPlaybackRate $rate');
    }
    await audioPlayer.setPlaybackRate(rate);
  }

  /// Starts playback.
  @override
  Future<void> play() async {
    _stopped = false;
    if (useIo) {
      await _ioSourceReady;
    }
    await audioPlayer.resume();
  }

  /// Disposes the player and releases resources.
  @override
  void dispose() {
    _stopped = true;
    audioPlayer.dispose();
    super.dispose();
  }

  /// Gets the current playback position.
  @override
  Future<Duration?> getCurrentPosition() {
    return audioPlayer.getCurrentPosition();
  }

  /// Pauses playback.
  @override
  Future<void> pause() => audioPlayer.pause();

  /// Stops playback.
  @override
  Future<void> stop() => audioPlayer.stop();

  /// Seeks to the specified [position].
  @override
  Future<void> seek(Duration position) => audioPlayer.seek(position);

  /// Gets the duration of the audio.
  @override
  Future<Duration?> getDuration() => audioPlayer.getDuration();

  @override
  String toString() => 'BlueFire${super.toString()}';

  /// Sets the playback volume.
  @override
  Future<void> setVolume(double volume) async {
    await audioPlayer.setVolume(volume);
  }
}
