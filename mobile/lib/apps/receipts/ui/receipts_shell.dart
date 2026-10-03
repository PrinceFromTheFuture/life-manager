import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutty_solar_icons/solar_icons_flutter.dart';

import 'package:shopping_list/apps/receipts/data/expense_repository.dart';
import 'package:shopping_list/apps/receipts/data/models/account_view.dart';
import 'package:shopping_list/apps/receipts/state/providers.dart';
import 'package:shopping_list/apps/receipts/ui/accounts/accounts_screen.dart';
import 'package:shopping_list/apps/receipts/ui/accountant_queue_screen.dart';
import 'package:shopping_list/apps/receipts/ui/accounts/accounts_setup_drawer.dart';
import 'package:shopping_list/apps/receipts/ui/accounts/change_chip.dart';
import 'package:shopping_list/apps/receipts/ui/accounts/income_sheet.dart';
import 'package:shopping_list/apps/receipts/ui/accounts/transfer_sheet.dart';
import 'package:shopping_list/apps/receipts/ui/accounts/views_drawer.dart';
import 'package:shopping_list/apps/receipts/ui/expense_list_screen.dart';
import 'package:shopping_list/apps/receipts/ui/expense_sheet.dart';
import 'package:shopping_list/apps/receipts/ui/manage_lookups_screen.dart';
import 'package:shopping_list/apps/receipts/ui/nav/divider_tabs.dart';
import 'package:shopping_list/apps/receipts/ui/recurring/recurring_screen.dart';
import 'package:shopping_list/apps/receipts/ui/recurring/recurring_sheet.dart';
import 'package:shopping_list/apps/receipts/ui/stats_screen.dart';
import 'package:shopping_list/apps/home/ui/home_palette.dart';
import 'package:shopping_list/core/design/paper_snack.dart';
import 'package:shopping_list/core/design/theme.dart';
import 'package:shopping_list/core/design/tokens.dart';
import 'package:shopping_list/core/design/widgets/count_up_money.dart';
import 'package:shopping_list/core/design/widgets/night_plate.dart';
import 'package:shopping_list/core/util/money.dart';

/// The four sections of the receipts app, in one frame.
///
/// The shell owns the app bar, the divider tabs and the one primary plate at
/// the bottom; each section owns only its own body. The summary line between
/// the tabs and the body is the shell's too, because every section has exactly
/// one headline number and it belongs in the same place on all of them.
class ReceiptsShell extends ConsumerStatefulWidget {
  const ReceiptsShell({super.key});

  static const List<String> _labels = [
    'Slips',
    'Accounts',
    'Recurring',
    'Stats',
  ];

  static const int slips = 0;
  static const int accounts = 1;
  static const int recurring = 2;
  static const int stats = 3;

  @override
  ConsumerState<ReceiptsShell> createState() => _ReceiptsShellState();
}

