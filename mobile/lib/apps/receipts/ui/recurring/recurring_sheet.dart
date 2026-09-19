import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shopping_list/apps/receipts/data/models/recurring_rule.dart';
import 'package:shopping_list/apps/receipts/data/finance/calendar.dart';
import 'package:shopping_list/apps/receipts/state/providers.dart';
import 'package:shopping_list/apps/receipts/ui/ledger_plate.dart';
import 'package:shopping_list/apps/receipts/ui/register_keypad.dart';
import 'package:shopping_list/apps/receipts/ui/widgets/day_grid.dart';
import 'package:shopping_list/apps/receipts/ui/widgets/sheet_parts.dart';
import 'package:shopping_list/core/design/paper_snack.dart';
import 'package:shopping_list/core/design/theme.dart';
import 'package:shopping_list/core/design/tokens.dart';
import 'package:shopping_list/core/design/widgets/perforation.dart';
import 'package:shopping_list/core/design/widgets/app_icon.dart';

/// Editing a recurring payment. The day is when you usually pay it — a note
/// to yourself, not a trigger. Nothing here writes a slip.
class RecurringSheet extends ConsumerStatefulWidget {
  const RecurringSheet({super.key, this.existing});

  final RecurringRule? existing;

  static Future<void> open(BuildContext context, {RecurringRule? existing}) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => RecurringSheet(existing: existing),
      ),
    );
  }

  @override
  ConsumerState<RecurringSheet> createState() => _RecurringSheetState();
}

class _RecurringSheetState extends ConsumerState<RecurringSheet> {
  final _nameController = TextEditingController();
  final _nameFocus = FocusNode();

  AmountEntry _amount = AmountEntry();
  RecurringKind _kind = RecurringKind.expense;
  int? _dayOfMonth;
  int? _categoryId;
  int? _paymentMethodId;
  int? _accountId;
  bool _isBusiness = false;

  bool _keypadOpen = false;
  bool _saving = false;

