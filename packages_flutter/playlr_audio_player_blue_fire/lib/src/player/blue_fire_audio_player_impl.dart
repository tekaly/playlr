import 'dart:io' as io;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
// ignore: implementation_imports
import 'package:playlr_audio_player/src/import.dart';
// ignore: implementation_imports
import 'package:playlr_audio_player/src/player/player.dart';

/// Index of the last temporary file written on Linux (the bytes are played
/// from one of 6 rotating files of the system temp folder).
var linuxIndex = 0;

/// Prints the creation of each song player when true.
var debugBlueFireAudioPlayer = false; // devWarning(true);

/// Implementation of [SongAudioPlayerImpl] using the BlueFire audioplayers package.
class BlueFireAudioPlayerImpl extends SongAudioPlayerImpl
    with SongAudioPlayerMixin {
  /// The underlying audioplayers [AudioPlayer] instance.
  late final AudioPlayer audioPlayer;

  /// Whether to use IO (Linux) specific implementation.
  bool get useIo => !kIsWeb && io.Platform.isLinux;

  /// The source loading, kept only while pending: a completed future kept in
  /// the player would call back in the zone it was created in (a widget test
  /// awaiting it in its fake async zone would wait forever).
  Future<void>? _loading;

  /// The error of the source loading, once failed.
  Object? _loadError;
  StackTrace? _loadStackTrace;

  /// Completes once the bytes are set as the source of the native player
  /// (prepared), throws when the native player refuses them.
  @override
  Future<void> get loaded {
    var loading = _loading;
    if (loading != null) {
      return loading;
    }
    var error = _loadError;
    if (error != null) {
      return Future<void>.error(error, _loadStackTrace);
    }
    return Future<void>.value();
  }

  /// Tracks the source [loading]: its error is kept for [loaded] (and play()
  /// on Linux), never an uncaught error.
  void _trackLoading(Future<void> loading) {
    _loading = loading;
    loading.then(
      (_) {
        _loading = null;
      },
      onError: (Object error, StackTrace stackTrace) {
        _loadError = error;
        _loadStackTrace = stackTrace;
        _loading = null;
      },
    );
  }

  /// Saved duration of the audio.
  Duration? _duration;

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

  /// An error of the native player (its event stream): a refused source is
  /// reported through [loaded], audioplayers logs it too.
  void _onNativeError(Object error) {
    if (debugPlayerDumpWriteLn != null) {
      debugPlayerDumpWriteLn!('$this native error $error');
    }
  }

  /// Triggers the duration getter to update the duration.
  void triggerDurationGetter() {
    pollDurationOnce(
      isActive: () => _active,
      readDuration: () async => _duration = await audioPlayer.getDuration(),
      onDuration: (_) => _updateDuration(),
    );
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
      if (disposed) {
        return;
      }
      _duration = duration;
      _updateDuration();
    }, onError: _onNativeError);

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
      _trackLoading(() async {
        // 6 rotating temp files
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
      }());
    } else {
      _trackLoading(() async {
        try {
          await audioPlayer.setSource(BytesSource(bytes));
        } catch (e) {
          if (kDebugMode) {
            print('error setting source bytes $e');
          }
          rethrow;
        }
      }());
    }
  }

  /// Resumes playback.
  @override
  Future<void> resume() async {
    _stopped = false;
    if (useIo) {
      await loaded;
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
      await loaded;
    }
    await audioPlayer.resume();
  }

  final _disposeLock = Lock();

  /// Disposes the player and releases resources.
  @override
  void dispose() {
    _stopped = true;
    _disposeLock.synchronized(() async {
      if (audioPlayer.state != PlayerState.disposed) {
        try {
          await audioPlayer.dispose();
        } catch (e) {
          if (debugPlayerDumpWriteLn != null) {
            debugPlayerDumpWriteLn!('$this dispose $e');
          }
        }
      }
    });
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
