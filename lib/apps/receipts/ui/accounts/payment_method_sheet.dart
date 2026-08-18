import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shopping_list/apps/receipts/data/models/payment_method.dart';
import 'package:shopping_list/apps/receipts/state/providers.dart';
import 'package:shopping_list/apps/receipts/ui/ledger_plate.dart';
import 'package:shopping_list/apps/receipts/ui/register_keypad.dart';
import 'package:shopping_list/apps/receipts/ui/widgets/day_grid.dart';
import 'package:shopping_list/apps/receipts/ui/widgets/sheet_parts.dart';
import 'package:shopping_list/core/design/paper_snack.dart';
import 'package:shopping_list/core/design/theme.dart';
import 'package:shopping_list/core/design/tokens.dart';
import 'package:shopping_list/core/design/widgets/perforation.dart';

/// Describing a way of paying.
///
/// The one decision that matters is settlement — direct or credit — and it is
/// the only one presented as a choice rather than a field, because everything
/// below it depends on the answer. Pick direct and the sheet ends there; pick
/// credit and the two questions a card actually raises appear.
class PaymentMethodSheet extends ConsumerStatefulWidget {
  const PaymentMethodSheet({super.key, this.existing, this.accountId});

  final PaymentMethod? existing;

  /// Which account a new method hangs off. Ignored when editing.
  final int? accountId;

  static Future<void> open(
    BuildContext context, {
    PaymentMethod? existing,
    int? accountId,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => PaymentMethodSheet(
          existing: existing,
          accountId: accountId,
        ),
      ),
    );
  }

  @override
  ConsumerState<PaymentMethodSheet> createState() => _PaymentMethodSheetState();
}

class _PaymentMethodSheetState extends ConsumerState<PaymentMethodSheet> {
  final _nameController = TextEditingController();
  final _last4Controller = TextEditingController();
  final _nameFocus = FocusNode();

  AmountEntry _limit = AmountEntry();
  Settlement _settlement = Settlement.direct;
  int? _statementDay;
  int? _accountId;
  bool _keypadOpen = false;
  bool _saving = false;

