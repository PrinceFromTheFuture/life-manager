import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';

import 'package:shopping_list/core/db/database.dart';
import 'package:shopping_list/core/db/migrator.dart';
import 'package:shopping_list/core/storage/image_store.dart';

/// What's inside a Spindle backup zip.
class BackupManifest {
  const BackupManifest({
    required this.format,
    required this.exportedAt,
    required this.schemaVersions,
    required this.tables,
    required this.imageCount,
  });

  static const String currentFormat = 'spindle.backup.v1';

  final String format;
  final DateTime exportedAt;
  final Map<String, int> schemaVersions;
  final Map<String, int> tables;
  final int imageCount;

  Map<String, Object?> toJson() => {
        'format': format,
        'exportedAt': exportedAt.toIso8601String(),
        'schemaVersions': schemaVersions,
        'tables': tables,
        'imageCount': imageCount,
      };

  factory BackupManifest.fromJson(Map<String, Object?> json) {
    final versions = json['schemaVersions'];
    final tables = json['tables'];
    return BackupManifest(
      format: json['format'] as String? ?? '',
      exportedAt: DateTime.tryParse(json['exportedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      schemaVersions: {
        if (versions is Map)
          for (final e in versions.entries)
            e.key.toString(): (e.value as num).toInt(),
      },
      tables: {
        if (tables is Map)
          for (final e in tables.entries)
            e.key.toString(): (e.value as num).toInt(),
      },
      imageCount: (json['imageCount'] as num?)?.toInt() ?? 0,
    );
  }
}

/// A zip ready to hand to the share sheet.
class BackupZip {
  const BackupZip({
    required this.fileName,
    required this.bytes,
    required this.manifest,
  });

  final String fileName;
  final List<int> bytes;
  final BackupManifest manifest;
}

/// Full copy of everything the app holds on disk: the SQLite file and every
/// receipt photo. API keys stay in the keystore and are not in this dump.
class AppBackup {
  const AppBackup(this._database, this._images);

  final AppDatabase _database;
  final ImageStore _images;

  static const String dbEntry = 'shopping_list.db';
  static const String manifestEntry = 'manifest.json';
  static const String receiptsPrefix = 'receipts/';

  Future<BackupZip> build() async {
    final work = await Directory.systemTemp.createTemp('spindle_backup');
    try {
      final snapshot = File(p.join(work.path, dbEntry));
      await _snapshotDatabase(snapshot);

      final images = await _images.listReceipts();
      final archive = Archive();
      archive.addFile(
        ArchiveFile.bytes(dbEntry, await snapshot.readAsBytes()),
      );

      for (final image in images) {
        archive.addFile(
          ArchiveFile.bytes(
            '$receiptsPrefix${p.basename(image.path)}',
            await image.readAsBytes(),
          ),
        );
      }

      final counts = await _tableCounts(_database.db);
      final manifest = BackupManifest(
        format: BackupManifest.currentFormat,
        exportedAt: DateTime.now(),
        schemaVersions: await Migrator.versions(_database.db),
        tables: counts,
        imageCount: images.length,
      );
      archive.addFile(
        ArchiveFile.string(
          manifestEntry,
          const JsonEncoder.withIndent('  ').convert(manifest.toJson()),
        ),
      );

      final stamp = DateFormat('yyyy-MM-dd_HHmm').format(DateTime.now());
      return BackupZip(
        fileName: 'spindle_$stamp.zip',
        bytes: ZipEncoder().encodeBytes(archive),
        manifest: manifest,
      );
    } finally {
      if (await work.exists()) await work.delete(recursive: true);
    }
  }

  /// Writes a consistent copy of the open database. WAL is checkpointed first
  /// so the snapshot is one file, not a db plus a sidecar log.
  Future<void> _snapshotDatabase(File dest) async {
    if (await dest.exists()) await dest.delete();
    // sqflite routes PRAGMA through query(), not execute().
    await _database.db.rawQuery('PRAGMA wal_checkpoint(FULL)');
    final escaped = dest.path.replaceAll(r'\', '/').replaceAll("'", "''");
    await _database.db.execute("VACUUM INTO '$escaped'");
  }

  Future<Map<String, int>> _tableCounts(DatabaseExecutor db) async {
    final names = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' "
      "AND name NOT LIKE 'sqlite_%' AND name NOT LIKE 'android_%' "
      'ORDER BY name',
    );
    final counts = <String, int>{};
    for (final row in names) {
      final name = row['name']! as String;
      final count = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM $name'),
      );
      counts[name] = count ?? 0;
    }
    return counts;
  }

  Future<void> share() async {
    final zip = await build();
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, zip.fileName));
    await file.writeAsBytes(zip.bytes, flush: true);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/zip')],
        fileNameOverrides: [zip.fileName],
        title: zip.fileName,
        subject: zip.fileName,
      ),
    );
  }

  /// Reads the zip without touching the live database.
  static BackupManifest inspect(List<int> zipBytes) {
    final archive = ZipDecoder().decodeBytes(zipBytes);
    return _manifestOf(archive);
  }

  /// Replaces the live database and receipt photos with [zipBytes].
  ///
  /// [closeLive] is called after the backup has been validated and written to
  /// a staging file, and before the live file is swapped — so a bad zip never
  /// closes the open database.
  static Future<BackupManifest> restore({
    required List<int> zipBytes,
    required String liveDbPath,
    required Directory documentsRoot,
    Future<void> Function()? closeLive,
  }) async {
    final archive = ZipDecoder().decodeBytes(zipBytes);
    final manifest = _manifestOf(archive);
    if (manifest.format != BackupManifest.currentFormat) {
      throw const FormatException('That file is not a Spindle backup.');
    }

    final dbFile = _fileNamed(archive, dbEntry);
    final dbBytes = dbFile.readBytes();
    if (dbBytes == null || dbBytes.isEmpty) {
      throw const FormatException('The backup has no database in it.');
    }

    final staging = File('$liveDbPath.restore');
    await staging.writeAsBytes(dbBytes, flush: true);

    if (closeLive != null) await closeLive();

    final live = File(liveDbPath);
    if (await live.exists()) await live.delete();
    await staging.rename(live.path);

    for (final suffix in ['-wal', '-shm']) {
      final extra = File('$liveDbPath$suffix');
      if (await extra.exists()) await extra.delete();
    }

    final receiptsDir = Directory(p.join(documentsRoot.path, 'receipts'));
    if (await receiptsDir.exists()) {
      await receiptsDir.delete(recursive: true);
    }
    await receiptsDir.create(recursive: true);

    for (final entry in archive) {
      if (!entry.isFile) continue;
      if (!entry.name.startsWith(receiptsPrefix)) continue;
      final name = p.basename(entry.name);
      if (name.isEmpty || name == '.' || name == '..') continue;
      final bytes = entry.readBytes();
      if (bytes == null) continue;
      await File(p.join(receiptsDir.path, name)).writeAsBytes(bytes);
    }

    return manifest;
  }

  static BackupManifest _manifestOf(Archive archive) {
    final file = _fileNamed(archive, manifestEntry);
    final bytes = file.readBytes();
    if (bytes == null) {
      throw const FormatException('The backup has no manifest.');
    }
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map) {
      throw const FormatException('The backup manifest is unreadable.');
    }
    return BackupManifest.fromJson(Map<String, Object?>.from(decoded));
  }

  static ArchiveFile _fileNamed(Archive archive, String name) {
    for (final file in archive) {
      if (file.name == name) return file;
    }
    throw FormatException('The backup is missing $name.');
  }
}
