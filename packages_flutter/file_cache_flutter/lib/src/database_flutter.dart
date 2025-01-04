import 'package:flutter/services.dart';
import 'package:tekartik_app_flutter_fs/fs.dart' as app;
// ignore: depend_on_referenced_packages
import 'package:tekartik_common_utils/byte_data_utils.dart';
import 'package:tekartik_file_cache/file_cache.dart';

import 'import.dart';

class FileCacheDatabaseFlutter extends FileCacheDatabase {
  FileCacheDatabaseFlutter(
      {FileSystem? fs,
      required super.databaseFactory,
      required super.options,
      super.path,
      super.httpClientFactory})
      : super(fs: fs ?? app.fs);

  // Handling assets
  @override
  Future<Uint8List> fetch(String source) async {
    var assetUri = parseAssetOrNull(source);
    if (assetUri != null) {
      return await wrap(() async {
        var path = assetUri.path;
        return byteDataToUint8List(await rootBundle.load(path));
      }, prefix: 'asset', details: source);
    }
    return super.fetch(source);
  }
}

extension FileCacheDatabaseFlutterExt on FileCacheDatabase {
  Uri? parseAssetOrNull(String source) {
    if (source.startsWith('asset:')) {
      return Uri.parse(source);
    }
    return null;
  }

  String assetToSource(String asset) {
    return 'asset:$asset';
  }
}
