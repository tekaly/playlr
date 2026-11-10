import 'dart:convert';
import 'dart:typed_data';

import 'package:fs_shim/fs_memory.dart';
import 'package:path/path.dart';
import 'package:sembast/sembast_memory.dart';
// ignore: depend_on_referenced_packages
import 'package:tekartik_common_utils/env_utils.dart';
import 'package:tekartik_file_cache/src/database.dart';
// ignore: depend_on_referenced_packages
import 'package:tekartik_http/http_memory.dart';
import 'package:test/test.dart';

/// Fails every fetch while [offline] is true.
class _FileCacheDatabaseNetwork extends FileCacheDatabase {
  var offline = false;

  _FileCacheDatabaseNetwork({
    required super.fs,
    required super.databaseFactory,
    required super.options,
    super.httpClientFactory,
  });

  @override
  Future<Uint8List> fetch(String source) async {
    if (offline) {
      throw StateError('offline');
    }
    return super.fetch(source);
  }
}

/// Every fetch returns 'fetched <source>', recorded in [fetched].
class _FileCacheDatabaseEcho extends FileCacheDatabase {
  final fetched = <String>[];

  _FileCacheDatabaseEcho({required super.fs})
    : super(
        databaseFactory: newDatabaseFactoryMemory(),
        options: FileCacheDatabaseOptions(fileCountMax: 10),
      );

  @override
  Future<Uint8List> fetch(String source) async {
    fetched.add(source);
    return Uint8List.fromList(utf8.encode('fetched $source'));
  }
}

void main() {
  group('source', () {
    test('without scheme: a file on io, fetched on the web', () async {
      var fs = newFileSystemMemory();
      var db = _FileCacheDatabaseEcho(fs: fs);
      if (kDartIsWeb) {
        // A url relative to the page, also with dart2wasm.
        expect(
          utf8.decode(await db.getContent('assets/song.mp3')),
          'fetched assets/song.mp3',
        );
      } else {
        await fs.file('song.mp3').writeAsString('file content');
        expect(utf8.decode(await db.getContent('song.mp3')), 'file content');
        expect(db.fetched, isEmpty);
      }
    });

    test('lost file is fetched again', () async {
      var fs = newFileSystemMemory();
      var db = _FileCacheDatabaseEcho(fs: fs);
      var source = 'https://example.com/a.mp3';
      expect(utf8.decode(await db.getContent(source)), 'fetched $source');
      // Deleted outside the cache (or the record survived its file).
      var dbFile = await db.getDbFile(source);
      await db.fileFromPath(dbFile.path.v!).delete();
      expect(utf8.decode(await db.getContent(source)), 'fetched $source');
      expect(utf8.decode(await db.getContent(source)), 'fetched $source');
      expect(db.fetched, [source, source]);
      expect((await db.getDbFile(source)).fetched.v, isTrue);
    });
  });

  group('simple', () {
    late HttpServer server;
    late Uri serverUri;
    late _FileCacheDatabaseNetwork db;
    late Map<String, int> serverHits;
    setUp(() async {
      // Additional setup goes here.
      serverHits = <String, int>{};
      server = await httpServerFactoryMemory.bind(InternetAddress.anyIPv4, 1);
      serverUri = server.clientUri;
      server.listen((event) async {
        Future<void> send(List<int> content) async {
          event.response.add(Uint8List.fromList(content));
          await event.response.close();
        }

        var filename = url.basename(event.uri.path);
        serverHits[filename] = (serverHits[filename] ?? 0) + 1;
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
      db = _FileCacheDatabaseNetwork(
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
    test('fetched after a failed fetch', () async {
      var source1 = sourceWithName('1');
      var source2 = sourceWithName('2');
      var source3 = sourceWithName('3');
      // The first fetch of 3 fails, its record (created now) is not fetched
      db.offline = true;
      await expectLater(db.getContent(source3), throwsStateError);
      db.offline = false;
      await Future<void>.delayed(const Duration(milliseconds: 2));
      expect(await db.getContent(source1), [1, 2, 3]);
      await Future<void>.delayed(const Duration(milliseconds: 2));
      expect(await db.getContent(source2), [4, 5, 6]);
      await Future<void>.delayed(const Duration(milliseconds: 2));
      // Fetched last: kept, the oldest fetched one (1) is evicted
      expect(await db.getContent(source3), [7, 8, 9]);
      expect((await db.getDbFile(source3)).fetched.v, isTrue);
      expect((await db.getDbFile(source1)).fetched.v, isFalse);
      expect(await db.getContent(source3), [7, 8, 9]);
      expect(serverHits['3'], 1);
    });
  });
}
