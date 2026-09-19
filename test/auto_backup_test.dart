import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shopping_list/core/backup/app_backup.dart';
import 'package:shopping_list/core/backup/auto_backup.dart';
import 'package:shopping_list/core/backup/local_backup_store.dart';
import 'package:shopping_list/core/backup/shared_backup_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
    expect(AutoBackup.isDue(null, DateTime(2026, 8, 21, 6)), isTrue);
  });

  test('isDue only after five minutes', () {
    final last = DateTime(2026, 8, 21, 6);
    expect(
      AutoBackup.isDue(last, last.add(const Duration(minutes: 4, seconds: 59))),
      isFalse,
    );
    expect(
      AutoBackup.isDue(last, last.add(const Duration(minutes: 5))),
      isTrue,
    );
  });

  test('writes copies into app documents, and keeps all of them', () async {
    await store.write(zip('spindle_a.zip'));
    await store.write(zip('spindle_b.zip'));
    final copies = await store.copies();
    expect(copies, hasLength(2));
    expect(
      copies.map((c) => c.name).toSet(),
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
    await File(written.id).setLastModified(
      DateTime.now().subtract(AutoBackup.interval),
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

  group('copies outside the app', () {
    const channel = MethodChannel('spindle/android');

    /// Stands in for MediaStore: ids are uris, newest first.
    late List<({String id, String name, int at})> shared;
    late List<String> deleted;

    void mockChannel({bool available = true}) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        if (!available) {
          throw PlatformException(code: 'unsupported');
        }
        switch (call.method) {
          case 'saveSharedCopy':
            final args = call.arguments as Map<Object?, Object?>;
            final name = args['name']! as String;
            shared.insert(
              0,
              (id: 'content://downloads/$name', name: name, at: shared.length),
            );
            return 'content://downloads/$name';
          case 'listSharedCopies':
            return [
              for (final row in shared)
                {'id': row.id, 'name': row.name, 'at': row.at},
            ];
          case 'deleteSharedCopy':
            final id =
                (call.arguments as Map<Object?, Object?>)['id']! as String;
            deleted.add(id);
            shared.removeWhere((row) => row.id == id);
            return true;
          default:
            throw MissingPluginException(call.method);
        }
      });
    }

    setUp(() {
      shared = [];
      deleted = [];
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('a copy goes to shared storage, not the app folder', () async {
      mockChannel();
      final outside = SharedBackupStore(fallback: store);

      await outside.write(zip('spindle_c.zip'));

      expect(shared.map((row) => row.name), ['spindle_c.zip']);
      expect(
        (await outside.copies()).map((c) => c.id),
        ['content://downloads/spindle_c.zip'],
      );
      // The whole point: nothing was left in the directory that an uninstall
      // deletes.
      expect(await store.copies(), isEmpty);
    });

    test('only the newest copies are kept', () async {
      mockChannel();
      final outside = SharedBackupStore(fallback: store);

      for (var i = 0; i <= SharedBackupStore.keep; i++) {
        await outside.write(zip('spindle_$i.zip'));
      }

      expect(await outside.copies(), hasLength(SharedBackupStore.keep));
      expect(deleted, ['content://downloads/spindle_0.zip']);
    });

    test('falls back to the app folder where shared storage is refused',
        () async {
      mockChannel(available: false);
      final outside = SharedBackupStore(fallback: store);

      await outside.write(zip('spindle_d.zip'));

      expect(shared, isEmpty);
      expect((await store.copies()).map((c) => c.name), ['spindle_d.zip']);
      expect((await outside.copies()).map((c) => c.name), ['spindle_d.zip']);
    });

    test('a fallback copy is read from disk, not the channel', () async {
      mockChannel(available: false);
      final outside = SharedBackupStore(fallback: store);
      await outside.write(zip('spindle_e.zip'));

      final copy = (await outside.copies()).single;
      expect(await outside.read(copy), [1, 2, 3, 4]);
    });
  });
}
