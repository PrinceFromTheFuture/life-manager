import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shopping_list/apps/receipts/data/expense_repository.dart';
import 'package:shopping_list/apps/receipts/data/finance/ledger.dart';
import 'package:shopping_list/apps/receipts/data/models/account_view.dart';
import 'package:shopping_list/apps/receipts/state/providers.dart';
import 'package:shopping_list/apps/receipts/ui/accounts/account_detail_screen.dart';
import 'package:shopping_list/apps/receipts/ui/accounts/accounts_setup_drawer.dart';
import 'package:shopping_list/apps/receipts/ui/accounts/glass_passbook.dart';
import 'package:shopping_list/apps/receipts/ui/accounts/ledger_entry_row.dart';
import 'package:shopping_list/core/design/theme.dart';
import 'package:shopping_list/core/design/tokens.dart';
import 'package:shopping_list/core/design/widgets/perforation.dart';

/// What you have, as frosted passbook pages with the ledger of the page
/// you are looking at printed underneath.
class AccountsSection extends ConsumerStatefulWidget {
  const AccountsSection({super.key});

  @override
  ConsumerState<AccountsSection> createState() => _AccountsSectionState();
}

class _AccountsSectionState extends ConsumerState<AccountsSection> {
  late final PageController _pages = PageController(viewportFraction: 0.88);
  int _page = 0;
  int? _viewId;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;
    final standings = ref.watch(accountStandingsProvider);
    final views = ref.watch(accountViewsProvider).valueOrNull ?? const [];
    final activeId = ref.watch(activeAccountViewIdProvider).valueOrNull;
    final view = viewById(views, activeId);

    ref.listen<AsyncValue<int?>>(activeAccountViewIdProvider, (prev, next) {
      if (next.valueOrNull == _viewId) return;
      _viewId = next.valueOrNull;
      _page = 0;
      if (_pages.hasClients) _pages.jumpToPage(0);
    });

    return standings.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(Space.lg),
          child: Text('$e', style: Type.caption.copyWith(color: palette.faded)),
        ),
      ),
      data: (all) {
        final items = standingsInView(all, view, forHeadline: false);
        if (items.isEmpty) {
          return view == null ? const _NoAccounts() : const _EmptyView();
        }
        final index = _page.clamp(0, items.length - 1);
        final selected = items[index];
        final reduce = MediaQuery.disableAnimationsOf(context);

        return Column(
          children: [
            const SizedBox(height: Space.md),
            _Enter(
              reduce: reduce,
              child: SizedBox(
                height: 188,
                child: PageView.builder(
                  controller: _pages,
                  padEnds: false,
                  itemCount: items.length,
                  onPageChanged: (i) => setState(() => _page = i),
                  itemBuilder: (context, i) {
                    return Padding(
                      padding: EdgeInsets.only(
                        left: i == 0 ? Space.lg : Space.sm,
                        right: Space.sm,
                      ),
                      child: _StandingCard(standing: items[i]),
                    );
                  },
                ),
              ),
            ),
            if (items.length > 1) ...[
              const SizedBox(height: Space.md),
              _PageMarks(count: items.length, index: index),
            ],
            const SizedBox(height: Space.lg),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.lg),
              child: Text(
                'LEDGER',
                style: Type.eyebrow.copyWith(color: palette.faded),
              ),
            ),
            const SizedBox(height: Space.sm),
            const PerforatedRule(),
            Expanded(
              child: AnimatedSwitcher(
                duration: reduce ? Duration.zero : Motion.settle,
                switchInCurve: Motion.heat,
                child: _AccountLedger(
                  key: ValueKey('ledger-${selected.account.id}'),
                  accountId: selected.account.id!,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StandingCard extends ConsumerWidget {
  const _StandingCard({required this.standing});

  final AccountStanding standing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountId = standing.account.id!;
    final lines = ref.watch(accountLedgerProvider(accountId)).valueOrNull;
    final today = _todayMoves(lines ?? const []);

    return GlassPassbook(
      standing: standing,
      inMinor: today.inMinor,
      outMinor: today.outMinor,
      onOpen: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => AccountDetailScreen(accountId: accountId),
        ),
      ),
    );
  }
}

class _AccountLedger extends ConsumerWidget {
  const _AccountLedger({super.key, required this.accountId});

  final int accountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.thermal;
    final lines = ref.watch(accountLedgerProvider(accountId));

    return lines.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(Space.lg),
          child: Text('$e', style: Type.caption.copyWith(color: palette.faded)),
        ),
      ),
      data: (entries) {
        if (entries.isEmpty) return const _NoEntries();
        return ListView.separated(
          padding: const EdgeInsets.only(bottom: Space.xxl),
          itemCount: entries.length,
          separatorBuilder: (context, index) =>
              const PerforatedRule(indent: Space.lg),
          itemBuilder: (context, i) => LedgerEntryRow(line: entries[i]),
        );
      },
    );
  }
}

class _Enter extends StatelessWidget {
  const _Enter({required this.child, required this.reduce});

  final Widget child;
  final bool reduce;

  @override
  Widget build(BuildContext context) {
    if (reduce) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Motion.settle,
      curve: Motion.heat,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 14 * (1 - t)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

({int inMinor, int outMinor}) _todayMoves(List<LedgerLine> lines) {
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, now.day);
  var inMinor = 0;
  var outMinor = 0;
  for (final line in Ledger.movement(lines)) {
    if (line.entry.occurredAt.isBefore(start)) continue;
    final amount = line.entry.amountMinor;
    if (amount > 0) inMinor += amount;
    if (amount < 0) outMinor += -amount;
  }
  return (inMinor: inMinor, outMinor: outMinor);
}

class _PageMarks extends StatelessWidget {
  const _PageMarks({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          AnimatedContainer(
            duration: Motion.quick,
            width: i == index ? 14 : 6,
            height: 6,
            decoration: BoxDecoration(
              borderRadius: Radii.media,
              color: i == index ? palette.print : palette.perforation,
            ),
          ),
        ],
      ],
    );
  }
}

class _NoAccounts extends StatelessWidget {
  const _NoAccounts();

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
              'No accounts yet.',
              style: Type.display.copyWith(color: palette.print, fontSize: 28),
            ),
            const SizedBox(height: Space.md),
            Text(
              'Add the account your money actually sits in. Payment methods '
              'hang off it.',
              style: Type.body.copyWith(color: palette.faded),
            ),
            const SizedBox(height: Space.lg),
            OutlinedButton(
              onPressed: () => openAddAccountDrawer(context),
              child: const Text('Add an account'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

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
              'Nothing in this view.',
              style: Type.display.copyWith(color: palette.print, fontSize: 28),
            ),
            const SizedBox(height: Space.md),
            Text(
              'Edit the view and pick the accounts it should add up.',
              style: Type.body.copyWith(color: palette.faded),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoEntries extends StatelessWidget {
  const _NoEntries();

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;

    return Padding(
      padding: const EdgeInsets.all(Space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: Space.lg),
          Text(
            'Nothing has moved yet.',
            style: Type.display.copyWith(color: palette.print, fontSize: 24),
          ),
          const SizedBox(height: Space.md),
          Text(
            'Every slip paid from this account writes a line here, and so does '
            'every correction.',
            style: Type.body.copyWith(color: palette.faded),
          ),
        ],
      ),
    );
  }
}
