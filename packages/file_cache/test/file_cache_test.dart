import 'dart:typed_data';

import 'package:fs_shim/fs_memory.dart';
import 'package:path/path.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:tekartik_file_cache/src/database.dart';
// ignore: depend_on_referenced_packages
import 'package:tekartik_http/http_memory.dart';
import 'package:test/test.dart';

void main() {
  group('simple', () {
    late HttpServer server;
    late Uri serverUri;
    late FileCacheDatabase db;
    setUp(() async {
      // Additional setup goes here.
      server = await httpServerFactoryMemory.bind(InternetAddress.anyIPv4, 1);
      serverUri = server.clientUri;
      server.listen((event) async {
        Future<void> send(List<int> content) async {
          event.response.add(Uint8List.fromList(content));
          await event.response.close();
        }

        var filename = url.basename(event.uri.path);
        switch (filename) {
          case '1':
            await send([1, 2, 3]);
            break;
          case '2':
            await send([4, 5, 6]);
            break;
          case '3':
            await send([7, 8, 9]);
            break;
        }
      });
      db = FileCacheDatabase(
        fs: newFileSystemMemory(),
        databaseFactory: newDatabaseFactoryMemory(),
        httpClientFactory: httpClientFactoryMemory,
        options: FileCacheDatabaseOptions(fileCountMax: 2),
      );
    });
    tearDown(() async {
      await server.close(force: true);
    });

    String sourceWithName(String name) {
      return serverUri.replace(path: url.join(serverUri.path, name)).toString();
    }

    test('fetch', () async {
      expect(await db.fetch(sourceWithName('1')), [1, 2, 3]);
    });
    test('cache', () async {
      var source = sourceWithName('1');
      expect((await db.getDbFile(source)).fetched.v, isFalse);
      expect(await db.getContent(source), [1, 2, 3]);
      expect((await db.getDbFile(source)).fetched.v, isTrue);
    });
    test('full', () async {
      var source1 = sourceWithName('1');
      var source2 = sourceWithName('2');
      var source3 = sourceWithName('3');
      expect(await db.getContent(source1), [1, 2, 3]);
      expect(await db.getContent(source2), [4, 5, 6]);
      expect((await db.getDbFile(source1)).fetched.v, isTrue);
      expect(await db.getContent(source3), [7, 8, 9]);
      expect((await db.getDbFile(source1)).fetched.v, isFalse);
    });
  });
}
