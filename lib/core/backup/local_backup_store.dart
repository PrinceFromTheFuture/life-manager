import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:shopping_list/core/backup/app_backup.dart';

/// On-phone copies, in the app's own documents directory.
///
/// These are not shared off the device. They sit next to receipt photos so a
/// reinstall still loses them — that is the same rule as everything else
/// Spindle holds — but a crash or a bad edit can be rolled back without
/// leaving the phone.
class LocalBackupStore {
  LocalBackupStore({Directory? root}) : _rootOverride = root;

  final Directory? _rootOverride;

  static const String folder = 'backups';
  static const Duration interval = Duration(minutes: 5);

  Future<Directory> directory() async {
    final root = _rootOverride ?? await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(root.path, folder));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Newest first, by when the file was written.
  Future<List<File>> copies() async {
    final dir = await directory();
    final files = [
      await for (final entity in dir.list())
        if (entity is File && entity.path.endsWith('.zip')) entity,
    ];
    final stamped = <({File file, DateTime at})>[];
    for (final file in files) {
      stamped.add((file: file, at: await file.lastModified()));
    }
    stamped.sort((a, b) => b.at.compareTo(a.at));
    return [for (final row in stamped) row.file];
  }

  Future<DateTime?> lastAt() async {
    final files = await copies();
    if (files.isEmpty) return null;
    return files.first.lastModified();
  }

  /// Whether a copy should be written at [now].
  static bool isDue(DateTime? last, DateTime now) {
    if (last == null) return true;
    return now.difference(last) >= interval;
  }

  Future<File> write(BackupZip zip) async {
    final dir = await directory();
    var name = zip.fileName;
    var dest = File(p.join(dir.path, name));
    var n = 2;
    while (await dest.exists()) {
      dest = File(p.join(dir.path, '${p.basenameWithoutExtension(name)}_$n.zip'));
      n++;
    }
    await dest.writeAsBytes(zip.bytes, flush: true);
    return dest;
  }
}
