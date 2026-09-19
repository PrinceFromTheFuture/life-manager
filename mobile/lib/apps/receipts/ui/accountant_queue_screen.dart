import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'package:shopping_list/apps/receipts/data/accountant_desk.dart';
import 'package:shopping_list/apps/receipts/data/models/expense.dart';
import 'package:shopping_list/apps/receipts/state/providers.dart';
import 'package:shopping_list/apps/receipts/ui/expense_detail_screen.dart';
import 'package:shopping_list/core/design/paper_snack.dart';
import 'package:shopping_list/core/design/theme.dart';
import 'package:shopping_list/core/design/tokens.dart';
import 'package:shopping_list/core/design/widgets/app_icon.dart';
import 'package:shopping_list/core/design/widgets/perforation.dart';
import 'package:shopping_list/core/util/money.dart';

/// The out-tray of business slips for the accountant.
///
/// Waiting copies sit above; copies already handed over sit below so a slip
/// can be sent again without fishing it out of the month roll.
class AccountantQueueScreen extends ConsumerStatefulWidget {
  const AccountantQueueScreen({super.key});

  @override
  ConsumerState<AccountantQueueScreen> createState() =>
      _AccountantQueueScreenState();
}

class _AccountantQueueScreenState extends ConsumerState<AccountantQueueScreen> {
  bool _busy = false;

  AccountantDesk _desk() {
    final origin = ref.read(accountantDeskOriginProvider).valueOrNull ??
        AccountantDesk.hostedOrigin;
    return AccountantDesk(origin);
  }

  Future<bool> _send(List<Expense> slips, {required bool stays}) async {
    final desk = _desk();
    setState(() => _busy = true);
    await WakelockPlus.enable();
    try {
      final sent = await ref.read(expensesProvider.notifier).handToAccountant(
            slips,
            desk: desk,
          );
      if (!mounted) return !stays;
      final again = slips.every((s) => s.transmittedAt != null);
      showPaperSnack(
        context,
        message: again
            ? (sent == 1 ? 'Sent again.' : '$sent slips sent again.')
            : sent == 1
                ? 'On its way to the accountant.'
                : '$sent slips on their way to the accountant.',
      );
      return !stays;
    } on Exception catch (e) {
      if (mounted) {
        showPaperSnack(context, message: '$e');
      }
      return false;
    } finally {
      await WakelockPlus.disable();
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;
    final pending = ref.watch(pendingAccountantProvider);
    final handed = ref.watch(handedAccountantProvider);

    final waiting = pending.valueOrNull;
    final sent = handed.valueOrNull;
    final loading = (waiting == null && pending.isLoading) ||
        (sent == null && handed.isLoading);
    final error = pending.error ?? handed.error;

    return Scaffold(
      backgroundColor: palette.paper,
      appBar: AppBar(title: const Text('Accountant')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(Space.lg),
                    child: Text(
                      '$error',
                      style: Type.caption.copyWith(color: palette.faded),
                    ),
                  ),
                )
              : _Tray(
                  waiting: waiting ?? const [],
                  sent: sent ?? const [],
                  busy: _busy,
                  onSend: _send,
                ),
      bottomNavigationBar: (waiting == null || waiting.isEmpty)
          ? SizedBox(height: MediaQuery.paddingOf(context).bottom)
          : _HandOverBar(
              count: waiting.length,
              busy: _busy,
              onPressed: () => _send(waiting, stays: false),
            ),
    );
  }
}

class _Tray extends StatelessWidget {
  const _Tray({
    required this.waiting,
    required this.sent,
    required this.busy,
    required this.onSend,
  });

  final List<Expense> waiting;
  final List<Expense> sent;
  final bool busy;
  final Future<bool> Function(List<Expense> slips, {required bool stays}) onSend;

