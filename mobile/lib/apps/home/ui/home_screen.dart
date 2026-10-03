import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutty_solar_icons/solar_icons_flutter.dart';
import 'package:intl/intl.dart';

import 'package:shopping_list/apps/calendar/data/models/ticket.dart';
import 'package:shopping_list/apps/calendar/state/providers.dart';
import 'package:shopping_list/apps/groceries/state/providers.dart';
import 'package:shopping_list/apps/gym/gym_app.dart';
import 'package:shopping_list/apps/gym/ui/record_set_screen.dart';
import 'package:shopping_list/apps/home/ui/home_palette.dart';
import 'package:shopping_list/core/design/widgets/night_plate.dart';
import 'package:shopping_list/apps/receipts/receipts_app.dart';
import 'package:shopping_list/apps/receipts/state/providers.dart';
import 'package:shopping_list/apps/receipts/ui/expense_sheet.dart';
import 'package:shopping_list/core/app/mini_app_host.dart';
import 'package:shopping_list/core/design/tokens.dart';
import 'package:shopping_list/core/util/money.dart';
import 'package:shopping_list/hub/account_screen.dart';

/// What was spent since midnight, and how many slips that was.
final todaySpendProvider = FutureProvider<({int total, int count})>((ref) async {
  ref.watch(expensesProvider);
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, now.day);
  final rows = await ref.watch(expenseRepositoryProvider).between(
        start,
        start.add(const Duration(days: 1)),
      );
  return (
    total: rows.fold<int>(0, (sum, expense) => sum + expense.amountMinor),
    count: rows.length,
  );
});

/// The black home. Money and the next thing to be at, then the three actions
/// that should not take a search.
class HomeView extends ConsumerWidget {
  const HomeView({super.key, this.onOpen});

  /// Shell index of an app. Null when this view is not inside the shell.
  final ValueChanged<int>? onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spend = ref.watch(todaySpendProvider);
    final tickets = ref.watch(todayTicketsProvider);
    final list = ref.watch(activeListProvider);
    final upcoming = _upcoming(tickets.valueOrNull ?? const []);
    final leftToBuy = list.valueOrNull?.items.where((item) => !item.isPicked).length;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: HomePalette.ground,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: ColoredBox(
        color: HomePalette.ground,
        child: SafeArea(
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Space.lg, Space.md, Space.lg, Space.lg),
            children: [
              const _Header(),
              const SizedBox(height: Space.xl),
              SizedBox(
                height: 188,
                child: Row(
                  children: [
                    Expanded(
                      flex: 8,
                      child: _SpendTile(
                        spend: spend,
                        onTap: () => onOpen?.call(1),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 5,
                      child: _NextTile(
                        tickets: upcoming,
                        loading: tickets.isLoading,
                        onTap: () => onOpen?.call(2),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 112,
                child: Row(
                  children: [
                    Expanded(
                      child: _ActionTile(
                        icon: SolarIcons.Dumbbell,
                        title: 'Record a set',
                        detail: 'Stamp the load you just did.',
                        onTap: () => openMiniApp(
                          context,
                          const GymApp(),
                          initialScreen: (_) => const RecordSetScreen(),
                          fullscreenDialog: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ActionTile(
                        icon: SolarIcons.Bag,
                        title: 'Add an item',
                        detail: leftToBuy == null
                            ? 'Onto the grocery list.'
                            : leftToBuy == 0
                                ? 'The list is clear.'
                                : '$leftToBuy still to buy.',
                        onTap: () => _addGrocery(context, ref),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              _ReceiptButton(
                onTap: () => openMiniApp(
                  context,
                  const ReceiptsApp(),
                  initialScreen: (_) => const ExpenseSheet(),
                  fullscreenDialog: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

List<Ticket> _upcoming(List<Ticket> tickets) {
  final now = DateTime.now();
  final coming = [
    for (final ticket in tickets)
      if (!ticket.endsAt.isBefore(now)) ticket,
  ]..sort((a, b) => a.startsAt.compareTo(b.startsAt));
  if (coming.length <= 2) return coming;
  return coming.sublist(0, 2);
}

Future<void> _addGrocery(BuildContext context, WidgetRef ref) async {
  final name = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: HomePalette.tile,
    builder: (context) => const _AddItemSheet(),
  );
  if (name == null || name.trim().isEmpty) return;
  await ref.read(activeListProvider.notifier).addItem(name.trim());
}

class _Header extends StatelessWidget {
  const _Header();

  static const double _mark = 42;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const AccountScreen()),
          ),
          child: const _Portrait(size: _mark),
        ),
        const SizedBox(width: Space.md),
        const Expanded(child: _Nameplate()),
        const SizedBox(width: Space.sm),
        NightPlate(
          icon: SolarIcons.Bell,
          size: _mark,
          label: 'Notifications',
          onTap: () {},
        ),
        const SizedBox(width: Space.sm),
        NightPlate(
          icon: SolarIcons.Magnifer,
          size: _mark,
          label: 'Search',
          onTap: () {},
        ),
      ],
    );
  }
}

class _Portrait extends StatelessWidget {
  const _Portrait({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: Image.asset(
          'assets/home/profile.jpg',
          fit: BoxFit.cover,
          alignment: const Alignment(0, -0.62),
        ),
      ),
    );
  }
}

class _Nameplate extends StatelessWidget {
  const _Nameplate();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'good morning',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: Fonts.body,
            fontSize: 14,
            height: 1,
            letterSpacing: 0.1,
            fontWeight: FontWeight.w500,
            fontVariations: [FontVariation('wght', 500)],
            color: HomePalette.mist,
          ),
        ),
        SizedBox(height: 2),
        Text(
          'Amir Waisblay',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: Fonts.display,
            fontSize: 21,
            height: 1,
            letterSpacing: -0.4,
            fontWeight: FontWeight.w800,
            fontVariations: [
              FontVariation('wght', 700),
              FontVariation('wdth', 96),
            ],
            color: HomePalette.bone,
          ),
        ),
      ],
    );
  }
}

class _SpendTile extends StatelessWidget {
  const _SpendTile({required this.spend, required this.onTap});

  final AsyncValue<({int total, int count})> spend;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final data = spend.valueOrNull;
    final amount = data == null ? '—' : Money.format(data.total);
    final detail = data == null
        ? 'Today’s slips'
        : data.count == 0
            ? 'Nothing spent today'
            : data.count == 1
                ? '1 slip today'
                : '${data.count} slips today';

    return _Tile(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('TODAY', style: _eyebrow),
          const Spacer(),
          Text(
            amount,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: Fonts.mono,
              fontSize: 28,
              height: 1,
              letterSpacing: -0.8,
              fontWeight: FontWeight.w700,
              color: HomePalette.bone,
            ),
          ),
          const SizedBox(height: 8),
          Text(detail, style: _detail),
        ],
      ),
    );
  }
}

