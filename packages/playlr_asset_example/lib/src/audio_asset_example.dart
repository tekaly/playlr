/// Package name, used to build the flutter asset key.
const playlrAssetExamplePackageName = 'playlr_asset_example';

/// An example audio asset (bundled in this package `lib/audio` folder).
class AudioAssetExample {
  /// Display name.
  final String name;

  /// File name in the package `lib/audio` folder.
  final String fileName;

  /// Approximate duration of the asset.
  final Duration duration;

  /// Creates an example audio asset.
  const AudioAssetExample({
    required this.name,
    required this.fileName,
    required this.duration,
  });

  /// Flutter asset key (`packages/playlr_asset_example/audio/<fileName>`).
  String get assetKey =>
      'packages/$playlrAssetExamplePackageName/audio/$fileName';

  /// Path relative to the package root.
  String get packagePath => 'lib/audio/$fileName';

  /// A clip of this asset.
  AudioAssetExampleClip clip({
    required Duration from,
    required Duration to,
    String? name,
  }) => AudioAssetExampleClip(asset: this, from: from, to: to, name: name);

  @override
  String toString() => '$name(${duration.inSeconds}s)';
}

/// A part of an [AudioAssetExample], typically played in a queue of clips.
class AudioAssetExampleClip {
  /// The asset to play.
  final AudioAssetExample asset;

  /// Where to start in the asset.
  final Duration from;

  /// Where to stop in the asset.
  final Duration to;

  /// Display name, defaults to the asset name and the clip range.
  final String? _name;

  /// Creates a clip of [asset], from [from] to [to].
  const AudioAssetExampleClip({
    required this.asset,
    required this.from,
    required this.to,
    String? name,
  }) : _name = name;

  /// Display name.
  String get name =>
      _name ?? '${asset.name} (${from.inSeconds}s - ${to.inSeconds}s)';

  /// Clip duration.
  Duration get duration => to - from;

  @override
  String toString() => name;
}

/// Short (5s) example song, handy to test a play then done scenario.
const audioAssetExampleShortSong5s = AudioAssetExample(
  name: 'Short song (5s)',
  fileName: 'short_song_5s.mp3',
  duration: Duration(seconds: 5),
);

/// 8s example song.
const audioAssetExample1 = AudioAssetExample(
  name: 'Example 1 (8s)',
  fileName: 'example1_8s.mp3',
  duration: Duration(milliseconds: 8496),
);

/// 15s example song.
const audioAssetExampleFreeTestData15s = AudioAssetExample(
  name: 'Free test data (15s)',
  fileName: 'free_test_data_15s.mp3',
  duration: Duration(milliseconds: 15151),
);

/// 30s example song.
const audioAssetExampleSoundHelixSong30s = AudioAssetExample(
  name: 'SoundHelix song (30s)',
  fileName: 'soundhelix_song_30s.mp3',
  duration: Duration(milliseconds: 28891),
);

/// Midi example asset (not an mp3, not part of [audioAssetExamples]).
const audioAssetExamplePopMidi = AudioAssetExample(
  name: 'Pop (midi)',
  fileName: 'pop.mid',
  duration: Duration(seconds: 9),
);

/// All the mp3 example assets, in playlist order.
const audioAssetExamples = <AudioAssetExample>[
  audioAssetExampleShortSong5s,
  audioAssetExample1,
  audioAssetExampleFreeTestData15s,
  audioAssetExampleSoundHelixSong30s,
];

/// Example queue of clips: 2s in the middle of a song then 5s in the middle
/// of another one.
final audioAssetExampleClips = <AudioAssetExampleClip>[
  audioAssetExample1.clip(
    from: const Duration(seconds: 3),
    to: const Duration(seconds: 5),
  ),
  audioAssetExampleSoundHelixSong30s.clip(
    from: const Duration(seconds: 12),
    to: const Duration(seconds: 17),
  ),
];