  @override
  Widget build(BuildContext context) {
    if (waiting.isEmpty && sent.isEmpty) return const _EmptyTray();

    return CustomScrollView(
      slivers: [
        _sectionHead(
          context,
          eyebrow: 'WAITING TO GO',
          expenses: waiting,
        ),
        if (waiting.isEmpty)
          _quietLine(context, 'Nothing waiting.')
        else
          _slipList(
            expenses: waiting,
            stays: false,
            busy: busy,
            onSend: onSend,
          ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: Space.xl),
            child: _sectionHead(
              context,
              eyebrow: 'ALREADY HANDED OVER',
              expenses: sent,
              asSliver: false,
            ),
          ),
        ),
        if (sent.isEmpty)
          _quietLine(context, 'None handed over yet.')
        else
          _slipList(
            expenses: sent,
            stays: true,
            busy: busy,
            onSend: onSend,
          ),
        const SliverToBoxAdapter(child: SizedBox(height: Space.xxl)),
      ],
    );
  }

  static Widget _sectionHead(
    BuildContext context, {
    required String eyebrow,
    required List<Expense> expenses,
    bool asSliver = true,
  }) {
    final palette = context.thermal;
    final total = expenses.fold<int>(0, (sum, e) => sum + e.amountMinor);
    final child = Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.lg,
            Space.md,
            Space.lg,
            Space.md,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  eyebrow,
                  style: Type.eyebrow.copyWith(color: palette.faded),
                ),
              ),
              if (expenses.isNotEmpty)
                Text(
                  '${expenses.length} · ${Money.format(total)}',
                  style: Type.mono.copyWith(color: palette.print),
                ),
            ],
          ),
        ),
        const PerforatedRule(),
      ],
    );
    return asSliver ? SliverToBoxAdapter(child: child) : child;
  }

  static Widget _quietLine(BuildContext context, String text) {
    final palette = context.thermal;
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.lg, Space.md, Space.lg, 0),
        child: Text(text, style: Type.caption.copyWith(color: palette.faded)),
      ),
    );
  }

  static Widget _slipList({
    required List<Expense> expenses,
    required bool stays,
    required bool busy,
    required Future<bool> Function(List<Expense> slips, {required bool stays})
        onSend,
  }) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, i) {
          if (i.isOdd) return const PerforatedRule();
          final expense = expenses[i ~/ 2];
          return _SlipRow(
            expense: expense,
            stays: stays,
            enabled: !busy,
            onSend: () => onSend([expense], stays: stays),
          );
        },
        childCount: expenses.isEmpty ? 0 : expenses.length * 2 - 1,
      ),
    );
  }
}

class _SlipRow extends ConsumerWidget {
  const _SlipRow({
    required this.expense,
    required this.stays,
    required this.enabled,
    required this.onSend,
  });

  final Expense expense;
  final bool stays;
  final bool enabled;
  final Future<bool> Function() onSend;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.thermal;
    final when = expense.occurredAt.toLocal();
    final handed = expense.transmittedAt?.toLocal();

    return Dismissible(
      key: ValueKey('accountant-${stays ? 'sent' : 'wait'}-${expense.id}'),
      direction:
          enabled ? DismissDirection.startToEnd : DismissDirection.none,
      background: Container(
        color: palette.paperShade,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: Space.lg),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon(SolarIcons.Plain, color: palette.carbon),
            const SizedBox(width: Space.sm),
            Text(
              stays ? 'SEND AGAIN' : 'SEND',
              style: Type.eyebrow.copyWith(color: palette.carbon),
            ),
          ],
        ),
      ),
      confirmDismiss: (_) => onSend(),
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ExpenseDetailScreen(expenseId: expense.id!),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Space.lg,
            vertical: Space.md,
          ),
          child: Row(
            children: [
              _Thumb(relativePath: expense.receiptPath),
              const SizedBox(width: Space.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      expense.title,
                      style: Type.item.copyWith(
                        color: stays ? palette.faded : palette.print,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      handed == null
                          ? DateFormat('d MMM yyyy').format(when)
                          : 'Sent ${DateFormat('d MMM yyyy').format(handed)}',
                      style: Type.caption.copyWith(color: palette.faded),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Space.md),
              Text(
                expense.amountLabel,
                style: Type.monoBold.copyWith(
                  color: stays ? palette.faded : palette.print,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Thumb extends ConsumerWidget {
  const _Thumb({required this.relativePath});

  final String relativePath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.thermal;

    return FutureBuilder<File>(
      future: ref.read(expenseRepositoryProvider).images.resolve(relativePath),
      builder: (context, snapshot) {
        final file = snapshot.data;
        if (file == null) {
          return Container(width: 44, height: 56, color: palette.paperShade);
        }
        return ClipRRect(
          borderRadius: Radii.media,
          child: Image.file(
            file,
            width: 44,
            height: 56,
            fit: BoxFit.cover,
            errorBuilder: (context, _, __) =>
                Container(width: 44, height: 56, color: palette.paperShade),
          ),
        );
      },
    );
  }
}

class _EmptyTray extends StatelessWidget {
  const _EmptyTray();

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.xl),
        child: Text(
          'Nothing waiting for the accountant.',
          textAlign: TextAlign.center,
          style: Type.body.copyWith(color: palette.faded),
        ),
      ),
    );
  }
}

class _HandOverBar extends StatelessWidget {
  const _HandOverBar({
    required this.count,
    required this.busy,
    required this.onPressed,
  });

  final int count;
  final bool busy;
  final VoidCallback onPressed;

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
        child: FilledButton.icon(
          onPressed: busy ? null : onPressed,
          icon: const AppIcon(SolarIcons.Plain, size: 20),
          label: Text(
            busy
                ? 'Handing over…'
                : count == 1
                    ? 'Hand over to accountant'
                    : 'Hand over all',
          ),
        ),
      ),
    );
  }
}
