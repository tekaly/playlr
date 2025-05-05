import 'package:flutter/foundation.dart';

// ignore: depend_on_referenced_packages
import 'package:playlr_audio_player/cache.dart';

// ignore: depend_on_referenced_packages
import 'package:rxdart/rxdart.dart';

// ignore: depend_on_referenced_packages
import 'package:tekartik_common_utils/list_utils.dart' show listLast;
// ignore: depend_on_referenced_packages
import 'package:tekartik_common_utils/num_utils.dart';
import '../import.dart';

var _positionRefreshDelay = 100;

// Debug only
DumpWriteLnFunction? debugPlayerDumpWriteLn;

class AppAudioPlayerSong {
  final String source;

  AppAudioPlayerSong(this.source);
}

enum AppAudioPlayerStateEnum {
  none,
  preparing,
  ready,
  completed, // end of song
}

class AppAudioPlayerState {
  late final Stopwatch _sw;
  final AppAudioPlayerStateEnum stateEnum;
  final bool playing;
  final Duration? duration;

  bool get isPreparing => stateEnum == AppAudioPlayerStateEnum.preparing;

  bool get isReady =>
      (stateEnum == AppAudioPlayerStateEnum.none ||
          stateEnum == AppAudioPlayerStateEnum.ready) &&
      duration != null;

  /// Is paused and ready for loading
  bool get isPausedAndReadyForLoading => !isPreparing && !playing;

  @override
  int get hashCode => stateEnum.hashCode + playing.hashCode;

  @override
  bool operator ==(Object other) {
    if (other is AppAudioPlayerState) {
      if (stateEnum != other.stateEnum) {
        return false;
      }
      if (playing != other.playing) {
        return false;
      }
      if (duration != other.duration) {
        return false;
      }
      // Want at lease 10ms change
      if ((position - other.position).inMilliseconds.abs() > 10) {
        return false;
      }
      return true;
    }
    return false;
  }

  late final Duration? _position;

  // Always accurate
  Duration get position {
    if (stateEnum == AppAudioPlayerStateEnum.ready &&
        playing &&
        _position != null) {
      return _position + Duration(milliseconds: _sw.elapsedMilliseconds);
    }
    return _position ?? Duration.zero;
  }

  AppAudioPlayerState({
    required this.stateEnum,
    required this.playing,
    required this.duration,
    Duration? position,
  }) {
    _sw = Stopwatch()..start();
    _position = position;
  }

  @override
  String toString() =>
      '[player_state] ${stateEnum.name} $playing $position / $duration';
}

abstract class AppOrSongAudioPlayer {
  /// Current position
  Future<Duration?> getCurrentPosition();
  Future<void> resume();
  Future<void> play();
  Future<Duration?> getDuration();
  Future<void> seek(Duration position);
  Future<void> stop();
  Future<void> pause();
  Future<void> setVolume(double volume);

  // Implemented
  Stream<Duration?> get positionStream;
  Stream<AppAudioPlayerState> get stateStream;
  AppAudioPlayerState get stateValue;
  Duration? getCurrentPositionSync();
}

/// Single song audio player
abstract class SongAudioPlayer implements AppOrSongAudioPlayer {
  void dispose();
  bool get disposed;
}

mixin SongAudioPlayerMixin implements SongAudioPlayer {
  @override
  bool disposed = false;
}

extension SongAudioPlayerExtension on AppOrSongAudioPlayer {
  Future<void> forward(Duration duration) async {
    var position = await getCurrentPosition();
    if (position != null) {
      await seek(position + duration);
    }
  }

  Future<void> playFromTo({Duration? from, Duration? to}) async {
    await pause();
    await stateStream.firstWhere((state) {
      //write('waiting for ready $state');
      return state.isReady;
    });
    if (from != null) {
      await seek(from);
      fadeIn();
    }
    resume();
    var completer = Completer();
    late StreamSubscription stateSubscription;
    late StreamSubscription positionSubscription;
    void end() {
      stateSubscription.cancel();
      positionSubscription.cancel();
    }

    stateSubscription = stateStream.listen((state) {
      if (state.stateEnum == AppAudioPlayerStateEnum.completed) {
        end();
        completer.safeComplete();
      }
    });

    positionSubscription = positionStream.listen((position) async {
      if (to != null) {
        if (position != null && position >= to) {
          end();
          await fadeOut();
          await pause();
          completer.safeComplete();
        }
      }
    });
    try {
      await completer.future;
    } finally {
      positionSubscription.cancel();
      stateSubscription.cancel();
    }
  }

