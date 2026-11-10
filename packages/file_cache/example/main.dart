// ignore_for_file: avoid_print

// Offline: a memory file system, database and http server. The second
// getContent reads the cached file, the server is hit once.
import 'dart:typed_data';

import 'package:fs_shim/fs_memory.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:tekartik_app_http/app_http.dart';
import 'package:tekartik_file_cache/file_cache.dart';

Future<void> main() async {
  var hits = 0;
  var server = await httpServerFactoryMemory.bind(InternetAddress.anyIPv4, 0);
  server.listen((request) async {
    hits++;
    request.response.add(Uint8List.fromList([1, 2, 3]));
    await request.response.close();
  });
  var cache = FileCacheDatabase(
    fs: newFileSystemMemory(),
    databaseFactory: newDatabaseFactoryMemory(),
    httpClientFactory: httpClientFactoryMemory,
    options: FileCacheDatabaseOptions(fileCountMax: 10),
    path: '/cache',
  );
  var source = server.clientUri.replace(path: '/song.mp3').toString();
  print(await cache.getContent(source)); // fetched: [1, 2, 3]
  print(await cache.getContent(source)); // from the cached file
  var dbFile = await cache.getDbFile(source);
  print('fetched: ${dbFile.fetched.v}, file: ${dbFile.path.v}, hits: $hits');
  await server.close(force: true);
}
