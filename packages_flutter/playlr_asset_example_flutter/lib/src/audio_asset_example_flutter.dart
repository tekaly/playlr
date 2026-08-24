import 'package:flutter/services.dart';
import 'package:playlr_asset_example/playlr_asset_example.dart';
import 'package:playlr_audio_player/player.dart';

/// Flutter helpers on an example audio asset.
extension AudioAssetExampleFlutterExtension on AudioAssetExample {
  /// The song to play in an [AppAudioPlayer].
  AppAudioPlayerSong get song => AppAudioPlayerSong.asset(assetKey);

  /// Load the raw asset content.
  Future<Uint8List> loadBytes({AssetBundle? bundle}) async {
    var byteData = await (bundle ?? rootBundle).load(assetKey);
    return byteData.buffer.asUint8List(
      byteData.offsetInBytes,
      byteData.lengthInBytes,
    );
  }
}

/// Flutter helpers on an example audio asset clip.
extension AudioAssetExampleClipFlutterExtension on AudioAssetExampleClip {
  /// The song to play in an [AppAudioPlayer], see [from] and [to] for the
  /// clip boundaries.
  AppAudioPlayerSong get song => asset.song;
}

/// All the mp3 example assets as songs, in playlist order.
List<AppAudioPlayerSong> get audioAssetExampleSongs =>
    audioAssetExamples.map((asset) => asset.song).toList();
