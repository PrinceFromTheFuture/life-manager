import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/models/trip_item.dart';
import '../../data/repositories/shopping_repository.dart';
import '../../design/theme.dart';
import '../../design/tokens.dart';
import '../../design/widgets/perforation.dart';
import '../../state/providers.dart';
import '../checkout/checkout_screen.dart';
import '../history/history_screen.dart';
import '../pickup/pickup_screen.dart';
import 'add_item_bar.dart';
import 'item_row.dart';
import 'quantity_sheet.dart';

/// The main shopping list — a continuous roll of paper.
///
/// Items still to buy sit above the tear line; items already in the cart sit
/// below it, burned. Because the tear moves as the list is worked through, it
/// doubles as the progress indicator, which is why there isn't a separate one.
class ListScreen extends ConsumerWidget {
  const ListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.thermal;
    final listAsync = ref.watch(activeListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('List'),
        actions: [
          IconButton(
            tooltip: 'Past trips',
            icon: const Icon(Icons.receipt_long_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const HistoryScreen(),
              ),
            ),
          ),
          const SizedBox(width: Space.sm),
        ],
      ),
      // The add field and its suggestion strip live in the body, not in
      // `bottomNavigationBar`. Scaffold does not lift a bottom bar out of the
      // way of the keyboard, so on the first device build the field, the
      // suggestions and the primary action were all buried under it — you
      // could not see what you were typing, and autocomplete was invisible at
      // the exact moment it was useful. Inside the body, resizeToAvoidBottomInset
      // shrinks the list instead and everything stays reachable.
      body: Column(
        children: [
          Expanded(
            child: listAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _LoadFailed(error: e),
              data: (list) =>
                  list.isEmpty ? const _EmptyList() : _Roll(list: list),
            ),
          ),
          listAsync.maybeWhen(
            data: (list) => list.isEmpty
                ? const SizedBox.shrink()
                : _PrimaryAction(list: list),
            orElse: () => const SizedBox.shrink(),
          ),
          const AddItemBar(),
        ],
      ),
      backgroundColor: palette.paper,
    );
  }
}

class _Roll extends ConsumerWidget {
  const _Roll({required this.list});

  final ActiveList list;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final toBuy = list.toBuy;
    final inCart = list.inCart;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _RollHeader(list: list)),

        SliverList.builder(
          itemCount: toBuy.length,
          itemBuilder: (context, i) => _DismissibleRow(item: toBuy[i]),
        ),

        // The tear only exists once something has actually been picked up.
        // Showing it against an untouched list would state a division that
        // isn't there yet.
        if (inCart.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: Space.lg),
              child: Column(
                children: [
                  const TearEdge(),
                  const SizedBox(height: Space.sm),
                  Text(
                    'IN THE CART',
                    style: Type.eyebrow.copyWith(color: context.thermal.faded),
                  ),
                ],
              ),
            ),
          ),

        SliverList.builder(
          itemCount: inCart.length,
          itemBuilder: (context, i) => _DismissibleRow(item: inCart[i]),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: Space.xxl)),
      ],
    );
  }
}

class _RollHeader extends StatelessWidget {
  const _RollHeader({required this.list});

  final ActiveList list;

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;
    final started = list.trip?.startedAt ?? DateTime.now();

    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat('d MMM yyyy').format(started).toUpperCase(),
                style: Type.eyebrow.copyWith(color: palette.faded),
              ),
              Text(
                '${list.pickedCount} / ${list.total}',
                style: Type.eyebrow.copyWith(color: palette.faded),
              ),
            ],
          ),
          const SizedBox(height: Space.md),
          const PerforatedRule(),
        ],
      ),
    );
  }
}

/// A row that can be swiped away, with a real undo rather than a confirmation
/// dialog. Deleting an item is cheap to reverse, and a modal per deletion would
/// be a tax on the common case to protect against the rare one.
class _DismissibleRow extends ConsumerWidget {
  const _DismissibleRow({required this.item});

  final TripItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.thermal;

    return Column(
      children: [
        Dismissible(
          key: ValueKey('item-${item.id}'),
          direction: DismissDirection.endToStart,
          background: Container(
            color: palette.paperShade,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: Space.lg),
            child: Icon(Icons.delete_outline, color: palette.faded),
          ),
          onDismissed: (_) async {
            final messenger = ScaffoldMessenger.of(context);
            final controller = ref.read(activeListProvider.notifier);
            final removed = await controller.deleteItem(item);

            messenger.clearSnackBars();
            messenger.showSnackBar(
              SnackBar(
                content: Text('Removed ${removed.nameSnapshot}'),
                action: SnackBarAction(
                  label: 'Undo',
                  onPressed: () => controller.restoreItem(removed),
                ),
              ),
            );
          },
          child: ItemRow(
            item: item,
            onToggle: () =>
                ref.read(activeListProvider.notifier).togglePicked(item),
            onEdit: () => showQuantitySheet(context, ref, item),
          ),
        ),
        const PerforatedRule(indent: Space.lg),
      ],
    );
  }
}

/// One action, whose label states exactly what it does next. It changes to
/// checkout only once everything is in the cart, so the two never compete for
/// the same tap.
class _PrimaryAction extends StatelessWidget {
  const _PrimaryAction({required this.list});

  final ActiveList list;

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;
    final ready = list.allPicked;

    return Container(
      color: palette.paper,
      padding: const EdgeInsets.fromLTRB(Space.lg, Space.sm, Space.lg, 0),
      child: SizedBox(
        width: double.infinity,
        child: ready
            ? FilledButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const CheckoutScreen(),
                  ),
                ),
                child: const Text('Check out'),
              )
            : OutlinedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const PickupScreen(),
                  ),
                ),
                child: Text('Start pick-up · ${list.total} items'),
              ),
      ),
    );
  }
}

class _EmptyList extends StatelessWidget {
  const _EmptyList();

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const PerforatedRule(),
            const SizedBox(height: Space.lg),
            Text(
              'Nothing on the list yet.',
              style: Type.display.copyWith(color: palette.print, fontSize: 28),
            ),
            const SizedBox(height: Space.md),
            // An empty screen is an invitation to act, so it says what to do
            // rather than describing its own emptiness.
            Text(
              'Add the first thing you need. Anything you add gets remembered, '
              'so next time it is one tap.',
              style: Type.body.copyWith(color: palette.faded),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadFailed extends StatelessWidget {
  const _LoadFailed({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Space.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "The list didn't load.",
              style: Type.display.copyWith(color: palette.print, fontSize: 24),
            ),
            const SizedBox(height: Space.sm),
            Text('$error', style: Type.caption.copyWith(color: palette.faded)),
          ],
        ),
      ),
    );
  }
}
