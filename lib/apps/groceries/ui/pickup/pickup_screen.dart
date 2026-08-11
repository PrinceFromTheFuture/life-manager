import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'package:shopping_list/apps/groceries/data/shopping_repository.dart';
import 'package:shopping_list/core/design/theme.dart';
import 'package:shopping_list/core/design/tokens.dart';
import 'package:shopping_list/core/design/widgets/perforation.dart';
import 'package:shopping_list/apps/groceries/state/providers.dart';
import 'package:shopping_list/apps/groceries/ui/checkout/checkout_screen.dart';
import 'package:shopping_list/apps/groceries/ui/list/item_row.dart';

/// The mode for actually being in the shop.
///
/// This is a separate route rather than a toggle on the main list because the
/// affordances genuinely differ: there is no keyboard, no reordering, no
/// quantity editing and no swipe-to-delete here. Every one of those is a way to
/// damage the list by accident while holding a phone in one hand and pushing a
/// trolley with the other, and none of them is something you need mid-aisle.
///
/// Undo is tapping the row again. A snackbar would sit on top of the next rows
/// you were about to check, which is the worst place to put it in exactly this
/// mode.
class PickupScreen extends ConsumerStatefulWidget {
  const PickupScreen({super.key});

  @override
  ConsumerState<PickupScreen> createState() => _PickupScreenState();
}

class _PickupScreenState extends ConsumerState<PickupScreen> {
  @override
  void initState() {
    super.initState();
    // A screen that sleeps every thirty seconds is unusable while shopping.
    // Scoped to this route only — the rest of the app has no business holding
    // the display on.
    WakelockPlus.enable();
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;
    final listAsync = ref.watch(activeListProvider);

    return Scaffold(
      backgroundColor: palette.paper,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Leave pick-up',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Pick-up'),
      ),
      body: listAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('$e', style: Type.caption.copyWith(color: palette.faded)),
        ),
        data: (list) => _PickupBody(list: list),
      ),
      bottomNavigationBar: listAsync.maybeWhen(
        data: (list) => _PickupFooter(list: list),
        orElse: () => const SizedBox.shrink(),
      ),
    );
  }
}

class _PickupBody extends ConsumerWidget {
  const _PickupBody({required this.list});

  final ActiveList list;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final toBuy = list.toBuy;
    final inCart = list.inCart;
    final controller = ref.read(activeListProvider.notifier);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _RemainingHeader(list: list)),

        SliverList.builder(
          itemCount: toBuy.length,
          itemBuilder: (context, i) => Column(
            children: [
              ItemRow(
                item: toBuy[i],
                large: true,
                onToggle: () {
                  controller.togglePicked(toBuy[i]);
                  HapticFeedback.mediumImpact();
                },
              ),
              const PerforatedRule(indent: Space.lg),
            ],
          ),
        ),

        if (inCart.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: Space.lg),
              child: Column(
                children: [
                  const TearEdge(),
                  const SizedBox(height: Space.sm),
                  Text(
                    'IN THE CART · ${inCart.length}',
                    style: Type.eyebrow.copyWith(color: context.thermal.faded),
                  ),
                ],
              ),
            ),
          ),

        SliverList.builder(
          itemCount: inCart.length,
          itemBuilder: (context, i) => Column(
            children: [
              ItemRow(
                item: inCart[i],
                large: true,
                onToggle: () {
                  controller.togglePicked(inCart[i]);
                  HapticFeedback.selectionClick();
                },
              ),
              const PerforatedRule(indent: Space.lg),
            ],
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: Space.xxl)),
      ],
    );
  }
}

/// The one number that matters in an aisle: how many things are still to find.
class _RemainingHeader extends StatelessWidget {
  const _RemainingHeader({required this.list});

  final ActiveList list;

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;
    final remaining = list.total - list.pickedCount;

    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$remaining',
                style: Type.totalDisplay.copyWith(color: palette.print),
              ),
              const SizedBox(width: Space.md),
              Text(
                'still to find',
                style: Type.body.copyWith(color: palette.faded),
              ),
            ],
          ),
          const SizedBox(height: Space.md),
          Text(
            '${list.pickedCount} OF ${list.total} IN THE CART',
            style: Type.eyebrow.copyWith(color: palette.faded),
          ),
          const SizedBox(height: Space.md),
          const PerforatedRule(),
        ],
      ),
    );
  }
}

class _PickupFooter extends StatelessWidget {
  const _PickupFooter({required this.list});

  final ActiveList list;

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;

    return Container(
      color: palette.paper,
      padding: EdgeInsets.fromLTRB(
        Space.lg,
        Space.md,
        Space.lg,
        Space.md + MediaQuery.paddingOf(context).bottom,
      ),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton(
          // Available before everything is ticked, because trolleys reach the
          // till with things still unfound and the app shouldn't argue.
          onPressed: list.isEmpty
              ? null
              : () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const CheckoutScreen(),
                    ),
                  ),
          child: Text(
            list.allPicked
                ? 'Check out'
                : 'Check out · ${list.total - list.pickedCount} still to find',
          ),
        ),
      ),
    );
  }
}