class _ReceiptsShellState extends ConsumerState<ReceiptsShell>
    with SingleTickerProviderStateMixin {
  /// Sections are built the first time they are opened and kept alive after,
  /// so ACCOUNTS never queries on a launch where you only logged a receipt.
  final _visited = <int>{};

  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: Motion.quick,
    value: 1,
  );

  @override
  void initState() {
    super.initState();
    _visited.add(ref.read(receiptsTabProvider));
    WidgetsBinding.instance.addPostFrameCallback((_) => _sweep());
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  /// Posts the credit statements that came due while the app was closed.
  /// Recurring payments do not write themselves.
  Future<void> _sweep() async {
    final result = await ref.read(financeControllerProvider).sweep();
    final message = result.message;
    if (message == null || !mounted) return;
    showPaperSnack(context, message: message);
  }

  void _select(int index) {
    if (index == ref.read(receiptsTabProvider)) return;
    setState(() => _visited.add(index));
    ref.read(receiptsTabProvider.notifier).state = index;

    if (!MediaQuery.disableAnimationsOf(context)) {
      _fade.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final index = ref.watch(receiptsTabProvider);

    return Scaffold(
      backgroundColor: HomePalette.ground,
      appBar: AppBar(
        title: const Text('Receipts'),
        actions: [
          NightPlate(
            icon: SolarIcons.Export,
            label: 'Export month',
            onTap: () => exportSelectedMonth(context, ref),
          ),
          const SizedBox(width: Space.sm),
          NightPlate(
            icon: SolarIcons.Plain,
            label: 'Accountant',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const AccountantQueueScreen(),
              ),
            ),
          ),
          const SizedBox(width: Space.sm),
          NightPlate(
            icon: SolarIcons.Tuning,
            label: 'Categories',
            // Straight to categories. Accounts used to live behind this button
            // too; they have a whole section of their own now, and two places
            // to edit the same thing is one place too many.
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const ManageLookupsScreen(),
              ),
            ),
          ),
          const SizedBox(width: Space.sm),
        ],
      ),
      body: Column(
        children: [
          DividerTabs(
            labels: ReceiptsShell._labels,
            index: index,
            onSelected: _select,
          ),
          _Summary(index: index),
          Expanded(
            child: FadeTransition(
              opacity: _fade,
              child: IndexedStack(
                index: index,
                sizing: StackFit.expand,
                children: [
                  for (var i = 0; i < ReceiptsShell._labels.length; i++)
                    _visited.contains(i)
                        ? _body(i)
                        : const SizedBox.shrink(),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _ActionBar(index: index),
    );
  }

  Widget _body(int index) => switch (index) {
        ReceiptsShell.accounts => const AccountsSection(),
        ReceiptsShell.recurring => const RecurringSection(),
        ReceiptsShell.stats => const StatsSection(),
        _ => const SlipsSection(),
      };
}

/// One headline number per section, always in the same place.
class _Summary extends StatelessWidget {
  const _Summary({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    return switch (index) {
      ReceiptsShell.accounts => const _AccountsSummary(),
      ReceiptsShell.recurring => const _RecurringSummary(),
      ReceiptsShell.stats => const StatsSummary(),
      _ => const MonthSelector(),
    };
  }
}

/// What you have, and what the cards are about to take.
///
/// The headline is the total of whichever view is active, and tapping it is how
/// you change view. The number and the carousel below it have to agree: a
/// headline that always summed every account would contradict the passbooks on
/// screen the moment a view was in use.
class _AccountsSummary extends ConsumerWidget {
  const _AccountsSummary();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.thermal;
    final all = ref.watch(accountStandingsProvider).valueOrNull;
    final views = ref.watch(accountViewsProvider).valueOrNull ?? const [];
    final activeId = ref.watch(activeAccountViewIdProvider).valueOrNull;
    final view = viewById(views, activeId);

    // Retired accounts are still listed below, but they are not money you have
    // — leaving them in the headline would overstate it every month.
    final standings = all == null
        ? null
        : standingsInView(all, view, forHeadline: true);

    final onHand =
        standings?.fold<int>(0, (sum, s) => sum + s.balanceMinor) ?? 0;
    final today =
        standings?.fold<int>(0, (sum, s) => sum + s.todayDeltaMinor) ?? 0;
    final label = view == null ? 'ON HAND' : view.name.toUpperCase();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Space.lg,
        Space.xl + 10,
        Space.lg,
        Space.xl + 10,
      ),
      child: Semantics(
        button: true,
        label: 'View: ${view?.name ?? AccountView.allLabel}. Change view.',
        child: InkWell(
          onTap: () => openAccountViewsDrawer(context),
          child: SizedBox(
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Type.eyebrow.copyWith(color: palette.faded),
                      ),
                    ),
                    const SizedBox(width: Space.xs),
                    const SolarIcon(
                      SolarIcons.AltArrowDown,
                      weight: SolarIconWeight.linear,
                      size: 14,
                      color: HomePalette.mist,
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: Space.xs),
                  child: standings == null
                      ? Text(
                          '—',
                          style: Type.totalDisplay.copyWith(
                            color: palette.print,
                            fontSize: 48,
                            fontFamily: Fonts.display,
                          ),
                        )
                      : CountUpMoney(
                          amountMinor: onHand,
                          style: Type.totalDisplay.copyWith(
                            color: palette.print,
                            fontFamily: Fonts.display,
                            fontSize: 48,
                          ),
                        ),
                ),
                if (standings != null)
                  ChangeChip(deltaMinor: today, balanceMinor: onHand),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// What you usually pay each month. Not a ledger total — a reminder.
class _RecurringSummary extends ConsumerWidget {
  const _RecurringSummary();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.thermal;
    final total = ref.watch(recurringMonthlyTotalProvider).valueOrNull;
    final rules = ref.watch(recurringRulesProvider).valueOrNull;
    final live = rules?.where((r) => !r.isIncome).length ?? 0;

    return _SummaryLine(
      eyebrow: 'EVERY MONTH',
      headline: total == null ? '—' : Money.format(total),
      detail: live == 0
          ? null
          : 'across $live ${live == 1 ? 'payment' : 'payments'}',
      ink: palette.print,
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({
    required this.eyebrow,
    required this.headline,
    required this.detail,
    required this.ink,
  });

  final String eyebrow;
  final String headline;
  final String? detail;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;

    return Padding(
      padding:
          const EdgeInsets.fromLTRB(Space.lg, Space.md, Space.lg, Space.md),
      child: Column(
        children: [
          Text(eyebrow, style: Type.eyebrow.copyWith(color: palette.faded)),
          const SizedBox(height: Space.xs),
          Text(
            headline,
            style: Type.totalDisplay.copyWith(color: ink, fontSize: 32),
          ),
          if (detail != null) ...[
            const SizedBox(height: Space.xs),
            Text(
              detail!,
              style: Type.caption.copyWith(color: palette.faded),
            ),
          ],
        ],
      ),
    );
  }
}

/// One primary plate, whatever the section is for.
///
/// Statistics has none: there is nothing to add to a page that only reads.
class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    final (label, icon, onPressed) = switch (index) {
      ReceiptsShell.accounts => (
          'Income',
          SolarIcons.ArrowLeftDown,
          () => IncomeSheet.open(context),
        ),
      ReceiptsShell.recurring => (
          'Add recurring',
          SolarIcons.Repeat,
          () => RecurringSheet.open(context),
        ),
      ReceiptsShell.stats => (null, null, null),
      _ => (
          'Add expense',
          SolarIcons.CameraMinimalistic,
          () => ExpenseSheet.open(context),
        ),
    };

    if (label == null) {
      return SizedBox(height: MediaQuery.paddingOf(context).bottom);
    }

    final button = _NightButton(
      label: label,
      icon: icon!,
      onPressed: onPressed!,
    );

    return Container(
      color: HomePalette.ground,
      padding: EdgeInsets.fromLTRB(
        Space.lg,
        Space.md,
        Space.lg,
        Space.md + MediaQuery.paddingOf(context).bottom,
      ),
      child: index == ReceiptsShell.accounts
          ? Row(
              children: [
                NightPlate(
                  icon: SolarIcons.AddCircle,
                  label: 'New account or payment method',
                  onTap: () => openNewFinanceDrawer(context),
                ),
                const SizedBox(width: Space.sm),
                Expanded(
                  child: _NightButton(
                    label: 'Income',
                    icon: SolarIcons.ArrowLeftDown,
                    onPressed: () => IncomeSheet.open(context),
                  ),
                ),
                const SizedBox(width: Space.sm),
                Expanded(
                  child: _NightButton(
                    label: 'Transfer',
                    icon: SolarIcons.Restart,
                    onPressed: () => TransferSheet.open(context),
                    primary: false,
                  ),
                ),
              ],
            )
          : SizedBox(width: double.infinity, child: button),
    );
  }
}

class _NightButton extends StatelessWidget {
  const _NightButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.primary = true,
  });

  final String label;
  final SolarIconData icon;
  final VoidCallback onPressed;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final background = primary ? HomePalette.bone : HomePalette.tile;
    final foreground = primary ? HomePalette.ink : HomePalette.bone;
    return SizedBox(
      height: 54,
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          elevation: 0,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(14)),
          ),
        ),
        icon: SolarIcon(
          icon,
          weight: SolarIconWeight.linear,
          color: foreground,
          size: 18,
        ),
        label: Text(label),
      ),
    );
  }
}
