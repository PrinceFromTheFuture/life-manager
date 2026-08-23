import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:shopping_list/apps/receipts/data/models/category_ink.dart';
import 'package:shopping_list/apps/receipts/state/providers.dart';
import 'package:shopping_list/core/design/theme.dart';
import 'package:shopping_list/core/design/tokens.dart';
import 'package:shopping_list/core/design/widgets/perforation.dart';
import 'package:shopping_list/core/util/money.dart';

/// The thinner sibling of an expense slip: who paid you, how much, when.
class IncomeDetailScreen extends ConsumerWidget {
  const IncomeDetailScreen({super.key, required this.incomeId});

  final int incomeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.thermal;
    final async = ref.watch(incomeDetailProvider(incomeId));
    final brightness = Theme.of(context).brightness;
    final inInk = CategoryInk.pine.of(brightness);

    return Scaffold(
      backgroundColor: palette.paper,
      appBar: AppBar(title: const Text('Income')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(Space.lg),
            child: Text('$e', style: Type.caption.copyWith(color: palette.faded)),
          ),
        ),
        data: (income) {
          if (income == null) {
            return Center(
              child: Text(
                'That arrival is no longer on this phone.',
                style: Type.body.copyWith(color: palette.faded),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              Space.lg,
              Space.lg,
              Space.lg,
              Space.xxl,
            ),
            children: [
              Text(
                'ARRIVED',
                style: Type.eyebrow.copyWith(color: palette.faded),
              ),
              const SizedBox(height: Space.sm),
              Text(
                Money.formatSigned(income.amountMinor),
                style: Type.totalDisplay.copyWith(color: inInk, fontSize: 40),
              ),
              const SizedBox(height: Space.lg),
              const PerforatedRule(),
              const SizedBox(height: Space.lg),
              _Row(label: 'FROM', value: income.sourceName),
              _Row(
                label: 'WHEN',
                value: DateFormat('d MMM yyyy').format(income.occurredAt),
              ),
              if ((income.note ?? '').trim().isNotEmpty)
                _Row(label: 'NOTE', value: income.note!.trim()),
              if (income.isAutoCreated)
                const _Row(
                    label: 'HOW', value: 'A standing order wrote this.'),
            ],
          );
        },
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: Type.eyebrow.copyWith(color: palette.faded),
            ),
          ),
          Expanded(
            child: Text(value, style: Type.item.copyWith(color: palette.print)),
          ),
        ],
      ),
    );
  }
}
