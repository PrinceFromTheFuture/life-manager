import 'package:flutter/services.dart';

import 'package:shopping_list/core/backup/app_backup.dart';
import 'package:shopping_list/core/backup/backup_copy_store.dart';

/// Copies in shared storage — `Download/Spindle` — so they outlive the app.
///
/// The app's own folder is the wrong place for the only copy. Android deletes
/// it with the package, so an uninstall, or any install that replaces rather
/// than updates, takes the whole five-minute history with it at exactly the
/// moment it is needed. Files published through MediaStore stay behind.
///
/// A reinstalled app cannot list files the old install created — MediaStore
/// scopes non-media reads to the app that wrote them — but they are still on
/// the phone and still restorable through the document picker, which is
/// permission-free.
class SharedBackupStore implements BackupCopyStore {
  SharedBackupStore({required this.fallback, MethodChannel? channel})
      : _channel = channel ?? const MethodChannel('spindle/android');

  /// Used where shared storage is not available: Android 9 and older, and
  /// every other host including tests.
  final BackupCopyStore fallback;

  final MethodChannel _channel;

  /// How many copies to keep. Each one is the whole database plus every
  /// receipt photo, so this is a disk budget rather than a history depth.
  static const int keep = 12;

  static const String _uriScheme = 'content://';

  @override
  Future<List<BackupCopy>> copies() async {
    try {
      final rows = await _channel
          .invokeListMethod<Map<Object?, Object?>>('listSharedCopies');
      return [
        for (final row in rows ?? const <Map<Object?, Object?>>[]) _copyOf(row),
      ];
    } on PlatformException {
      return fallback.copies();
    } on MissingPluginException {
      return fallback.copies();
    }
  }

  @override
  Future<DateTime?> lastAt() async {
    final all = await copies();
    return all.isEmpty ? null : all.first.at;
  }

  @override
  Future<void> write(BackupZip zip) async {
    try {
      await _channel.invokeMethod<String>('saveSharedCopy', {
        'name': zip.fileName,
        'bytes': Uint8List.fromList(zip.bytes),
      });
    } on PlatformException {
      return fallback.write(zip);
    } on MissingPluginException {
      return fallback.write(zip);
    }
    await _prune();
  }

  @override
  Future<Uint8List> read(BackupCopy copy) async {
    if (!copy.id.startsWith(_uriScheme)) return fallback.read(copy);
    final bytes =
        await _channel.invokeMethod<Uint8List>('readSharedCopy', {'id': copy.id});
    if (bytes == null) {
      throw const FormatException('That copy could not be read.');
    }
    return bytes;
  }

  /// Drops everything past [keep], oldest first.
  Future<void> _prune() async {
    final all = await copies();
    if (all.length <= keep) return;
    for (final copy in all.skip(keep)) {
      if (!copy.id.startsWith(_uriScheme)) continue;
      try {
        await _channel.invokeMethod<bool>('deleteSharedCopy', {'id': copy.id});
      } on PlatformException {
        // A copy that will not delete is not worth failing the backup over;
        // the next prune tries again.
      }
    }
  }

  static BackupCopy _copyOf(Map<Object?, Object?> row) => BackupCopy(
        id: row['id']! as String,
        name: row['name']! as String,
        at: DateTime.fromMillisecondsSinceEpoch((row['at']! as num).toInt()),
      );
}
