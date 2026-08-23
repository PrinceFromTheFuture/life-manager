import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shopping_list/core/backup/app_backup.dart';
import 'package:shopping_list/core/backup/auto_backup.dart';
import 'package:shopping_list/core/backup/local_backup_store.dart';

void main() {
  late Directory dir;
  late LocalBackupStore store;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('auto_backup_test');
    store = LocalBackupStore(root: dir);
  });

  tearDown(() async {
    if (dir.existsSync()) await dir.delete(recursive: true);
  });

  BackupZip zip([String name = 'spindle_2026-08-21_060000.zip']) => BackupZip(
        fileName: name,
        bytes: const [1, 2, 3, 4],
        manifest: BackupManifest(
          format: BackupManifest.currentFormat,
          exportedAt: DateTime(2026, 8, 21, 6),
          schemaVersions: const {},
          tables: const {},
          imageCount: 0,
        ),
      );

  test('isDue when there is no previous copy', () {
    expect(LocalBackupStore.isDue(null, DateTime(2026, 8, 21, 6)), isTrue);
  });

  test('isDue only after five minutes', () {
    final last = DateTime(2026, 8, 21, 6);
    expect(
      LocalBackupStore.isDue(last, last.add(const Duration(minutes: 4, seconds: 59))),
      isFalse,
    );
    expect(
      LocalBackupStore.isDue(last, last.add(const Duration(minutes: 5))),
      isTrue,
    );
  });

  test('writes copies into app documents, and keeps all of them', () async {
    await store.write(zip('spindle_a.zip'));
    await store.write(zip('spindle_b.zip'));
    final copies = await store.copies();
    expect(copies, hasLength(2));
    expect(
      copies.map((f) => p.basename(f.path)).toSet(),
      {'spindle_a.zip', 'spindle_b.zip'},
    );
    expect(
      Directory(p.join(dir.path, LocalBackupStore.folder)).existsSync(),
      isTrue,
    );
  });

  test('tick writes when none exist, then skips until five minutes pass',
      () async {
    var builds = 0;
    final backup = AutoBackup(
      store: store,
      buildZip: () async {
        builds++;
        return zip('spindle_$builds.zip');
      },
    );

    expect(await backup.tick(), isTrue);
    expect(await backup.tick(), isFalse);
    expect(builds, 1);
    expect(await store.copies(), hasLength(1));

    final written = (await store.copies()).single;
    await written.setLastModified(
      DateTime.now().subtract(LocalBackupStore.interval),
    );

    expect(await backup.tick(), isTrue);
    expect(builds, 2);
    expect(await store.copies(), hasLength(2));
  });

  test('tick does not start a second copy while one is writing', () async {
    final started = Completer<void>();
    final release = Completer<BackupZip>();
    final backup = AutoBackup(
      store: store,
      buildZip: () async {
        started.complete();
        return release.future;
      },
    );

    final first = backup.tick();
    await started.future;
    expect(await backup.tick(), isFalse);
    release.complete(zip());
    expect(await first, isTrue);
    expect(await store.copies(), hasLength(1));
  });
}
