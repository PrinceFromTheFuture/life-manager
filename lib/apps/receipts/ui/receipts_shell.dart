import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shopping_list/apps/receipts/state/providers.dart';
import 'package:shopping_list/apps/receipts/ui/accounts/accounts_screen.dart';
import 'package:shopping_list/apps/receipts/ui/accounts/accounts_setup_drawer.dart';
import 'package:shopping_list/apps/receipts/ui/accounts/change_chip.dart';
import 'package:shopping_list/apps/receipts/ui/accounts/income_sheet.dart';
import 'package:shopping_list/apps/receipts/ui/expense_list_screen.dart';
import 'package:shopping_list/apps/receipts/ui/expense_sheet.dart';
import 'package:shopping_list/apps/receipts/ui/manage_lookups_screen.dart';
import 'package:shopping_list/apps/receipts/ui/nav/divider_tabs.dart';
import 'package:shopping_list/apps/receipts/ui/standing/standing_screen.dart';
import 'package:shopping_list/apps/receipts/ui/standing/standing_sheet.dart';
import 'package:shopping_list/apps/receipts/ui/stats_screen.dart';
import 'package:shopping_list/core/design/paper_snack.dart';
import 'package:shopping_list/core/design/theme.dart';
import 'package:shopping_list/core/design/tokens.dart';
import 'package:shopping_list/core/design/widgets/count_up_money.dart';
import 'package:shopping_list/core/design/widgets/ink_plate.dart';
import 'package:shopping_list/core/design/widgets/perforation.dart';
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
    'Standing',
    'Stats',
  ];

  static const int slips = 0;
  static const int accounts = 1;
  static const int standing = 2;
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

  /// Posts the standing orders and statements that came due while the app was
  /// closed, then says so once. Rows appearing from nowhere is disorienting;
  /// a print ceremony for something you did not do would be worse.
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
    final palette = context.thermal;
    final index = ref.watch(receiptsTabProvider);

    return Scaffold(
      backgroundColor: palette.paper,
      appBar: AppBar(
        title: const Text('Receipts'),
        actions: [
          IconButton(
            tooltip: 'Export month',
            icon: const Icon(Icons.ios_share),
            onPressed: () => exportSelectedMonth(context, ref),
          ),
          IconButton(
            tooltip: 'Categories',
            icon: const Icon(Icons.tune),
            // Straight to categories. Accounts used to live behind this button
            // too; they have a whole section of their own now, and two places
            // to edit the same thing is one place too many.
            onPressed: () => Navigator.of(context).push(
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
          const PerforatedRule(),
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
        ReceiptsShell.standing => const StandingSection(),
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
      ReceiptsShell.standing => const _StandingSummary(),
      // Slips and stats are the two month-scoped sections, and they share the
      // month, so they share its selector.
      _ => const MonthSelector(),
    };
  }
}

/// What you have, and what the cards are about to take.
class _AccountsSummary extends ConsumerWidget {
  const _AccountsSummary();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.thermal;
    // Retired accounts are still listed below, but they are not money you have
    // — leaving them in the headline would overstate it every month.
    final standings = ref
        .watch(accountStandingsProvider)
        .valueOrNull
        ?.where((s) => s.account.archivedAt == null)
        .toList();

    final onHand =
        standings?.fold<int>(0, (sum, s) => sum + s.balanceMinor) ?? 0;
    final today =
        standings?.fold<int>(0, (sum, s) => sum + s.todayDeltaMinor) ?? 0;

    return Padding(
      padding:
          const EdgeInsets.fromLTRB(Space.lg, Space.md, Space.lg, Space.md),
      child: Column(
        children: [
          Text('ON HAND', style: Type.eyebrow.copyWith(color: palette.faded)),
          const SizedBox(height: Space.xs),
          if (standings == null)
            Text(
              '—',
              style: Type.totalDisplay.copyWith(
                color: palette.print,
                fontSize: 48,
                letterSpacing: -1.8,
              ),
            )
          else
            CountUpMoney(
              amountMinor: onHand,
              style: Type.totalDisplay.copyWith(
                color: palette.print,
                fontSize: 48,
                letterSpacing: -1.8,
              ),
            ),
          const SizedBox(height: Space.sm),
          if (standings != null)
            ChangeChip(deltaMinor: today, balanceMinor: onHand),
        ],
      ),
    );
  }
}

/// What leaves every month without you touching anything.
class _StandingSummary extends ConsumerWidget {
  const _StandingSummary();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.thermal;
    final total = ref.watch(recurringMonthlyTotalProvider).valueOrNull;
    final rules = ref.watch(recurringRulesProvider).valueOrNull;
    final live = rules?.where((r) => r.active).length ?? 0;

    return _SummaryLine(
      eyebrow: 'EVERY MONTH',
      headline: total == null ? '—' : Money.format(total),
      detail: live == 0
          ? null
          : 'across $live ${live == 1 ? 'order' : 'orders'}',
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
    final palette = context.thermal;

    final (label, icon, onPressed) = switch (index) {
      ReceiptsShell.accounts => (
          'Record income',
          Icons.south_west,
          () => IncomeSheet.open(context),
        ),
      ReceiptsShell.standing => (
          'Add standing order',
          Icons.event_repeat_outlined,
          () => StandingSheet.open(context),
        ),
      ReceiptsShell.stats => (null, null, null),
      _ => (
          'Add expense',
          Icons.photo_camera_outlined,
          () => ExpenseSheet.open(context),
        ),
    };

    if (label == null) {
      return SizedBox(height: MediaQuery.paddingOf(context).bottom);
    }

    final plate = FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      label: Text(label),
    );

    return Container(
      color: palette.paper,
      padding: EdgeInsets.fromLTRB(
        Space.lg,
        Space.md,
        Space.lg,
        Space.md + MediaQuery.paddingOf(context).bottom,
      ),
      child: index == ReceiptsShell.accounts
          ? Row(
              children: [
                InkPlate(
                  primary: false,
                  size: const Size(Plate.height, Plate.height),
                  semanticLabel: 'Add account',
                  onPressed: () => openAddAccountDrawer(context),
                  child: Icon(Icons.account_balance_outlined,
                      size: 22, color: palette.print),
                ),
                const SizedBox(width: Space.sm),
                InkPlate(
                  primary: false,
                  size: const Size(Plate.height, Plate.height),
                  semanticLabel: 'Add payment method',
                  onPressed: () => openAddPaymentMethodDrawer(context),
                  child: Icon(Icons.credit_card_outlined,
                      size: 22, color: palette.print),
                ),
                const SizedBox(width: Space.sm),
                Expanded(child: plate),
              ],
            )
          : SizedBox(width: double.infinity, child: plate),
    );
  }
}
