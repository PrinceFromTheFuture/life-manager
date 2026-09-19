import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/apps/groceries/data/aisle_memory.dart';
import 'package:shopping_list/apps/groceries/data/models/trip_item.dart';

void main() {
  TripItem item({
    required int id,
    required int productId,
    int sort = 0,
  }) {
    return TripItem(
      id: id,
      tripId: 1,
      productId: productId,
      nameSnapshot: '$productId',
      sortOrder: sort,
    );
  }

  group('AisleMemory', () {
    test('an empty memory leaves the list alone', () {
      final items = [
        item(id: 1, productId: 10, sort: 0),
        item(id: 2, productId: 20, sort: 1),
      ];
      expect(
        AisleMemory.empty.arrange(
          items,
          productId: (i) => i.productId,
          listOrder: (i) => i.sortOrder,
        ),
        items,
      );
    });

    test('a single-item shop teaches nothing', () {
      final memory = AisleMemory.fromWalks([
        [10],
      ]);
      expect(memory.isEmpty, isTrue);
    });

    test('the first tick of a walk ranks first on the next list', () {
      // Store walk: produce (1), dairy (2), bakery (3).
      final memory = AisleMemory.fromWalks([
        [1, 2, 3],
      ]);
      final items = [
        item(id: 1, productId: 3, sort: 0),
        item(id: 2, productId: 1, sort: 1),
        item(id: 3, productId: 2, sort: 2),
      ];
      final arranged = memory.arrange(
        items,
        productId: (i) => i.productId,
        listOrder: (i) => i.sortOrder,
      );
      expect(arranged.map((i) => i.productId), [1, 2, 3]);
    });

    test('unknown products sit after anything already mapped', () {
      final memory = AisleMemory.fromWalks([
        [1, 2],
      ]);
      final items = [
        item(id: 1, productId: 99, sort: 0),
        item(id: 2, productId: 2, sort: 1),
        item(id: 3, productId: 1, sort: 2),
      ];
      final arranged = memory.arrange(
        items,
        productId: (i) => i.productId,
        listOrder: (i) => i.sortOrder,
      );
      expect(arranged.map((i) => i.productId), [1, 2, 99]);
    });

    test('a later shop outweighs an earlier one, without erasing it', () {
      final memory = AisleMemory.fromWalks([
        [1, 2, 3],
        [3, 2, 1],
      ]);
      // After one reverse walk at recency 0.35, 1 is still earlier than 3
      // (0.65*0 + 0.35*1 = 0.35 vs 0.65*1 + 0.35*0 = 0.65).
      expect(memory.rankOf(1)! < memory.rankOf(3)!, isTrue);
      expect(memory.rankOf(2), 0.5);
    });

    test('a duplicate tick in one shop counts once, at first finding', () {
      final memory = AisleMemory.fromWalks([
        [1, 2, 1, 3],
      ]);
      expect(memory.rankOf(1), 0);
      expect(memory.rankOf(2), 0.5);
      expect(memory.rankOf(3), 1);
    });
  });
}
