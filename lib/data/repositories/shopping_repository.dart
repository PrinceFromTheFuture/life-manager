import 'package:sqflite/sqflite.dart';

import '../dao/product_dao.dart';
import '../dao/trip_dao.dart';
import '../dao/trip_item_dao.dart';
import '../db/database.dart';
import '../image_store.dart';
import '../models/product.dart';
import '../models/trip.dart';
import '../models/trip_item.dart';

/// The active shopping list: the open trip and everything on it.
///
/// There is no separate "current list" concept in this app — the list the user
/// looks at *is* the active trip, which is what makes checkout a state change
/// rather than a copy.
class ActiveList {
  const ActiveList({required this.trip, required this.items});

  final Trip? trip;
  final List<TripItem> items;

  static const ActiveList empty = ActiveList(trip: null, items: []);

  List<TripItem> get toBuy => items.where((i) => !i.isPicked).toList();
  List<TripItem> get inCart => items.where((i) => i.isPicked).toList();

  int get total => items.length;
  int get pickedCount => items.where((i) => i.isPicked).length;
  bool get isEmpty => items.isEmpty;

  /// How far through the trip we are, 0–1. Drives the tear line's position.
  double get progress => items.isEmpty ? 0 : pickedCount / items.length;

  bool get allPicked => items.isNotEmpty && pickedCount == items.length;
}

class ShoppingRepository {
  ShoppingRepository(this._appDb, this.images);

  final AppDatabase _appDb;
  final ImageStore images;

  Database get _db => _appDb.db;

  ProductDao get products => ProductDao(_db);
  TripDao get trips => TripDao(_db);
  TripItemDao get items => TripItemDao(_db);

  // ---------------------------------------------------------------- reading

  Future<ActiveList> loadActiveList() async {
    final trip = await trips.activeTrip();
    if (trip == null) return ActiveList.empty;
    return ActiveList(trip: trip, items: await items.forTrip(trip.id!));
  }

  Future<List<Product>> searchProducts(String query, {int limit = 8}) =>
      products.search(query, limit: limit);

  Future<List<TripSummary>> loadHistory({int limit = 100}) =>
      trips.history(limit: limit);

  Future<(Trip, List<TripItem>)?> loadTrip(int tripId) async {
    final trip = await trips.byId(tripId);
    if (trip == null) return null;
    return (trip, await items.forTrip(tripId));
  }

  // ---------------------------------------------------------------- writing

  /// Adds [rawName] to the active list.
  ///
  /// Runs as one transaction across four tables' worth of work: open a trip if
  /// none is open, resolve or create the catalogue entry, merge into an
  /// existing unpicked line if there is one, and bump the product's ranking.
  /// Partial application here would leave an item on a list with no product
  /// behind it, so it either all lands or none of it does.
  Future<TripItem> addItem(
    String rawName, {
    double quantity = 1,
    String? unit,
  }) async {
    return _db.transaction((txn) async {
      final productDao = ProductDao(txn);
      final tripDao = TripDao(txn);
      final itemDao = TripItemDao(txn);

      final trip = await tripDao.ensureActive();
      final product = await productDao.findOrCreate(rawName, unit: unit);
      await productDao.touch(product.id!);

      // Adding something already on the list bumps its quantity. Two "Milk"
      // rows is never what someone meant, and it makes the list harder to read
      // in the one place readability matters most.
      final existing =
          await itemDao.findUnpickedByProduct(trip.id!, product.id!);
      if (existing != null) {
        final merged = existing.copyWith(
          quantity: existing.quantity + quantity,
          unit: unit ?? existing.unit,
        );
        await itemDao.setQuantity(
          existing.id!,
          merged.quantity,
          unit: merged.unit,
        );
        return merged;
      }

      return itemDao.insert(
        TripItem(
          tripId: trip.id!,
          productId: product.id,
          nameSnapshot: product.name,
          quantity: quantity,
          unit: unit ?? product.defaultUnit,
          sortOrder: await itemDao.nextSortOrder(trip.id!),
        ),
      );
    });
  }

  Future<void> setPicked(int itemId, {required bool picked}) =>
      items.setPicked(itemId, picked);

  Future<void> setQuantity(int itemId, double quantity, {String? unit}) =>
      items.setQuantity(itemId, quantity, unit: unit);

  Future<void> deleteItem(int itemId) => items.delete(itemId);

  /// Puts a deleted item back, id and all, so undo is a true reversal.
  Future<void> restoreItem(TripItem item) => items.restore(item);

  Future<void> unpickAll(int tripId) => items.unpickAll(tripId);

  /// Copies a picked image into managed storage and attaches it to the trip.
  /// Returns the stored relative path.
  Future<String> attachReceipt(int tripId, String sourcePath) async {
    final previous = (await trips.byId(tripId))?.receiptPath;
    final stored = await images.saveReceipt(sourcePath, tripId: tripId);
    await trips.setReceiptPath(tripId, stored);

    // Replacing a photo shouldn't leave the old one occupying storage forever.
    if (previous != null && previous != stored) {
      await images.delete(previous);
    }
    return stored;
  }

  Future<void> removeReceipt(int tripId) async {
    final existing = (await trips.byId(tripId))?.receiptPath;
    await trips.setReceiptPath(tripId, null);
    if (existing != null) await images.delete(existing);
  }

  /// Closes out the trip. After this the main list is empty and the next added
  /// item opens a fresh trip.
  Future<void> completeTrip({
    required int tripId,
    required int totalMinor,
    String? note,
  }) async {
    final trip = await trips.byId(tripId);
    await trips.complete(
      tripId: tripId,
      totalMinor: totalMinor,
      receiptPath: trip?.receiptPath,
      note: note,
    );
  }

  /// Deletes a past trip and the receipt image that belonged to it.
  Future<void> deleteTrip(int tripId) async {
    final trip = await trips.byId(tripId);
    await trips.delete(tripId);
    if (trip?.receiptPath != null) {
      await images.delete(trip!.receiptPath!);
    }
  }
}