class _NextTile extends StatelessWidget {
  const _NextTile({
    required this.tickets,
    required this.loading,
    required this.onTap,
  });

  final List<Ticket> tickets;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final clock = DateFormat('HH:mm');

    return _Tile(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('NEXT', style: _eyebrow),
          const Spacer(),
          if (loading && tickets.isEmpty)
            const Text('…', style: _detail)
          else if (tickets.isEmpty)
            const Text(
              'Nothing else today.',
              style: _detail,
            )
          else
            for (final ticket in tickets) ...[
              Text(
                clock.format(ticket.startsAt),
                style: const TextStyle(
                  fontFamily: Fonts.mono,
                  fontSize: 13,
                  height: 1,
                  color: HomePalette.mist,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                ticket.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: Fonts.body,
                  fontSize: 15,
                  height: 1.15,
                  fontWeight: FontWeight.w600,
                  fontVariations: [FontVariation('wght', 600)],
                  color: HomePalette.bone,
                ),
              ),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.detail,
    required this.onTap,
  });

  final SolarIconData icon;
  final String title;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _Tile(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SolarIcon(
            icon,
            weight: SolarIconWeight.linear,
            color: HomePalette.bone,
            size: 22,
          ),
          const Spacer(),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: Fonts.body,
              fontSize: 15,
              height: 1.1,
              fontWeight: FontWeight.w600,
              fontVariations: [FontVariation('wght', 600)],
              color: HomePalette.bone,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            detail,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _detail,
          ),
        ],
      ),
    );
  }
}

class _ReceiptButton extends StatelessWidget {
  const _ReceiptButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: HomePalette.bone,
          foregroundColor: HomePalette.ink,
          elevation: 0,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(14)),
          ),
        ),
        icon: const SolarIcon(
          SolarIcons.Camera,
          weight: SolarIconWeight.linear,
          color: HomePalette.ink,
          size: 18,
        ),
        label: const Text('Record a receipt'),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: HomePalette.tile,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(Space.lg - 2),
          child: child,
        ),
      ),
    );
  }
}

class _AddItemSheet extends StatefulWidget {
  const _AddItemSheet();

  @override
  State<_AddItemSheet> createState() => _AddItemSheetState();
}

class _AddItemSheetState extends State<_AddItemSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(Space.lg, Space.lg, Space.lg, Space.lg + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Add to the list',
            style: TextStyle(
              fontFamily: Fonts.display,
              fontSize: 22,
              height: 1.1,
              fontWeight: FontWeight.w700,
              fontVariations: [
                FontVariation('wght', 700),
                FontVariation('wdth', 92),
              ],
              color: HomePalette.bone,
            ),
          ),
          const SizedBox(height: Space.md),
          TextField(
            controller: _controller,
            autofocus: true,
            textInputAction: TextInputAction.done,
            style: const TextStyle(color: HomePalette.bone),
            cursorColor: HomePalette.bone,
            decoration: const InputDecoration(
              hintText: 'Milk, batteries, coffee',
            ),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: Space.lg),
          FilledButton(
            onPressed: _submit,
            style: FilledButton.styleFrom(
              backgroundColor: HomePalette.bone,
              foregroundColor: HomePalette.ink,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(14)),
              ),
            ),
            child: const Text('Add item'),
          ),
          const SizedBox(height: Space.sm),
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}

const _eyebrow = TextStyle(
  fontFamily: Fonts.mono,
  fontSize: 11,
  height: 1,
  letterSpacing: 1.4,
  fontWeight: FontWeight.w700,
  color: HomePalette.mist,
);

const _detail = TextStyle(
  fontFamily: Fonts.body,
  fontSize: 13,
  height: 1.2,
  fontWeight: FontWeight.w500,
  fontVariations: [FontVariation('wght', 500)],
  color: HomePalette.mist,
);

/// Kept so a direct open of the home mini-app still lands on this surface.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) => const HomeView();
}
