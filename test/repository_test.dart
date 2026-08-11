import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/apps/groceries/data/groceries_migrations.dart';
import 'package:shopping_list/core/db/database.dart';
import 'package:shopping_list/core/storage/image_store.dart';
import 'package:shopping_list/apps/groceries/data/models/trip.dart';
import 'package:shopping_list/apps/groceries/data/shopping_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// The whole data layer runs headlessly against in-memory SQLite, so none of
/// this needs a device or an emulator.
void main() {
  late AppDatabase database;
  late ShoppingRepository repo;
  late Directory tempDir;

  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() async {
    database = await AppDatabase.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
      modules: [groceriesMigrations],
    );
    tempDir = await Directory.systemTemp.createTemp('shopping_list_test');
    repo = ShoppingRepository(database, ImageStore(root: tempDir));
  });

  tearDown(() async {
    await database.close();
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  group('adding items', () {
    test('the first item opens a trip', () async {
      expect(await repo.trips.activeTrip(), isNull);

      await repo.addItem('Milk');

      final list = await repo.loadActiveList();
      expect(list.trip, isNotNull);
      expect(list.trip!.status, TripStatus.active);
      expect(list.items.single.nameSnapshot, 'Milk');
    });

    test('adding the same thing twice bumps quantity instead of duplicating',
        () async {
      await repo.addItem('Milk');
      await repo.addItem('milk', quantity: 2);

      final list = await repo.loadActiveList();
      expect(list.items, hasLength(1));
      expect(list.items.single.quantity, 3);
    });

    test('an already-picked line is not merged into', () async {
      final first = await repo.addItem('Milk');
      await repo.setPicked(first.id!, picked: true);
      await repo.addItem('Milk');

      // Buying milk, then deciding to buy more milk, is two lines — the first
      // is already in the trolley.
      final list = await repo.loadActiveList();
      expect(list.items, hasLength(2));
    });

    test('case and whitespace variants resolve to one product', () async {
      await repo.addItem('Milk');
      await repo.addItem('  MILK  ');

      expect(await repo.products.count(), 1);
    });
  });

  group('autocomplete', () {
    test('ranks by how often something is bought', () async {
      await repo.addItem('Bread');
      await repo.addItem('Butter');
      await repo.addItem('Butter');
      await repo.addItem('Butter');

      final results = await repo.searchProducts('b');
      expect(results.first.name, 'Butter');
    });

    test('prefers prefix matches over mid-word matches', () async {
      await repo.addItem('Sourdough bread');
      await repo.addItem('Bread rolls');

      final results = await repo.searchProducts('bread');
      expect(results.first.name, 'Bread rolls');
    });

    test('an empty query returns the usual basket', () async {
      await repo.addItem('Eggs');
      final results = await repo.searchProducts('');
      expect(results, isNotEmpty);
    });

    test('wildcards in a name are searched literally', () async {
      await repo.addItem('50% cream');
      await repo.addItem('Apples');

      final results = await repo.searchProducts('50%');
      expect(results, hasLength(1));
      expect(results.single.name, '50% cream');
    });
  });

  group('checkout', () {
    test('completing empties the active list and files the trip', () async {
      await repo.addItem('Milk');
      final trip = (await repo.loadActiveList()).trip!;

      await repo.completeTrip(tripId: trip.id!, totalMinor: 14250);

      expect((await repo.loadActiveList()).trip, isNull);

      final history = await repo.loadHistory();
      expect(history, hasLength(1));
      expect(history.single.trip.totalMinor, 14250);
      expect(history.single.itemCount, 1);
    });

    test('the next item after checkout opens a fresh trip', () async {
      await repo.addItem('Milk');
      final first = (await repo.loadActiveList()).trip!;
      await repo.completeTrip(tripId: first.id!, totalMinor: 1000);

      await repo.addItem('Bread');
      final second = (await repo.loadActiveList()).trip!;

      expect(second.id, isNot(first.id));
    });

    test('only one trip can be active at a time', () async {
      await repo.addItem('Milk');

      // The partial unique index has to reject this, not just the repository.
      expect(
        () => database.db.insert('trips', Trip.start().toMap()),
        throwsA(isA<DatabaseException>()),
      );
    });
  });

  group('history is a record, not a live view', () {
    test('the name is snapshotted at the time it was added', () async {
      await repo.addItem('Milk');
      final trip = (await repo.loadActiveList()).trip!;
      await repo.completeTrip(tripId: trip.id!, totalMinor: 500);

      // Deleting the catalogue entry must not rewrite what was bought.
      final product = (await repo.searchProducts('Milk')).single;
      await repo.products.delete(product.id!);

      final (_, items) = (await repo.loadTrip(trip.id!))!;
      expect(items.single.nameSnapshot, 'Milk');
      expect(items.single.productId, isNull);
    });
  });

  group('receipts', () {
    test('the stored path is relative, and resolves back to the file',
        () async {
      final source = File('${tempDir.path}/source.jpg')
        ..writeAsBytesSync([1, 2, 3]);

      await repo.addItem('Milk');
      final trip = (await repo.loadActiveList()).trip!;
      final stored = await repo.attachReceipt(trip.id!, source.path);

      // An absolute path here is the bug that loses receipts across installs.
      expect(stored.startsWith('receipts/'), isTrue);
      expect(stored.contains(tempDir.path), isFalse);
      expect(await repo.images.exists(stored), isTrue);
    });

    test('replacing a receipt deletes the old file', () async {
      final a = File('${tempDir.path}/a.jpg')..writeAsBytesSync([1]);
      final b = File('${tempDir.path}/b.jpg')..writeAsBytesSync([2]);

      await repo.addItem('Milk');
      final trip = (await repo.loadActiveList()).trip!;

      final first = await repo.attachReceipt(trip.id!, a.path);
      final second = await repo.attachReceipt(trip.id!, b.path);

      expect(await repo.images.exists(first), isFalse);
      expect(await repo.images.exists(second), isTrue);
    });

    test('deleting a trip removes its items and its receipt', () async {
      final source = File('${tempDir.path}/c.jpg')..writeAsBytesSync([3]);

      await repo.addItem('Milk');
      final trip = (await repo.loadActiveList()).trip!;
      final stored = await repo.attachReceipt(trip.id!, source.path);
      await repo.completeTrip(tripId: trip.id!, totalMinor: 100);

      await repo.deleteTrip(trip.id!);

      expect(await repo.loadHistory(), isEmpty);
      expect(await repo.images.exists(stored), isFalse);
      // ON DELETE CASCADE only fires with foreign keys on, which AppDatabase
      // enables per connection.
      expect(await repo.items.forTrip(trip.id!), isEmpty);
    });
  });

  group('undo', () {
    test('restoring a deleted item brings back the same row', () async {
      final item = await repo.addItem('Milk');
      await repo.deleteItem(item.id!);
      expect((await repo.loadActiveList()).items, isEmpty);

      await repo.restoreItem(item);

      final restored = (await repo.loadActiveList()).items.single;
      expect(restored.id, item.id);
      expect(restored.nameSnapshot, 'Milk');
    });
  });
}