  bool get _isEditing => widget.existing != null;
  bool get _isIncome => _kind == RecurringKind.income;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _nameController.text = existing.name;
      _amount = AmountEntry.fromAgorot(existing.amountMinor);
      _kind = existing.kind;
      _dayOfMonth = existing.dayOfMonth;
      _categoryId = existing.categoryId;
      _paymentMethodId = existing.paymentMethodId;
      _accountId = existing.accountId;
      _isBusiness = existing.isBusiness;
    } else {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _nameFocus.requestFocus());
    }
    _nameController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  bool get _canSave =>
      _amount.agorot != null &&
      _nameController.text.trim().isNotEmpty &&
      _dayOfMonth != null &&
      !_saving;

  String? get _hint {
    if (_nameController.text.trim().isEmpty) return 'What is it?';
    if (_amount.agorot == null) return 'How much, usually?';
    if (_dayOfMonth == null) return 'Which day do you usually pay?';
    return null;
  }

  Future<void> _save() async {
    final amount = _amount.agorot;
    if (amount == null || _dayOfMonth == null) return;

    setState(() => _saving = true);
    final navigator = Navigator.of(context);
    final finance = ref.read(financeControllerProvider);
    final existing = widget.existing;

    try {
      if (existing != null) {
        await finance.updateRule(
          existing.copyWith(
            kind: _kind,
            name: _nameController.text.trim(),
            amountMinor: amount,
            categoryId: _isIncome ? null : _categoryId,
            paymentMethodId: _isIncome ? null : _paymentMethodId,
            accountId: _isIncome ? _accountId : null,
            dayOfMonth: _dayOfMonth,
            isBusiness: _isBusiness,
          ),
        );
      } else {
        await finance.addRule(
          RecurringRule(
            kind: _kind,
            name: _nameController.text.trim(),
            amountMinor: amount,
            categoryId: _isIncome ? null : _categoryId,
            paymentMethodId: _isIncome ? null : _paymentMethodId,
            accountId: _isIncome ? _accountId : null,
            dayOfMonth: _dayOfMonth!,
            isBusiness: _isBusiness,
            startsOn: Calendar.startOfDay(DateTime.now()),
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

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;
    final categories = ref.watch(categoriesProvider).valueOrNull ?? const [];
    final methods = ref.watch(paymentMethodsProvider).valueOrNull ?? const [];
    final accounts = ref.watch(accountsProvider).valueOrNull ?? const [];

    return Scaffold(
      backgroundColor: palette.paper,
      appBar: AppBar(
        leading: IconButton(
          icon: const AppIcon(SolarIcons.CloseCircle),
          tooltip: 'Discard',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(_isEditing ? 'Edit recurring' : 'New recurring'),
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
                  sign: _isIncome ? '+' : null,
                  onTap: () => setState(() => _keypadOpen = true),
                ),
                const PerforatedRule(),
                const SizedBox(height: Space.lg),
                SheetBlock(
                  label: 'WHAT',
                  child: SheetField(
                    controller: _nameController,
                    focusNode: _nameFocus,
                    hintText: 'Rent, gym, insurance, …',
                    onTap: () => setState(() => _keypadOpen = false),
                  ),
                ),
                SheetBlock(
                  label: 'DIRECTION',
                  child: Row(
                    children: [
                      LedgerPlate(
                        label: 'Goes out',
                        selected: !_isIncome,
                        onTap: () => setState(() {
                          _kind = RecurringKind.expense;
                          _keypadOpen = false;
                        }),
                      ),
                      const SizedBox(width: Space.sm),
                      LedgerPlate(
                        label: 'Comes in',
                        selected: _isIncome,
                        onTap: () => setState(() {
                          _kind = RecurringKind.income;
                          _keypadOpen = false;
                        }),
                      ),
                    ],
                  ),
                ),
                SheetBlock(
                  label: 'USUALLY ON',
                  child: DayGrid(
                    selected: _dayOfMonth,
                    shortMonthNote: 'A note to yourself. Short months keep the last day.',
                    onSelected: (day) => setState(() {
                      _dayOfMonth = day;
                      _keypadOpen = false;
                    }),
                  ),
                ),
                if (_isIncome)
                  SheetBlock(
                    label: 'LANDS IN',
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
                  )
                else ...[
                  SheetBlock(
                    label: 'WHAT KIND',
                    child: Wrap(
                      spacing: Space.sm,
                      runSpacing: Space.sm,
                      children: [
                        for (final category in categories)
                          SheetChip(
                            label: category.name,
                            selected: category.id == _categoryId,
                            ink: category.stamp,
                            onTap: () => setState(() {
                              _categoryId = category.id;
                              _keypadOpen = false;
                            }),
                          ),
                      ],
                    ),
                  ),
                  SheetBlock(
                    label: 'PAID WITH',
                    child: Wrap(
                      spacing: Space.sm,
                      runSpacing: Space.sm,
                      children: [
                        for (final method in methods)
                          SheetChip(
                            label: method.label,
                            selected: method.id == _paymentMethodId,
                            onTap: () => setState(() {
                              _paymentMethodId = method.id;
                              _keypadOpen = false;
                            }),
                          ),
                      ],
                    ),
                  ),
                  SheetBlock(
                    label: 'FOR',
                    child: InkWell(
                      onTap: () => setState(() {
                        _isBusiness = !_isBusiness;
                        _keypadOpen = false;
                      }),
                      child: Padding(
                        padding:
                            const EdgeInsets.symmetric(vertical: Space.xs),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Business expense',
                                style: Type.item.copyWith(color: palette.print),
                              ),
                            ),
                            Switch(
                              value: _isBusiness,
                              onChanged: (value) => setState(() {
                                _isBusiness = value;
                                _keypadOpen = false;
                              }),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
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
              label: _isEditing ? 'Save changes' : 'Add recurring',
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
