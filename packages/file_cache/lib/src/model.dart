import 'package:sembast/timestamp.dart';

import 'import.dart';

/// The source is the key
class DbFile extends DbStringRecordBase {
  /// Path is generated on start
  final path = CvField<String>('path');

  /// True when fetched
  final fetched = CvField<bool>('fetched');
  final timestamp = CvField<Timestamp>('timestamp');

  @override
  List<CvField> get fields => [path, timestamp, fetched];
}

final dbFileModel = DbFile();
