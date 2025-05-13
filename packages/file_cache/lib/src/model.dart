import 'package:sembast/timestamp.dart';

import 'import.dart';

/// Database model representing a cached file.
/// The source is the key.
class DbFile extends DbStringRecordBase {
  /// The generated file path on start.
  final path = CvField<String>('path');

  /// Whether the file has been fetched.
  final fetched = CvField<bool>('fetched');

  /// The timestamp when the file was added or updated.
  final timestamp = CvField<Timestamp>('timestamp');

  @override
  List<CvField> get fields => [path, timestamp, fetched];
}

/// Singleton instance of the [DbFile] model.
final dbFileModel = DbFile();
