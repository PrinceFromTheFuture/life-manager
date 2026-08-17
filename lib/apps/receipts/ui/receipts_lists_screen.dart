import 'package:flutter/material.dart';

import 'package:shopping_list/apps/receipts/ui/manage_lookups_screen.dart';
import 'package:shopping_list/core/design/theme.dart';
import 'package:shopping_list/core/design/tokens.dart';
import 'package:shopping_list/core/design/widgets/perforation.dart';

/// Categories and accounts — owned by Receipts, not by the hub.
///
/// These lists only mean something when logging an expense. Putting them next
/// to API keys on the account screen made them look like product settings,
/// which they are not.
class ReceiptsListsScreen extends StatelessWidget {
  const ReceiptsListsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;

    return Scaffold(
      backgroundColor: palette.paper,
      appBar: AppBar(title: const Text('Lists')),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.md),
            child: Text(
              'Used when you log an expense. Changing a name here updates the '
              'chips; past expenses keep whatever they were saved with.',
              style: Type.body.copyWith(color: palette.faded),
            ),
          ),
          const PerforatedRule(indent: Space.lg),
          _NavRow(
            label: 'Categories',
            subtitle: 'Groceries, fuel, eating out…',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    const ManageLookupsScreen(kind: LookupKind.category),
              ),
            ),
          ),
          const PerforatedRule(indent: Space.lg),
          _NavRow(
            label: 'Accounts',
            subtitle: 'Cards, cash, anything you pay with',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    const ManageLookupsScreen(kind: LookupKind.account),
              ),
            ),
          ),
          const PerforatedRule(indent: Space.lg),
        ],
      ),
    );
  }
}

class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Space.lg,
          vertical: Space.md + 2,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, style: Type.item.copyWith(color: palette.print)),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: Type.caption.copyWith(color: palette.faded),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: palette.faded),
          ],
        ),
      ),
    );
  }
}
