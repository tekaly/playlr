import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
// ignore: implementation_imports
import 'package:playlr_audio_player/src/import.dart';
// ignore: implementation_imports
import 'package:playlr_audio_player/src/player/player.dart';
import 'package:playlr_audio_player_just_audio/src/player/source.dart';

/// Debug flag for JustAudio player.
var debugJustAudioPlayer = false; // devWarning(true);

/// Convert just audio state to app audio player state enum.
AppAudioPlayerStateEnum processingStateToStateEnum(
  ProcessingState processingState,
) {
  var stateEnum = AppAudioPlayerStateEnum.none;
  switch (processingState) {
    case ProcessingState.ready:
      stateEnum = AppAudioPlayerStateEnum.ready;
      break;
    case ProcessingState.idle:
      break;
    case ProcessingState.buffering:
    case ProcessingState.loading:
      stateEnum = AppAudioPlayerStateEnum.preparing;
      break;
    case ProcessingState.completed:
      stateEnum = AppAudioPlayerStateEnum.completed;
      break;
  }
  return stateEnum;
}

/// App audio player implementation using the JustAudio package.
abstract class SongAudioPlayerJustAudio implements SongAudioPlayer {}

/// Implementation of [SongAudioPlayerImpl] using the JustAudio package.
class JustAudioPlayerImpl extends SongAudioPlayerImpl
    with SongAudioPlayerMixin
    implements SongAudioPlayerJustAudio {
  /// Native instance of the JustAudio player.
  late final AudioPlayer jaAudioPlayer;

  /// Creates a new instance of [JustAudioPlayerImpl] from bytes.
  JustAudioPlayerImpl.fromBytes(Uint8List bytes) {
    if (debugPlayerDumpWriteLn != null) {
      debugPlayerDumpWriteLn!('JustAudioPlayerImpl.fromBytes(${bytes.length})');
    }

    jaAudioPlayer = AudioPlayer();
    jaAudioPlayer.playbackEventStream.listen((e) {
      if (debugPlayerDumpWriteLn != null) {
        // debugPlayerDumpWriteLn!('playbackEventStream ${e.processingState} ${e.updatePosition} / ${e.duration}');
        debugPlayerDumpWriteLn!(
          'playbackEventStream $e${disposed ? [', disposed'] : ''}',
        );
      }
      if (disposed) {
        return;
      }

      stateSink.add(
        AppAudioPlayerState(
          stateEnum: processingStateToStateEnum(e.processingState),
          playing: stateValue.playing,
          position: e.updatePosition,
          duration: e.duration,
        ),
      );
      if (e.processingState == ProcessingState.ready) {
        triggerDurationGetter();
      }
    });
    jaAudioPlayer.playerStateStream.listen((e) {
      if (debugPlayerDumpWriteLn != null) {
        // debugPlayerDumpWriteLn!('$this state ${e.processingState}, playing ${e.playing}, jaPlaying: ${jaAudioPlayer.playing}');
        debugPlayerDumpWriteLn!(
          'playerStateStream $e${disposed ? [', disposed'] : ''}',
        );
      }
      if (disposed) {
        return;
      }
      if (e.processingState == ProcessingState.completed) {
        // If completed, pause it otherwise play cannot work
        stop().unawait();
        _addCurrentState(
          stateEnum: processingStateToStateEnum(e.processingState),
          playing: false,
        );
      } else {
        _addCurrentState(
          stateEnum: processingStateToStateEnum(e.processingState),
        );
        positionSink.add(jaAudioPlayer.position);
      }
    });

    // ignore: dead_code
    if (false) {
      // devWarning(true)) {
      //if (false) {
      jaAudioPlayer.processingStateStream.listen((e) {
        if (debugPlayerDumpWriteLn != null) {
          debugPlayerDumpWriteLn!('processingStateStream $e');
        }
      });
      jaAudioPlayer.playingStream.listen((e) {
        if (debugPlayerDumpWriteLn != null) {
          debugPlayerDumpWriteLn!('playingStream $e');
        }
      });
    }
    jaAudioPlayer.setAudioSource(JustAudioBytesSource(bytes));
    jaAudioPlayer.positionStream.listen((e) {
      if (disposed) {
        return;
      }
      if (debugPlayerDumpWriteLn != null) {
        // debugPlayerDumpWriteLn!('position $e');
      }
      positionSink.add(e);
    });
  }

  void _addCurrentState({AppAudioPlayerStateEnum? stateEnum, bool? playing}) {
    playing ??= jaAudioPlayer.playing;
    var position = jaAudioPlayer.position;
    var duration = jaAudioPlayer.duration;

    var newState = AppAudioPlayerState(
      stateEnum: stateEnum ?? stateValue.stateEnum,
      playing: playing,
      position: position,
      duration: duration,
    );
    stateSink.add(newState);
    positionSink.add(position);
  }

  bool get _active => true;

  var _initialDurationRead = false;

  /// Trigger the duration getter to read the initial duration.
  void triggerDurationGetter() {
    if (!_initialDurationRead) {
      _initialDurationRead = true;
      () async {
        // Perform until it succeeds every seconds
        // on linux we don't seem to get the info until too late
        while (_active) {
          // We don't seem to get the duration right
          var duration = jaAudioPlayer.duration;
          if (debugPlayerDumpWriteLn != null) {
            debugPlayerDumpWriteLn!('$this triggerDurationGetter $duration');
          }

          if ((duration ?? Duration.zero) != Duration.zero) {
            _addCurrentState();

            break;
          }
          await sleep(1000);
        }
      }();
    }
  }

  @override
  Future<void> resume() async {
    if (debugPlayerDumpWriteLn != null) {
      debugPlayerDumpWriteLn!('jaAudioPlayer.resume()');
    }

    await jaAudioPlayer.play();
  }

  @override
  Future<void> setPlaybackRate(double rate) async {
    await jaAudioPlayer.setSpeed(rate);
  }

  @override
  void dispose() {
    super.dispose();
    jaAudioPlayer.dispose();
  }

  @override
  Future<Duration?> getCurrentPosition() async {
    // devPrint('ja position ${jaAudioPlayer.position}');
    return jaAudioPlayer.position;
  }

  @override
  Future<void> pause() => jaAudioPlayer.pause();

  @override
  Future<void> stop() async {
    await jaAudioPlayer.stop();
  }

  @override
  Future<void> setVolume(double volume) async {
    if (debugPlayerDumpWriteLn != null) {
      debugPlayerDumpWriteLn!('jaAudioPlayer.setVolume($volume)');
    }
    await jaAudioPlayer.setVolume(volume);
  }

  @override
  Future<void> seek(Duration position) async {
    // This crashes on linus if not ready
    try {
      await jaAudioPlayer.seek(position);
    } catch (e) {
      // print('error $e during seek');
    }
  }

  @override
  Future<void> play() async {
    if (debugPlayerDumpWriteLn != null) {
      debugPlayerDumpWriteLn!('jaAudioPlayer.play()');
    }

    await jaAudioPlayer.play();
  }

  @override
  Future<Duration?> getDuration() async => jaAudioPlayer.duration;

  @override
  String toString() => 'JustAudio${super.toString()}';
}