  bool get _isEditing => widget.existing != null;
  bool get _isCredit => _settlement == Settlement.indirect;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _nameController.text = existing.name;
      _last4Controller.text = existing.last4 ?? '';
      _settlement = existing.settlement;
      _statementDay = existing.statementDay;
      _accountId = existing.accountId;
      if (existing.creditLimitMinor != null) {
        _limit = AmountEntry.fromAgorot(existing.creditLimitMinor!);
      }
    } else {
      _accountId = widget.accountId;
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _nameFocus.requestFocus());
    }
    _nameController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _last4Controller.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  bool get _canSave =>
      _nameController.text.trim().isNotEmpty && _accountId != null && !_saving;

  String? get _hint {
    if (_nameController.text.trim().isEmpty) return 'Give it a name';
    if (_accountId == null) return 'Choose the account it draws on';
    return null;
  }

  Future<void> _save() async {
    if (!_canSave) return;

    setState(() => _saving = true);
    final navigator = Navigator.of(context);
    final finance = ref.read(financeControllerProvider);

    final last4 = _last4Controller.text.trim();
    final existing = widget.existing;

    try {
      if (existing != null) {
        await finance.updatePaymentMethod(
          PaymentMethod(
            id: existing.id,
            accountId: _accountId!,
            name: _nameController.text.trim(),
            settlement: _settlement,
            statementDay: _isCredit ? _statementDay : null,
            creditLimitMinor: _isCredit ? _limit.agorot : null,
            last4: last4.isEmpty ? null : last4,
            sort: existing.sort,
            archivedAt: existing.archivedAt,
            createdAt: existing.createdAt,
          ),
        );
      } else {
        await finance.addPaymentMethod(
          PaymentMethod(
            accountId: _accountId!,
            name: _nameController.text.trim(),
            settlement: _settlement,
            statementDay: _isCredit ? _statementDay : null,
            creditLimitMinor: _isCredit ? _limit.agorot : null,
            last4: last4.isEmpty ? null : last4,
            createdAt: DateTime.now(),
          ),
        );
      }
      navigator.pop();
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showPaperSnack(context, message: "That didn't save. Try again. ($e)");
    }
  }

  Future<void> _archive() async {
    final method = widget.existing;
    if (method == null) return;

    final uses = await ref
        .read(expenseRepositoryProvider)
        .paymentMethodUsage(method.id!);
    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      useRootNavigator: false,
      builder: (context) => AlertDialog(
        backgroundColor: context.thermal.paper,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: const Text('Retire this method?'),
        content: Text(
          uses == 0
              ? 'It stops being offered when you record an expense.'
              : "It stops being offered. The $uses ${uses == 1 ? 'slip' : 'slips'} "
                  'already paid with it keep it.',
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

    if (confirmed != true || !mounted) return;
    await ref.read(financeControllerProvider).archivePaymentMethod(method.id!);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;
    final accounts = ref.watch(accountsProvider).valueOrNull ?? const [];

    return Scaffold(
      backgroundColor: palette.paper,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Discard',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(_isEditing ? 'Edit payment method' : 'New payment method'),
        actions: [
          if (_isEditing)
            IconButton(
              tooltip: 'Retire',
              icon: const Icon(Icons.archive_outlined),
              onPressed: _archive,
            ),
          const SizedBox(width: Space.sm),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding:
                  const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.lg),
              children: [
                const SizedBox(height: Space.md),
                SheetBlock(
                  label: 'NAME',
                  child: SheetField(
                    controller: _nameController,
                    focusNode: _nameFocus,
                    hintText: 'Visa gold, Bank transfer, …',
                    onTap: () => setState(() => _keypadOpen = false),
                  ),
                ),
                SheetBlock(
                  label: 'DRAWS ON',
                  child: Wrap(
                    spacing: Space.sm,
                    runSpacing: Space.sm,
                    children: [
                      for (final account in accounts)
                        SheetChip(
                          label: account.name,
                          selected: account.id == _accountId,
                          onTap: () => setState(() {
                            _accountId = account.id;
                            _keypadOpen = false;
                          }),
                        ),
                    ],
                  ),
                ),
                SheetBlock(
                  label: 'LAST 4',
                  child: SheetField(
                    controller: _last4Controller,
                    hintText: 'Optional — tells two cards apart',
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    onTap: () => setState(() => _keypadOpen = false),
                  ),
                ),
                Text(
                  'SETTLEMENT',
                  style: Type.eyebrow.copyWith(color: palette.faded),
                ),
                const SizedBox(height: Space.sm),
                Row(
                  children: [
                    LedgerPlate(
                      label: 'Direct',
                      selected: !_isCredit,
                      onTap: () => setState(() {
                        _settlement = Settlement.direct;
                        _keypadOpen = false;
                      }),
                    ),
                    const SizedBox(width: Space.sm),
                    LedgerPlate(
                      label: 'Credit',
                      selected: _isCredit,
                      onTap: () => setState(() {
                        _settlement = Settlement.indirect;
                        _keypadOpen = false;
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: Space.sm),
                Text(
                  _isCredit
                      ? 'Collects until the statement day, then leaves the '
                          'account in one go.'
                      : 'Leaves the account the moment you pay.',
                  style: Type.caption.copyWith(color: palette.faded),
                ),
                const SizedBox(height: Space.md),
                const PerforatedRule(),
                const SizedBox(height: Space.lg),
                if (_isCredit) ...[
                  SheetBlock(
                    label: 'STATEMENT DAY',
                    child: DayGrid(
                      selected: _statementDay,
                      shortMonthNote: 'Short months settle on the last day.',
                      onSelected: (day) => setState(() {
                        _statementDay = day;
                        _keypadOpen = false;
                      }),
                    ),
                  ),
                  Text(
                    'CREDIT LIMIT',
                    style: Type.eyebrow.copyWith(color: palette.faded),
                  ),
                  SheetAmountRow(
                    entry: _limit,
                    active: _keypadOpen,
                    onTap: () => setState(() => _keypadOpen = true),
                  ),
                  Text(
                    'Optional. With a limit set, the card shows how far through '
                    'it you are against how far through the month.',
                    style: Type.caption.copyWith(color: palette.faded),
                  ),
                  const SizedBox(height: Space.md),
                  const PerforatedRule(),
                ],
              ],
            ),
          ),
          if (_keypadOpen)
            RegisterKeypad(
              entry: _limit,
              onChanged: (next) => setState(() => _limit = next),
              onDone: () => setState(() => _keypadOpen = false),
            )
          else
            SheetSaveBar(
              label: _isEditing ? 'Save changes' : 'Add payment method',
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
