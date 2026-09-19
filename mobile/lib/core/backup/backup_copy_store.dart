import 'dart:typed_data';

import 'package:shopping_list/core/backup/app_backup.dart';

/// One kept copy, wherever it is being held.
class BackupCopy {
  const BackupCopy({required this.id, required this.name, required this.at});

  /// Handle the store that produced it understands: a file path for the
  /// app's own folder, a `content://` uri for shared storage.
  final String id;

  /// File name, `spindle_<date>_<time>.zip`.
  final String name;

  /// When it was written.
  final DateTime at;
}

/// Where [AutoBackup] keeps its copies.
///
/// Two implementations: shared storage, which outlives the app, and the app's
/// own documents folder, which does not. The interface exists so the schedule
/// does not care which one it got.
abstract interface class BackupCopyStore {
  /// Newest first.
  Future<List<BackupCopy>> copies();

  Future<DateTime?> lastAt();

  Future<void> write(BackupZip zip);

  Future<Uint8List> read(BackupCopy copy);
}
