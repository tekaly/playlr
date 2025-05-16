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

/// Debug only
DumpWriteLnFunction? debugPlayerDumpWriteLn;

/// Represents an audio player song with its source.
class AppAudioPlayerSong {
  /// The source of the song (e.g., file path or URL).
  final String source;

  /// Creates an [AppAudioPlayerSong] with the given [source].
  AppAudioPlayerSong(this.source);
}

/// Enum representing the state of the audio player.
enum AppAudioPlayerStateEnum {
  /// No state.
  none,

  /// Preparing the audio player.
  preparing,

  /// Ready to play.
  ready,

  /// Playback completed.
  completed, // end of song
}

/// Represents the state of the audio player.
class AppAudioPlayerState {
  late final Stopwatch _sw;

  /// The current state of the audio player.
  final AppAudioPlayerStateEnum stateEnum;

  /// Indicates whether the audio player is playing.
  final bool playing;

  /// The duration of the audio being played.
  final Duration? duration;

  /// Indicates whether the audio player is preparing.
  bool get isPreparing => stateEnum == AppAudioPlayerStateEnum.preparing;

  /// Indicates whether the audio player is ready to resume.
  bool get isReady =>
      (stateEnum == AppAudioPlayerStateEnum.none ||
          stateEnum == AppAudioPlayerStateEnum.ready) &&
      duration != null;

  /// Indicates whether the audio player is paused and ready for loading.
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

  /// Always accurate
  Duration get position {
    if (stateEnum == AppAudioPlayerStateEnum.ready &&
        playing &&
        _position != null) {
      return _position + Duration(milliseconds: _sw.elapsedMilliseconds);
    }
    return _position ?? Duration.zero;
  }

  /// Creates an [AppAudioPlayerState] with the given parameters.
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

/// Audio player interface
abstract class AppOrSongAudioPlayer {
  /// Current position
  Future<Duration?> getCurrentPosition();

  /// Resume the player
  Future<void> resume();

  /// To call after resume
  Future<void> setPlaybackRate(double rate);

  /// Play
  Future<void> play();

  /// Get current duration
  Future<Duration?> getDuration();

  /// Seek to a position
  Future<void> seek(Duration position);

  /// Stop the player
  Future<void> stop();

  /// Pause the player
  Future<void> pause();

  /// Set volume
  Future<void> setVolume(double volume);

  /// position stream
  Stream<Duration?> get positionStream;

  /// State stream
  Stream<AppAudioPlayerState> get stateStream;

  /// Current state
  AppAudioPlayerState get stateValue;

  /// Current position
  Duration? getCurrentPositionSync();
}

/// Single song audio player
abstract class SongAudioPlayer implements AppOrSongAudioPlayer {
  /// Dispose
  void dispose();

  /// Disposed
  bool get disposed;
}

/// Mixin for song audio player
mixin SongAudioPlayerMixin implements SongAudioPlayer {
  @override
  bool disposed = false;
}

/// Extension
extension SongAudioPlayerExtension on AppOrSongAudioPlayer {
  /// Forward
  Future<void> forward(Duration duration) async {
    var position = await getCurrentPosition();
    if (position != null) {
      await seek(position + duration);
    }
  }

  /// Play helper
  Future<void> playFromTo({
    Duration? from,
    Duration? to,
    double? playbackRate,
  }) async {
    await pause();
    await stateStream.firstWhere((state) {
      //write('waiting for ready $state');
      return state.isReady;
    });
    if (from != null) {
      await seek(from);
      fadeIn().unawait();
    }
    resume().unawait();
    if (playbackRate != null) {
      setPlaybackRate(playbackRate).unawait();
    }
    var completer = Completer<void>();
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
      positionSubscription.cancel().unawait();
      stateSubscription.cancel().unawait();
    }
  }

  /// Face in
  Future<void> fadeIn({Duration? duration}) async {
    var sw = Stopwatch()..start();
    duration ??= const Duration(milliseconds: 500);
    Duration? startPlayingDuration;
    while (true) {
      var elapsed = sw.elapsed;
      if (stateValue.playing) {
        startPlayingDuration ??= elapsed;
        var position = ((elapsed.inMilliseconds -
                    startPlayingDuration.inMilliseconds) /
                duration.inMilliseconds)
            .bounded(0, 1);
        setVolume(position).unawait();
      }
      await sleep(10);
      if (elapsed > duration) {
        setVolume(1).unawait();
        break;
      }
    }
  }

  /// Fade out
  Future<void> fadeOut({Duration? duration}) async {
    var sw = Stopwatch()..start();
    duration ??= const Duration(milliseconds: 500);

    while (true) {
      var elapsed = sw.elapsed;
      var position = (elapsed.inMilliseconds / duration.inMilliseconds).bounded(
        0,
        1,
      );
      setVolume(1 - position).unawait();

      await sleep(10);
      if (elapsed > duration) {
        setVolume(0).unawait();
        break;
      }
    }
  }

  /// True if the player is playing
  bool isPlayingSync() {
    return stateValue.playing;
  }
}

/// Mixin for app audio player
mixin AppAudioPlayerMixin on AppAudioPlayer {}

/// Base class for app audio player
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

  /// State sink
  Sink<AppAudioPlayerState> get stateSink => _stateSubject.sink;

  @override
  AppAudioPlayerState get stateValue => _stateSubject.value;

  @override
  Stream<Duration?> get positionStream => _positionSubject.distinct();

  /// Position sink
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

  /// Constructor
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

/// App audio player
abstract class AppAudioPlayer implements AppOrSongAudioPlayer {
  /// The name of the audio player.
  String get name; //  => useJaAudioPlayer ? 'JustAudio' : 'BlueFire';

  /// [useJaAudioPlayer] if null means use default (i.e. default on the web)
  AppAudioPlayer({@Deprecated('Do no use') bool? useJaAudioPlayer});

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

  /// Current player
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

  /// Create a new audio player instance from bytes
  SongAudioPlayer newAudioPlayerInstanceFromBytes(Uint8List data);

  /// Start play but returns before play terminates
  Future<SongAudioPlayer> playSong(AppAudioPlayerSong song) async {
    // Stop current
    stop().unawait();
    var player = await loadSong(song);
    player.play().unawait();
    return player;
  }

  /// Load a song from the given [song] source.
  Future<SongAudioPlayer> loadSong(AppAudioPlayerSong song) async {
    var bytes = await globalCacheOrNull!.getContent(song.source);
    return _newAudioPlayer(bytes);
  }

  @override
  Future<void> resume() async {
    await _currentPlayer?.resume();
  }

  @override
  Future<void> setPlaybackRate(double rate) async {
    await _currentPlayer?.setPlaybackRate(rate);
  }

  @override
  Future<void> play() async {
    await _currentPlayer?.play();
  }

  @override
  Future<void> setVolume(double volume) async {
    await _currentPlayer?.setVolume(volume);
  }

  @override
  Duration? getCurrentPositionSync() =>
      _currentPlayer?.getCurrentPositionSync();

  /// Dump the current position
  Future<void> dumpPosition() async {
    globalCacheOrNull?.dumpLine(
      'position: ${(await getCurrentPosition())?.inMilliseconds} ms',
    );
  }

  /// Dump the current position synchronously
  void dumpPositionSync() {
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

/// Private extension
extension AppAudioPlayerPrvExtension on AppAudioPlayer {}
