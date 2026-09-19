import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:shopping_list/core/backup/app_backup.dart';
import 'package:shopping_list/core/backup/backup_copy_store.dart';

/// Copies in the app's own documents directory.
///
/// The fallback store, not the first choice: this folder is deleted with the
/// app, so copies here do not survive an uninstall or an installer that
/// replaces rather than updates. [SharedBackupStore] is what runs on a phone;
/// this is what everything else — older Android, tests — gets.
class LocalBackupStore implements BackupCopyStore {
  LocalBackupStore({Directory? root}) : _rootOverride = root;

  final Directory? _rootOverride;

  static const String folder = 'backups';

  Future<Directory> directory() async {
    final root = _rootOverride ?? await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(root.path, folder));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  @override
  Future<List<BackupCopy>> copies() async {
    final dir = await directory();
    final files = [
      await for (final entity in dir.list())
        if (entity is File && entity.path.endsWith('.zip')) entity,
    ];
    final stamped = <BackupCopy>[];
    for (final file in files) {
      stamped.add(
        BackupCopy(
          id: file.path,
          name: p.basename(file.path),
          at: await file.lastModified(),
        ),
      );
    }
    stamped.sort((a, b) => b.at.compareTo(a.at));
    return stamped;
  }

  @override
  Future<DateTime?> lastAt() async {
    final all = await copies();
    return all.isEmpty ? null : all.first.at;
  }

  @override
  Future<void> write(BackupZip zip) async {
    final dir = await directory();
    final name = zip.fileName;
    var dest = File(p.join(dir.path, name));
    var n = 2;
    while (await dest.exists()) {
      dest = File(p.join(dir.path, '${p.basenameWithoutExtension(name)}_$n.zip'));
      n++;
    }
    await dest.writeAsBytes(zip.bytes, flush: true);
  }

  @override
  Future<Uint8List> read(BackupCopy copy) => File(copy.id).readAsBytes();
}
