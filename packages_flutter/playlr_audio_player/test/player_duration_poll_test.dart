// ignore: depend_on_referenced_packages
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playlr_audio_player/player.dart';

/// Player without a platform, only the base implementation.
class _TestPlayer extends SongAudioPlayerImpl with SongAudioPlayerMixin {
  Duration? duration;
  var durationReadCount = 0;
  var active = true;
  final durations = <Duration>[];

  void startPoll() {
    pollDurationOnce(
      isActive: () => active,
      readDuration: () {
        durationReadCount++;
        return duration;
      },
      onDuration: durations.add,
    );
  }

  @override
  Future<Duration?> getCurrentPosition() async => null;

  @override
  Future<Duration?> getDuration() async => duration;

  @override
  Future<void> pause() async {}

  @override
  Future<void> play() async {}

  @override
  Future<void> resume() async {}

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> setPlaybackRate(double rate) async {}

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> stop() async {}
}

void main() {
  group('pollDurationOnce', () {
    test('polls until a duration is known, once', () {
      fakeAsync((async) {
        var player = _TestPlayer();
        player.startPoll();
        async.elapse(const Duration(milliseconds: 2500));
        expect(player.durationReadCount, 3);
        expect(player.durations, isEmpty);

        player.duration = Duration.zero;
        async.elapse(const Duration(seconds: 1));
        expect(player.durations, isEmpty);

        player.duration = const Duration(seconds: 3);
        async.elapse(const Duration(seconds: 1));
        expect(player.durations, [const Duration(seconds: 3)]);
        var count = player.durationReadCount;
        async.elapse(const Duration(seconds: 5));
        expect(player.durationReadCount, count);

        // Only the first call polls
        player.startPoll();
        async.elapse(const Duration(seconds: 5));
        expect(player.durationReadCount, count);
        expect(player.durations, hasLength(1));
        player.dispose();
      });
    });
    test('stops once disposed', () {
      fakeAsync((async) {
        var player = _TestPlayer();
        player.startPoll();
        async.elapse(const Duration(milliseconds: 2500));
        expect(player.durationReadCount, 3);
        player.dispose();
        async.elapse(const Duration(seconds: 1));
        var count = player.durationReadCount;
        player.duration = const Duration(seconds: 3);
        async.elapse(const Duration(seconds: 5));
        expect(player.durationReadCount, count);
        expect(player.durations, isEmpty);
      });
    });
    test('stops when inactive', () {
      fakeAsync((async) {
        var player = _TestPlayer();
        player.startPoll();
        async.elapse(const Duration(milliseconds: 1500));
        expect(player.durationReadCount, 2);
        player.active = false;
        async.elapse(const Duration(seconds: 5));
        expect(player.durationReadCount, 2);
        player.dispose();
      });
    });
  });
}
