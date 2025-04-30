import 'dart:typed_data';

import 'package:flutter/foundation.dart';
// ignore: implementation_imports
import 'package:playlr_audio_player/src/import.dart';
// ignore: implementation_imports
import 'package:playlr_audio_player/src/player/player.dart';
import 'package:just_audio/just_audio.dart';
import 'package:playlr_audio_player_just_audio/src/player/source.dart';

var debugJustAudioPlayer = false; // devWarning(true);

AppAudioPlayerStateEnum processingStateToStateEnum(
  ProcessingState processingState,
) {
  AppAudioPlayerStateEnum stateEnum = AppAudioPlayerStateEnum.none;
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

abstract class SongAudioPlayerJustAudio implements SongAudioPlayer {}

class JustAudioPlayerImpl extends SongAudioPlayerImpl
    with SongAudioPlayerMixin
    implements SongAudioPlayerJustAudio {
  late final AudioPlayer jaAudioPlayer;
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
        stateSink.add(
          AppAudioPlayerState(
            stateEnum: processingStateToStateEnum(e.processingState),
            playing: false,
            position: jaAudioPlayer.position,
            duration: jaAudioPlayer.duration,
          ),
        );
      } else {
        stateSink.add(
          AppAudioPlayerState(
            stateEnum: processingStateToStateEnum(e.processingState),
            playing: jaAudioPlayer.playing,
            position: jaAudioPlayer.position,
            duration: jaAudioPlayer.duration,
          ),
        );
        positionSink.add(jaAudioPlayer.position);
      }
    });

    // if (devWarning(true)) {
    // ignore: dead_code
    if (false) {
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

  void _addCurrentState() {
    var position = jaAudioPlayer.position;
    stateSink.add(
      AppAudioPlayerState(
        stateEnum: stateValue.stateEnum,
        playing: stateValue.playing,
        position: position,
        duration: stateValue.duration,
      ),
    );
    positionSink.add(jaAudioPlayer.position);
  }

  bool get _active => true;

  var _initialDurationRead = false;
  void triggerDurationGetter() {
    if (!_initialDurationRead) {
      _initialDurationRead = true;
      () async {
        // Perform until it succeeds every seconds
        // on linux we don't seem to get the info until too late
        while (_active) {
          // We don't seem to get the duration right
          var duration = jaAudioPlayer.duration;
          // devPrint('$this getting duration $duration');
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
      debugPlayerDumpWriteLn!('jaAudioPlayer.play()');
    }

    await jaAudioPlayer.play();
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
  Future<void> seek(Duration position) async {
    // This crashes on linus if not ready
    try {
      await jaAudioPlayer.seek(position);
    } catch (e) {
      // print('error $e during seek');
    }
  }

  @override
  Future<void> play() => jaAudioPlayer.play();

  @override
  Future<Duration?> getDuration() async => jaAudioPlayer.duration;

  @override
  String toString() => 'JustAudio${super.toString()}';
}
