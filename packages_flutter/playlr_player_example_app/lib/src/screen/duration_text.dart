/// Formats a duration as `m:ss`, `--:--` when null.
String formatDuration(Duration? duration) {
  if (duration == null) {
    return '--:--';
  }
  var minutes = duration.inMinutes;
  var seconds = duration.inSeconds % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}
