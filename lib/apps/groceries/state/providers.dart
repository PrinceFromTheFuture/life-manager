import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shopping_list/apps/groceries/data/models/product.dart';
import 'package:shopping_list/apps/groceries/data/models/trip.dart';
import 'package:shopping_list/apps/groceries/data/models/trip_item.dart';
import 'package:shopping_list/apps/groceries/data/shopping_repository.dart';
import 'package:shopping_list/core/activity/providers.dart';
import 'package:shopping_list/core/providers.dart';

/// Built from the shared database rather than overridden in `main()`, so
/// adding a mini-app never requires editing the app's entry point.
final repositoryProvider = Provider<ShoppingRepository>(
  (ref) => ShoppingRepository(
    ref.watch(databaseProvider),
    ref.watch(imageStoreProvider),
  ),
);

// ---------------------------------------------------------------- active list

/// The open shopping trip and its items — the state behind both the main list
/// and Pick-Up Mode, so checking something off in one is reflected in the other
/// without any syncing.
class ActiveListController extends AsyncNotifier<ActiveList> {
  @override
  Future<ActiveList> build() => ref.read(repositoryProvider).loadActiveList();

  ShoppingRepository get _repo => ref.read(repositoryProvider);

  Future<void> _reload() async {
    state = AsyncData(await _repo.loadActiveList());
  }

  Future<void> addItem(String name, {double quantity = 1, String? unit}) async {
    if (name.trim().isEmpty) return;
    await _repo.addItem(name, quantity: quantity, unit: unit);
    await _reload();
  }

  /// Applied optimistically. In Pick-Up Mode this fires once per item while
  /// the user is walking, and a round-trip to SQLite before the row reacts
  /// would make the whole mode feel laggy under the one condition it exists
  /// for.
  Future<void> togglePicked(TripItem item) async {
    final next = !item.isPicked;

    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncData(
        ActiveList(
          trip: current.trip,
          items: [
            for (final i in current.items)
              if (i.id == item.id)
                i.copyWith(
                  isPicked: next,
                  pickedAt: next ? DateTime.now() : null,
                  clearPickedAt: !next,
                )
              else
                i,
          ],
        ),
      );
    }

    await _repo.setPicked(item.id!, picked: next);
  }

  Future<void> setQuantity(TripItem item, double quantity,
      {String? unit}) async {
    if (quantity <= 0) {
      await deleteItem(item);
      return;
    }
    await _repo.setQuantity(item.id!, quantity, unit: unit ?? item.unit);
    await _reload();
  }

  /// Returns the removed item so the caller can offer a real undo.
  Future<TripItem> deleteItem(TripItem item) async {
    await _repo.deleteItem(item.id!);
    await _reload();
    return item;
  }

  Future<void> restoreItem(TripItem item) async {
    await _repo.restoreItem(item);
    await _reload();
  }

  Future<void> unpickAll() async {
    final trip = state.valueOrNull?.trip;
    if (trip == null) return;
    await _repo.unpickAll(trip.id!);
    await _reload();
  }

  Future<String?> attachReceipt(String sourcePath) async {
    final trip = state.valueOrNull?.trip;
    if (trip == null) return null;
    final stored = await _repo.attachReceipt(trip.id!, sourcePath);
    await _reload();
    return stored;
  }

  Future<void> removeReceipt() async {
    final trip = state.valueOrNull?.trip;
    if (trip == null) return;
    await _repo.removeReceipt(trip.id!);
    await _reload();
  }

  /// Closes the trip out. The active list empties, history gains a row, and
  /// the next item added opens a fresh trip.
  Future<void> completeTrip({required int totalMinor, String? note}) async {
    final trip = state.valueOrNull?.trip;
    if (trip == null) return;
    await _repo.completeTrip(
      tripId: trip.id!,
      totalMinor: totalMinor,
      note: note,
    );
    await _reload();
    ref.invalidate(historyProvider);
    // The checkout just wrote a feed entry, so the hub is now stale.
    ref.invalidate(activityFeedProvider);
  }
}

final activeListProvider =
    AsyncNotifierProvider<ActiveListController, ActiveList>(
  ActiveListController.new,
);

// -------------------------------------------------------------------- history

class HistoryController extends AsyncNotifier<List<TripSummary>> {
  @override
  Future<List<TripSummary>> build() =>
      ref.read(repositoryProvider).loadHistory();

  Future<void> deleteTrip(int tripId) async {
    await ref.read(repositoryProvider).deleteTrip(tripId);
    state = AsyncData(await ref.read(repositoryProvider).loadHistory());
  }
}

final historyProvider =
    AsyncNotifierProvider<HistoryController, List<TripSummary>>(
  HistoryController.new,
);

/// A single past trip with its items, for the detail screen.
final tripDetailProvider =
    FutureProvider.autoDispose.family<(Trip, List<TripItem>)?, int>(
  (ref, tripId) => ref.read(repositoryProvider).loadTrip(tripId),
);

// ------------------------------------------------------------- autocomplete

/// What the user has typed into the add field. Kept in a provider rather than
/// local widget state so the suggestion strip can react without the text field
/// having to own it.
final addQueryProvider = StateProvider.autoDispose<String>((ref) => '');

/// Autocomplete results for the current query. An empty query yields the
/// user's most-bought products, so the strip is useful before they type
/// anything at all.
final suggestionsProvider = FutureProvider.autoDispose<List<Product>>((ref) {
  final query = ref.watch(addQueryProvider);
  return ref.read(repositoryProvider).searchProducts(query);
});