  Future<void> fadeIn({Duration? duration}) async {
    var sw = Stopwatch()..start();
    duration ??= Duration(milliseconds: 500);
    Duration? startPlayingDuration;
    while (true) {
      var elapsed = sw.elapsed;
      if (stateValue.playing) {
        startPlayingDuration ??= elapsed;
        var position = ((elapsed.inMilliseconds -
                    startPlayingDuration.inMilliseconds) /
                duration.inMilliseconds)
            .bounded(0, 1);
        setVolume(position);
      }
      await sleep(10);
      if (elapsed > duration) {
        setVolume(1);
        break;
      }
    }
  }

  Future<void> fadeOut({Duration? duration}) async {
    var sw = Stopwatch()..start();
    duration ??= Duration(milliseconds: 500);

    while (true) {
      var elapsed = sw.elapsed;
      var position = (elapsed.inMilliseconds / duration.inMilliseconds).bounded(
        0,
        1,
      );
      setVolume(1 - position);

      await sleep(10);
      if (elapsed > duration) {
        setVolume(0);
        break;
      }
    }
  }

  bool isPlayingSync() {
    return stateValue.playing;
  }
}

mixin AppAudioPlayerMixin on AppAudioPlayer {}

abstract class SongAudioPlayerImpl implements SongAudioPlayer {
  // To define
  set disposed(bool disposed);

  static var _globalId = 0;
  late final _id = ++_globalId;
  final _stateSubject = BehaviorSubject<AppAudioPlayerState>.seeded(
    AppAudioPlayerState(
      stateEnum: AppAudioPlayerStateEnum.none,
      playing: false,
      duration: null,
    ),
  );
  final _positionSubject = BehaviorSubject<Duration?>.seeded(null);

  // Use JustAudio on the web

  @override
  Stream<AppAudioPlayerState> get stateStream => _stateSubject.distinct();

  Sink<AppAudioPlayerState> get stateSink => _stateSubject.sink;

  @override
  AppAudioPlayerState get stateValue => _stateSubject.value;

  @override
  Stream<Duration?> get positionStream => _positionSubject.distinct();

  Sink<Duration?> get positionSink => _positionSubject.sink;

  @mustCallSuper
  @override
  void dispose() {
    disposed = true;
    _stateSubject.close();
    _positionSubject.close();
  }

  // Might be estimated

  Duration? _lastPosition;
  Stopwatch? _lastPositionStopwatch;

  @override
  Duration? getCurrentPositionSync() {
    var lastPosition = _lastPosition;
    if (lastPosition == null) {
      return null;
    }
    if (isPlayingSync()) {
      return lastPosition + _lastPositionStopwatch!.elapsed;
    } else {
      return lastPosition;
    }
  }

  SongAudioPlayerImpl() {
    () async {
      await for (var position in positionStream) {
        _lastPosition = position;
        _lastPositionStopwatch = Stopwatch()..start();
      }
    }();
  }

  @override
  String toString() => 'Player($_id)';
}

abstract class AppAudioPlayer implements AppOrSongAudioPlayer {
  late final bool _useJaAudioPlayer;

  String get name => useJaAudioPlayer ? 'JustAudio' : 'BlueFire';

  /// [useJaAudioPlayer] if null means use default (i.e. default on the web)
  AppAudioPlayer({bool? useJaAudioPlayer}) {
    _useJaAudioPlayer = useJaAudioPlayer ?? kIsWeb;
  }

  final _poolLength = 2;
  final _players = <SongAudioPlayerImpl>[];
  final _stateSubject = BehaviorSubject<AppAudioPlayerState>.seeded(
    AppAudioPlayerState(
      stateEnum: AppAudioPlayerStateEnum.none,
      playing: false,
      duration: null,
    ),
  );
  final _positionSubject = BehaviorSubject<Duration?>.seeded(null);

  SongAudioPlayer? get currentPlayer => _currentPlayer;

  SongAudioPlayer? get _currentPlayer => listLast(_players);

  // Use JustAudio on the web

  /// Convenient state, on changed
  @override
  Stream<AppAudioPlayerState> get stateStream => _stateSubject.distinct();

  @override
  AppAudioPlayerState get stateValue => _stateSubject.value;

  @override
  Stream<Duration?> get positionStream => _positionSubject.distinct();

  bool get useJaAudioPlayer => _useJaAudioPlayer;

  StreamSubscription? _stateSubscription;
  StreamSubscription? _positionSubscription;

