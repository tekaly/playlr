import 'package:flutter/services.dart';
import 'package:tekartik_app_flutter_fs/fs.dart' as app;
// ignore: depend_on_referenced_packages
import 'package:tekartik_common_utils/byte_data_utils.dart';
import 'package:tekartik_file_cache/file_cache.dart';

import 'import.dart';

/// Flutter-specific implementation of [FileCacheDatabase] that supports asset loading.
class FileCacheDatabaseFlutter extends FileCacheDatabase {
  /// Creates a [FileCacheDatabaseFlutter] instance.
  FileCacheDatabaseFlutter({
    FileSystem? fs,
    required super.databaseFactory,
    required super.options,
    super.path,
    super.httpClientFactory,
  }) : super(fs: fs ?? app.fs);

  // Handling assets

  /// Fetches the content of a file or asset from the given [source].
  @override
  Future<Uint8List> fetch(String source) async {
    var assetKey = parseAssetOrNull(source);
    if (assetKey != null) {
      return await wrap(
        () async {
          var path = assetKey;
          return byteDataToUint8List(await rootBundle.load(path));
        },
        prefix: 'asset',
        details: source,
      );
    }
    return super.fetch(source);
  }
}
