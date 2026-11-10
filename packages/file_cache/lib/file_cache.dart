/// A cache of downloaded files: [FileCacheDatabase.getContent] fetches a
/// source once, then reads its local file (fs_shim), indexed in a sembast
/// database.
library;

export 'src/database.dart'
    show
        FileCacheDatabase,
        FileCacheDatabaseAssetExt,
        FileCacheDatabaseOptions,
        debugCacheWriteLn,
        cvFileStore,
        DumpWriteLnFunction;
export 'src/model.dart' show DbFile, dbFileModel;