  /*
  Future<void> startPlay(String url) async {
    await audioPlayer?.dispose();
    audioPlayer = AudioPlayer();
    await audioPlayer!.setSource(UrlSource(url));
    audioPlayer!.resume().unawait();
  }*/
  SongAudioPlayerImpl _newAudioPlayer(Uint8List data) {
    var impl = newAudioPlayerInstanceFromBytes(data) as SongAudioPlayerImpl;
    _players.add(impl);
    _stateSubscription?.cancel();
    _positionSubscription?.cancel();

    Timer? nextPositionTimer;
    void triggerNextPosition(Duration position) {
      nextPositionTimer?.cancel();
      if (_stateSubject.valueOrNull?.playing ?? false) {
        var elapsed = position.inMilliseconds % _positionRefreshDelay;
        var next = _positionRefreshDelay - elapsed;

        if (next < _positionRefreshDelay / 20) {
          next += _positionRefreshDelay;
        }
        nextPositionTimer = Timer(Duration(milliseconds: next), () {
          var newPosition = _currentPlayer?.getCurrentPositionSync();
          if (debugPlayerDumpWriteLn != null) {
            // debugPlayerDumpWriteLn!('timer $newPosition');
          }
          if (newPosition != null) {
            if (_currentPlayer == impl) {
              _positionSubject.add(newPosition);
              triggerNextPosition(newPosition);
            }
          }
        });
      }
    }

    _stateSubscription = impl.stateStream.listen((event) {
      // identical!
      if (_currentPlayer == impl) {
        if (debugPlayerDumpWriteLn != null) {
          debugPlayerDumpWriteLn!('state: $event');
        }
        _stateSubject.add(event);
      }
    });

    _positionSubscription = impl.positionStream.listen((position) {
      // identical!
      if (_currentPlayer == impl) {
        /*
        if (debugPlayerDumpWriteLn != null) {
          debugPlayerDumpWriteLn!('position: $position');
        }*/
        _positionSubject.add(position);
        if (position != null) {
          // Trigger another
          triggerNextPosition(position);
        }
      }
    });
    while (_players.length > _poolLength) {
      var oldPlayer = _players.first;
      oldPlayer.dispose();
      _players.removeAt(0);
    }
    return impl;
  }

  SongAudioPlayer newAudioPlayerInstanceFromBytes(Uint8List data);

  var linuxIndex = 0;

  // Start play but returns before play terminates
  Future<SongAudioPlayer> playSong(AppAudioPlayerSong song) async {
    // Stop current
    stop();
    var player = await loadSong(song);
    player.play();
    return player;
  }

  Future<SongAudioPlayer> loadSong(AppAudioPlayerSong song) async {
    var bytes = await globalCacheOrNull!.getContent(song.source);
    return _newAudioPlayer(bytes);
  }

  @override
  Future<void> resume() async {
    await _currentPlayer?.resume();
  }

  @override
  Future<void> play() async {
    await _currentPlayer?.play();
  }

  @override
  Future<void> setVolume(double volume) async {
    _currentPlayer?.setVolume(volume);
  }

  @override
  Duration? getCurrentPositionSync() =>
      _currentPlayer?.getCurrentPositionSync();

  Future<void> dumpPosition() async {
    globalCacheOrNull?.dumpLine(
      'position: ${(await getCurrentPosition())?.inMilliseconds} ms',
    );
  }

  Future<void> dumpPositionSync() async {
    globalCacheOrNull?.dumpLine(
      'position: ${(getCurrentPositionSync())?.inMilliseconds} ms',
    );
  }

  @override
  Future<Duration?> getCurrentPosition() async {
    return await _currentPlayer?.getCurrentPosition();
  }

  @override
  Future<Duration?> getDuration() async {
    return await _currentPlayer?.getDuration();
  }

  @override
  Future<void> seek(Duration position) async {
    return await _currentPlayer?.seek(position);
  }

  /*
  Future<void> stopWithFadeOut(int millis) {
    void fade(double to, double from, int len) {
      double vol = from;
      double diff = to - from;
      double steps = (diff / 0.01).abs();
      int stepLen = max(4, (steps > 0) ? len ~/ steps : len);
      int lastTick = DateTime.now().millisecondsSinceEpoch;

      // // Update the volume value on each interval ticks
      Timer.periodic(new Duration(milliseconds: stepLen), (Timer t) {
        var now = DateTime.now().millisecondsSinceEpoch;
        var tick = (now - lastTick) / len;
        lastTick = now;
        vol += diff * tick;

        vol = Math.max(0, vol);
        vol = Math.min(1, vol);
        vol = (vol * 100).round() / 100;

        player.setVolume(vol); // change this

        if ((to < from && vol <= to) || (to > from && vol >= to)) {
          if (t != null) {
            t.cancel();
            t = null;
          }
          player.setVolume(vol); // change this
        }
      });
    }
  }

   */

  // Typically you should not be able to play it again...
  @override
  Future<void> stop() async {
    await _currentPlayer?.stop();
  }

  @override
  Future<void> pause() async {
    await _currentPlayer?.pause();
  }

  @override
  String toString() => '$name${_currentPlayer?.toString() ?? '<no player>'}';
}

// final appAudioPlayer = AppAudioPlayer();
