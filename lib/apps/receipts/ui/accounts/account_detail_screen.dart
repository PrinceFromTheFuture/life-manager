import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shopping_list/apps/receipts/data/expense_repository.dart';
import 'package:shopping_list/apps/receipts/data/finance/ledger.dart';
import 'package:shopping_list/apps/receipts/data/finance/statement_cycle.dart';
import 'package:shopping_list/apps/receipts/data/models/payment_method.dart';
import 'package:shopping_list/apps/receipts/state/providers.dart';
import 'package:shopping_list/apps/receipts/ui/accounts/account_sheet.dart';
import 'package:shopping_list/apps/receipts/ui/accounts/cycle_band.dart';
import 'package:shopping_list/apps/receipts/ui/accounts/glass_passbook.dart';
import 'package:shopping_list/apps/receipts/ui/accounts/ledger_entry_row.dart';
import 'package:shopping_list/apps/receipts/ui/accounts/payment_method_sheet.dart';
import 'package:shopping_list/core/design/theme.dart';
import 'package:shopping_list/core/design/tokens.dart';
import 'package:shopping_list/core/design/widgets/perforation.dart';
import 'package:shopping_list/core/design/widgets/app_icon.dart';

/// One account, elevated: what it is, what pays from it, and every line
/// that built the balance.
class AccountDetailScreen extends ConsumerWidget {
  const AccountDetailScreen({super.key, required this.accountId});

  final int accountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.thermal;
    final standings = ref.watch(accountStandingsProvider).valueOrNull ?? const [];
    final standing =
        standings.where((s) => s.account.id == accountId).firstOrNull;
    final account = standing?.account;
    final lines = ref.watch(accountLedgerProvider(accountId));

    return Scaffold(
      backgroundColor: palette.paper,
      appBar: AppBar(
        title: Text(account?.name ?? 'Account'),
        actions: [
          if (account != null) ...[
            IconButton(
              tooltip: 'Edit account',
              icon: const AppIcon(SolarIcons.PenNewSquare),
              onPressed: () => AccountSheet.open(context, existing: account),
            ),
            IconButton(
              tooltip: 'Retire account',
              icon: const AppIcon(SolarIcons.TrashBinMinimalistic),
              onPressed: () => _retire(context, ref, account.id!),
            ),
          ],
          const SizedBox(width: Space.sm),
        ],
      ),
      body: lines.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(Space.lg),
            child:
                Text('$e', style: Type.caption.copyWith(color: palette.faded)),
          ),
        ),
        data: (entries) {
          return ListView(
            padding: const EdgeInsets.only(bottom: Space.xxl),
            children: [
              if (standing != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Space.lg,
                    Space.md,
                    Space.lg,
                    0,
                  ),
                  child: SizedBox(
                    height: 188,
                    child: GlassPassbook(
                      standing: standing,
                      inMinor: _todayIn(entries),
                      outMinor: _todayOut(entries),
                    ),
                  ),
                ),
              const SizedBox(height: Space.lg),
              _PaysWith(standing: standing),
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
              if (entries.isEmpty)
                const _NoEntries()
              else
                for (final line in entries) ...[
                  LedgerEntryRow(line: line),
                  if (line != entries.last)
                    const PerforatedRule(indent: Space.lg),
                ],
            ],
          );
        },
      ),
    );
  }

  static Future<void> _retire(
    BuildContext context,
    WidgetRef ref,
    int accountId,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      useRootNavigator: false,
      builder: (context) => AlertDialog(
        backgroundColor: context.thermal.paper,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: const Text('Retire this account?'),
        content: const Text(
          'It stops being offered, along with everything you pay from it. Its '
          'slips and its ledger stay exactly as they are.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Retire'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await ref.read(financeControllerProvider).archiveAccount(accountId);
    if (context.mounted) Navigator.of(context).pop();
  }

  static int _todayIn(List<LedgerLine> lines) {
    final start = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    var total = 0;
    for (final line in Ledger.movement(lines)) {
      if (line.entry.occurredAt.isBefore(start)) continue;
      if (line.entry.amountMinor > 0) total += line.entry.amountMinor;
    }
    return total;
  }

  static int _todayOut(List<LedgerLine> lines) {
    final start = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    var total = 0;
    for (final line in Ledger.movement(lines)) {
      if (line.entry.occurredAt.isBefore(start)) continue;
      if (line.entry.amountMinor < 0) total += -line.entry.amountMinor;
    }
    return total;
  }
}

class _PaysWith extends StatelessWidget {
  const _PaysWith({required this.standing});

  final AccountStanding? standing;

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;
    final methods = standing?.methods ?? const <PaymentMethod>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.lg),
          child: Text(
            'PAYS WITH',
            style: Type.eyebrow.copyWith(color: palette.faded),
          ),
        ),
        const SizedBox(height: Space.sm),
        const PerforatedRule(),
        if (methods.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.lg, Space.md, Space.lg, 0),
            child: Text(
              'Nothing pays from this yet. A payment method is a way of '
              'reaching the account, not the account itself.',
              style: Type.caption.copyWith(color: palette.faded),
            ),
          )
        else
          for (final method in methods)
            _MethodRow(
              method: method,
              committedMinor: standing?.committed[method.id] ?? 0,
            ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: standing == null
                ? null
                    : () => PaymentMethodSheet.open(
                      context,
                      accountId: standing!.account.id!,
                    ),
            child: const Text('Add a payment method'),
          ),
        ),
      ],
    );
  }
}

class _MethodRow extends StatelessWidget {
  const _MethodRow({required this.method, required this.committedMinor});

  final PaymentMethod method;
  final int committedMinor;

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;
    final now = DateTime.now();
    final statementDay = method.statementDay;

    return InkWell(
      onTap: () => PaymentMethodSheet.open(context, existing: method),
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
            Text(
              method.label,
              style: Type.item.copyWith(color: palette.print),
            ),
            const SizedBox(height: Space.xs),
            if (method.isCredit && statementDay != null)
              CycleBand(
                committedMinor: committedMinor,
                limitMinor: method.creditLimitMinor,
                cycleStart: StatementCycles.open(now, statementDay).start,
                settlesOn: StatementCycles.open(now, statementDay).settlesOn,
                now: now,
              )
            else
              Text(
                method.isCredit
                    ? 'Credit · set a statement day to track the cycle'
                    : 'Direct · leaves the account when you pay',
                style: Type.caption.copyWith(color: palette.faded),
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
