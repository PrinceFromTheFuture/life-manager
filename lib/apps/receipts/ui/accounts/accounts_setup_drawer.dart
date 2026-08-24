import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shopping_list/apps/receipts/data/models/account.dart';
import 'package:shopping_list/apps/receipts/state/providers.dart';
import 'package:shopping_list/apps/receipts/ui/accounts/payment_method_sheet.dart';
import 'package:shopping_list/apps/receipts/ui/register_keypad.dart';
import 'package:shopping_list/apps/receipts/ui/widgets/sheet_parts.dart';
import 'package:shopping_list/core/design/paper_snack.dart';
import 'package:shopping_list/core/design/theme.dart';
import 'package:shopping_list/core/design/tokens.dart';
import 'package:shopping_list/core/design/widgets/inset_drawer.dart';
import 'package:shopping_list/core/design/widgets/perforation.dart';
import 'package:shopping_list/core/design/widgets/app_icon.dart';

/// The two setup actions that almost never happen, so they do not live on the
/// accounts page itself.
Future<void> openAddAccountDrawer(BuildContext context) {
  return showInsetDrawer<void>(
    context: context,
    primary: (_) => const _AddAccountDrawer(),
  );
}

Future<void> openAddPaymentMethodDrawer(BuildContext context) async {
  final accountId = await showInsetDrawer<int>(
    context: context,
    primary: (_) => const _PickAccountDrawer(),
  );
  if (accountId == null || !context.mounted) return;
  await PaymentMethodSheet.open(context, accountId: accountId);
}

class _AddAccountDrawer extends ConsumerStatefulWidget {
  const _AddAccountDrawer();

  @override
  ConsumerState<_AddAccountDrawer> createState() => _AddAccountDrawerState();
}

class _AddAccountDrawerState extends ConsumerState<_AddAccountDrawer> {
  static const _kinds = ['bank', 'cash', 'card', 'other'];

  final _name = TextEditingController();
  AmountEntry _opening = AmountEntry();
  String _kind = 'bank';
  bool _keypadOpen = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool get _canSave => _name.text.trim().isNotEmpty && !_saving;

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    try {
      final created =
          await ref.read(financeControllerProvider).addAccount(name, kind: _kind);
      final opening = _opening.agorot ?? 0;
      if (opening != 0) {
        await ref
            .read(financeControllerProvider)
            .setOpeningBalance(created.id!, opening);
      }
      if (mounted) Navigator.of(context).pop();
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showPaperSnack(context, message: "That didn't save. Try again. ($e)");
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;

    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.lg, Space.sm, Space.lg, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'New account',
            style: Type.display.copyWith(fontSize: 22, color: palette.print),
          ),
          const SizedBox(height: Space.xs),
          Text(
            'Where the money actually sits. Ways of paying hang off it later.',
            style: Type.caption.copyWith(color: palette.faded),
          ),
          const SizedBox(height: Space.lg),
          SheetBlock(
            label: 'NAME',
            child: SheetField(
              controller: _name,
              hintText: 'Bank Leumi, Cash, …',
              onTap: () => setState(() => _keypadOpen = false),
            ),
          ),
          SheetBlock(
            label: 'KIND',
            child: Wrap(
              spacing: Space.sm,
              runSpacing: Space.sm,
              children: [
                for (final kind in _kinds)
                  SheetChip(
                    label: switch (kind) {
                      'bank' => 'Bank',
                      'cash' => 'Cash',
                      'card' => 'Card',
                      _ => 'Other',
                    },
                    selected: kind == _kind,
                    onTap: () => setState(() {
                      _kind = kind;
                      _keypadOpen = false;
                    }),
                  ),
              ],
            ),
          ),
          Text('OPENING BALANCE',
              style: Type.eyebrow.copyWith(color: palette.faded)),
          SheetAmountRow(
            entry: _opening,
            active: _keypadOpen,
            onTap: () => setState(() => _keypadOpen = true),
          ),
          const SizedBox(height: Space.sm),
          if (_keypadOpen)
            RegisterKeypad(
              entry: _opening,
              onChanged: (next) => setState(() => _opening = next),
              onDone: () => setState(() => _keypadOpen = false),
            )
          else ...[
            if (!_canSave)
              Padding(
                padding: const EdgeInsets.only(bottom: Space.sm),
                child: Text(
                  'Give the account a name',
                  style: Type.caption.copyWith(color: palette.faded),
                ),
              ),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _canSave ? _save : null,
                child: Text(_saving ? 'Saving…' : 'Add account'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Pick which account a new payment method will draw on, then hand off to
/// the existing editor. The editor is a full sheet because a credit card
/// still has a day grid and a limit keypad.
class _PickAccountDrawer extends ConsumerWidget {
  const _PickAccountDrawer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.thermal;
    final accounts = (ref.watch(accountsProvider).valueOrNull ?? const [])
        .where((a) => a.archivedAt == null)
        .toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.lg, Space.sm, Space.lg, Space.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'New payment method',
            style: Type.display.copyWith(fontSize: 22, color: palette.print),
          ),
          const SizedBox(height: Space.xs),
          Text(
            'A way of reaching an account. Not an account itself.',
            style: Type.caption.copyWith(color: palette.faded),
          ),
          const SizedBox(height: Space.lg),
          Text('DRAWS ON', style: Type.eyebrow.copyWith(color: palette.faded)),
          const SizedBox(height: Space.sm),
          if (accounts.isEmpty)
            Text(
              'Add an account first. A card has to hang off something.',
              style: Type.body.copyWith(color: palette.faded),
            )
          else
            for (final account in accounts) ...[
              _AccountPick(account: account),
              if (account != accounts.last) const PerforatedRule(),
            ],
        ],
      ),
    );
  }
}

class _AccountPick extends StatelessWidget {
  const _AccountPick({required this.account});

  final Account account;

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;

    return InkWell(
      onTap: () => Navigator.of(context).pop(account.id!),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.md),
        child: Row(
          children: [
            Expanded(
              child: Text(
                account.name,
                style: Type.item.copyWith(color: palette.print),
              ),
            ),
            AppIcon(SolarIcons.AltArrowRight, color: palette.faded, size: 20),
          ],
        ),
      ),
    );
  }
}
