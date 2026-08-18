import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shopping_list/apps/receipts/data/expense_repository.dart';
import 'package:shopping_list/apps/receipts/state/providers.dart';
import 'package:shopping_list/apps/receipts/ui/accounts/account_detail_screen.dart';
import 'package:shopping_list/apps/receipts/ui/accounts/accounts_setup_drawer.dart';
import 'package:shopping_list/apps/receipts/ui/accounts/change_chip.dart';
import 'package:shopping_list/apps/receipts/ui/accounts/meta_chip.dart';
import 'package:shopping_list/core/design/theme.dart';
import 'package:shopping_list/core/design/tokens.dart';
import 'package:shopping_list/core/design/widgets/ink_plate.dart';
import 'package:shopping_list/core/design/widgets/perforation.dart';
import 'package:shopping_list/core/util/money.dart';

/// What you have, as a handful of passbook pages.
///
/// There are never more than a few accounts, so this is a carousel of cards
/// rather than a list that pretends it might be infinite. Each card is the
/// account — tap it to open the account, not a payment method hanging off it.
class AccountsSection extends ConsumerStatefulWidget {
  const AccountsSection({super.key});

  @override
  ConsumerState<AccountsSection> createState() => _AccountsSectionState();
}

class _AccountsSectionState extends ConsumerState<AccountsSection> {
  late final PageController _pages = PageController(viewportFraction: 0.80);
  int _page = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;
    final standings = ref.watch(accountStandingsProvider);

    return standings.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(Space.lg),
          child: Text('$e', style: Type.caption.copyWith(color: palette.faded)),
        ),
      ),
      data: (items) {
        if (items.isEmpty) return const _NoAccounts();
        final height = MediaQuery.sizeOf(context).height * 0.30;
        return Column(
          children: [
            const SizedBox(height: Space.lg),
            SizedBox(
              height: height,
              child: PageView.builder(
                controller: _pages,
                itemCount: items.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, i) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Space.sm),
                    child: _AccountCard(standing: items[i]),
                  );
                },
              ),
            ),
            if (items.length > 1) ...[
              const SizedBox(height: Space.md),
              _PageMarks(count: items.length, index: _page),
            ],
          ],
        );
      },
    );
  }
}

/// One passbook page. The balance is the whole point of the card; the chips
/// are the statement codes that fill the remaining paper.
class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.standing});

  final AccountStanding standing;

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;
    final account = standing.account;
    final retired = account.archivedAt != null;
    final ink = retired
        ? palette.faded
        : standing.balanceMinor < 0
            ? palette.carbon
            : palette.print;

    return Semantics(
      button: true,
      label: '${account.name}, ${Money.format(standing.balanceMinor)}',
      child: Material(
        color: palette.paperShade,
        shape: InkPlateBorder(
          borderRadius: Radii.key,
          side: BorderSide(
            color: palette.print.withValues(alpha: retired ? 0.18 : 0.35),
            width: 1.25,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => AccountDetailScreen(accountId: account.id!),
            ),
          ),
          customBorder: const InkPlateBorder(borderRadius: Radii.key),
          overlayColor: WidgetStatePropertyAll(
            palette.scorch.withValues(alpha: 0.18),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.lg,
              Space.md,
              Space.lg,
              Space.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const PerforatedRule(),
                const SizedBox(height: Space.md),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        account.name.toUpperCase(),
                        style: Type.eyebrow.copyWith(color: palette.faded),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (retired)
                      Text(
                        'RETIRED',
                        style: Type.eyebrow.copyWith(color: palette.faded),
                      ),
                  ],
                ),
                const Spacer(),
                Text(
                  Money.format(standing.balanceMinor),
                  style: Type.totalDisplay.copyWith(
                    color: ink,
                    fontSize: 34,
                    letterSpacing: -1.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: Space.md),
                Wrap(
                  spacing: Space.sm,
                  runSpacing: Space.sm,
                  children: [
                    ChangeChip(
                      deltaMinor: standing.todayDeltaMinor,
                      balanceMinor: standing.balanceMinor,
                      compact: true,
                    ),
                    for (final method in standing.methods)
                      MetaChip(label: method.label),
                    if (standing.owedMinor > 0)
                      MetaChip(label: '${Money.format(standing.owedMinor)} on cards'),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Punch-holes under the carousel. The filled one is the page you are on —
/// the same device as the divider tabs, just smaller.
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
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
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
