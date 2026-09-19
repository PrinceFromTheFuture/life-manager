import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:shopping_list/apps/receipts/state/providers.dart';
import 'package:shopping_list/apps/receipts/ui/register_keypad.dart';
import 'package:shopping_list/apps/receipts/ui/widgets/sheet_parts.dart';
import 'package:shopping_list/core/design/paper_snack.dart';
import 'package:shopping_list/core/design/theme.dart';
import 'package:shopping_list/core/design/tokens.dart';
import 'package:shopping_list/core/design/widgets/perforation.dart';
import 'package:shopping_list/core/util/money.dart';
import 'package:shopping_list/core/design/widgets/app_icon.dart';

/// Moving money from one account to another.
///
/// Not income and not an expense — both sides of the move are written together
/// so the money cannot vanish from one place without arriving in the other.
class TransferSheet extends ConsumerStatefulWidget {
  const TransferSheet({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => const TransferSheet(),
      ),
    );
  }

  @override
  ConsumerState<TransferSheet> createState() => _TransferSheetState();
}

class _TransferSheetState extends ConsumerState<TransferSheet> {
  final _noteController = TextEditingController();

  AmountEntry _amount = AmountEntry();
  int? _fromId;
  int? _toId;
  DateTime _occurredAt = DateTime.now();
  bool _keypadOpen = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _noteController.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) => _preselect());
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _preselect() async {
    final accounts = await ref.read(accountsProvider.future);
    final live = accounts.where((a) => a.archivedAt == null).toList();
    if (!mounted || live.length < 2) return;
    setState(() {
      _fromId = live.first.id;
      _toId = live[1].id;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _occurredAt,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      useRootNavigator: false,
    );
    if (picked == null) return;
    setState(() {
      _occurredAt = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _occurredAt.hour,
        _occurredAt.minute,
      );
    });
  }

  bool get _canSave =>
      _amount.agorot != null &&
      _fromId != null &&
      _toId != null &&
      _fromId != _toId &&
      !_saving;

  String? get _hint {
    if (_amount.agorot == null) return 'How much is moving?';
    if (_fromId == null) return 'Where from?';
    if (_toId == null) return 'Where to?';
    if (_fromId == _toId) return 'Pick two different accounts';
    return null;
  }

  Future<void> _save() async {
    final amount = _amount.agorot;
    final fromId = _fromId;
    final toId = _toId;
    if (amount == null || fromId == null || toId == null) return;

    setState(() => _saving = true);
    final navigator = Navigator.of(context);

    try {
      await ref.read(financeControllerProvider).transfer(
            fromAccountId: fromId,
            toAccountId: toId,
            amountMinor: amount,
            occurredAt: _occurredAt,
            note: _noteController.text.trim().isEmpty
                ? null
                : _noteController.text.trim(),
          );
      navigator.pop();
      if (!mounted) return;
      showPaperSnack(context, message: 'Moved · ${Money.format(amount)}');
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showPaperSnack(context, message: "That didn't save. Try again. ($e)");
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;
    final accounts = (ref.watch(accountsProvider).valueOrNull ?? const [])
        .where((a) => a.archivedAt == null)
        .toList();

    return Scaffold(
      backgroundColor: palette.paper,
      appBar: AppBar(
        leading: IconButton(
          icon: const AppIcon(SolarIcons.CloseCircle),
          tooltip: 'Discard',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Record transfer'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding:
                  const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.lg),
              children: [
                SheetAmountRow(
                  entry: _amount,
                  active: _keypadOpen,
                  onTap: () => setState(() => _keypadOpen = true),
                ),
                const PerforatedRule(),
                const SizedBox(height: Space.lg),
                if (accounts.length < 2)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Space.lg),
                    child: Text(
                      'A transfer needs two accounts. Add another first.',
                      style: Type.body.copyWith(color: palette.faded),
                    ),
                  )
                else ...[
                  SheetBlock(
                    label: 'FROM',
                    child: Wrap(
                      spacing: Space.sm,
                      runSpacing: Space.sm,
                      children: [
                        for (final account in accounts)
                          SheetChip(
                            label: account.name,
                            selected: account.id == _fromId,
                            onTap: () => setState(() {
                              _fromId = account.id;
                              if (_toId == _fromId) _toId = null;
                              _keypadOpen = false;
                            }),
                          ),
                      ],
                    ),
                  ),
                  SheetBlock(
                    label: 'TO',
                    child: Wrap(
                      spacing: Space.sm,
                      runSpacing: Space.sm,
                      children: [
                        for (final account in accounts)
                          if (account.id != _fromId)
                            SheetChip(
                              label: account.name,
                              selected: account.id == _toId,
                              onTap: () => setState(() {
                                _toId = account.id;
                                _keypadOpen = false;
                              }),
                            ),
                      ],
                    ),
                  ),
                ],
                SheetBlock(
                  label: 'WHEN',
                  child: InkWell(
                    onTap: _pickDate,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: Space.xs),
                      child: Text(
                        DateFormat('d MMM yyyy').format(_occurredAt),
                        style: Type.mono.copyWith(
                          color: palette.print,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ),
                SheetBlock(
                  label: 'NOTE',
                  child: SheetField(
                    controller: _noteController,
                    hintText: 'Optional',
                    onTap: () => setState(() => _keypadOpen = false),
                  ),
                ),
              ],
            ),
          ),
          if (_keypadOpen)
            RegisterKeypad(
              entry: _amount,
              onChanged: (next) => setState(() => _amount = next),
              onDone: () => setState(() => _keypadOpen = false),
            )
          else
            SheetSaveBar(
              label: 'Move money',
              enabled: _canSave,
              saving: _saving,
              hint: _hint,
              onSave: _save,
            ),
        ],
      ),
    );
  }
}
