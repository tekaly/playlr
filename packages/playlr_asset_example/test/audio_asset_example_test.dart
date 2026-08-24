import 'dart:io';

import 'package:playlr_asset_example/playlr_asset_example.dart';
import 'package:test/test.dart';

void main() {
  group('audioAssetExample', () {
    test('assetKey', () {
      expect(
        audioAssetExample1.assetKey,
        'packages/playlr_asset_example/audio/example1_8s.mp3',
      );
    });
    test('files exist', () {
      for (var asset in [...audioAssetExamples, audioAssetExamplePopMidi]) {
        expect(File(asset.packagePath).existsSync(), isTrue, reason: '$asset');
      }
    });
    test('clips', () {
      expect(audioAssetExampleClips.length, 2);
      expect(audioAssetExampleClips[0].duration, const Duration(seconds: 2));
      expect(audioAssetExampleClips[1].duration, const Duration(seconds: 5));
      for (var clip in audioAssetExampleClips) {
        expect(clip.to, lessThanOrEqualTo(clip.asset.duration));
      }
    });
  });
}
