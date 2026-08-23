import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:shopping_list/apps/receipts/data/finance/calendar.dart';
import 'package:shopping_list/apps/receipts/data/models/recurring_rule.dart';
import 'package:shopping_list/apps/receipts/state/providers.dart';
import 'package:shopping_list/apps/receipts/ui/ledger_plate.dart';
import 'package:shopping_list/apps/receipts/ui/register_keypad.dart';
import 'package:shopping_list/apps/receipts/ui/widgets/day_grid.dart';
import 'package:shopping_list/apps/receipts/ui/widgets/sheet_parts.dart';
import 'package:shopping_list/core/design/paper_snack.dart';
import 'package:shopping_list/core/design/theme.dart';
import 'package:shopping_list/core/design/tokens.dart';
import 'package:shopping_list/core/design/widgets/perforation.dart';

/// Describing something that repeats.
///
/// The expense sheet's field vocabulary minus the camera, plus the two things
/// only a repeating charge has: which day it lands on, and when it stops. An
/// income rule swaps the category out for the account it arrives in, so a
/// salary is just a standing order pointing the other way.
class StandingSheet extends ConsumerStatefulWidget {
  const StandingSheet({super.key, this.existing});

  final RecurringRule? existing;

  static Future<void> open(BuildContext context, {RecurringRule? existing}) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => StandingSheet(existing: existing),
      ),
    );
  }

  @override
  ConsumerState<StandingSheet> createState() => _StandingSheetState();
}

class _StandingSheetState extends ConsumerState<StandingSheet> {
  final _nameController = TextEditingController();
  final _nameFocus = FocusNode();

  AmountEntry _amount = AmountEntry();
  RecurringKind _kind = RecurringKind.expense;
  int? _dayOfMonth;
  int? _categoryId;
  int? _paymentMethodId;
  int? _accountId;
  bool _isBusiness = false;
  DateTime _startsOn = Calendar.startOfDay(DateTime.now());
  DateTime? _endsOn;

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
      _startsOn = existing.startsOn;
      _endsOn = existing.endsOn;
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
    if (_amount.agorot == null) return 'How much, every month?';
    if (_dayOfMonth == null) return 'Which day of the month?';
    return null;
  }

  Future<void> _pickDate({required bool start}) async {
    final initial = start ? _startsOn : (_endsOn ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(DateTime.now().year + 20),
      useRootNavigator: false,
    );
    if (picked == null) return;
    setState(() {
      if (start) {
        _startsOn = Calendar.startOfDay(picked);
      } else {
        _endsOn = Calendar.startOfDay(picked);
      }
    });
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
            startsOn: _startsOn,
            endsOn: _endsOn,
            clearEndsOn: _endsOn == null,
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
            startsOn: _startsOn,
            endsOn: _endsOn,
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
          icon: const Icon(Icons.close),
          tooltip: 'Discard',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(_isEditing ? 'Edit standing order' : 'New standing order'),
        actions: [
          if (_isEditing)
            TextButton(
              onPressed: () async {
                final rule = widget.existing!;
                await ref.read(financeControllerProvider).setRuleActive(
                      rule.id!,
                      active: !rule.active,
                    );
                if (context.mounted) Navigator.of(context).pop();
              },
              child: Text(widget.existing!.active ? 'Pause' : 'Resume'),
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
                  label: 'WHICH DAY',
                  child: DayGrid(
                    selected: _dayOfMonth,
                    shortMonthNote: 'Short months run it on the last day.',
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
                SheetBlock(
                  label: 'RUNS',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _DateLine(
                        label: 'From',
                        value: DateFormat('d MMM yyyy').format(_startsOn),
                        onTap: () => _pickDate(start: true),
                      ),
                      const SizedBox(height: Space.sm),
                      _DateLine(
                        label: 'Until',
                        value: _endsOn == null
                            ? 'No end'
                            : DateFormat('d MMM yyyy').format(_endsOn!),
                        onTap: () => _pickDate(start: false),
                        onClear:
                            _endsOn == null ? null : () => setState(() => _endsOn = null),
                      ),
                    ],
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
              label: _isEditing ? 'Save changes' : 'Add standing order',
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

class _DateLine extends StatelessWidget {
  const _DateLine({
    required this.label,
    required this.value,
    required this.onTap,
    this.onClear,
  });

  final String label;
  final String value;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.xs),
        child: Row(
          children: [
            SizedBox(
              width: 56,
              child: Text(
                label,
                style: Type.caption.copyWith(color: palette.faded),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: Type.mono.copyWith(color: palette.print, fontSize: 15),
              ),
            ),
            if (onClear != null)
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                tooltip: 'Clear end date',
                onPressed: onClear,
              ),
          ],
        ),
      ),
    );
  }
}
