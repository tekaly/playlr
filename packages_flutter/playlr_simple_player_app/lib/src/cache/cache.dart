import 'package:playlr_audio_player/cache.dart' as cache;
import 'package:playlr_simple_player_app/src/constant.dart';
import 'package:playlr_simple_player_app/src/import.dart';
export 'package:playlr_audio_player/cache.dart' show globalCacheOrNull;

Future<cache.FileCacheDatabase> initCache() async {
  return await cache.initCacheDatabase(packageName: packageName);
}
