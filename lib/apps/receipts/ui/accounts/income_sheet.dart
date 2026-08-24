import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:shopping_list/apps/receipts/data/models/income.dart';
import 'package:shopping_list/apps/receipts/state/providers.dart';
import 'package:shopping_list/apps/receipts/ui/register_keypad.dart';
import 'package:shopping_list/apps/receipts/ui/widgets/sheet_parts.dart';
import 'package:shopping_list/core/design/paper_snack.dart';
import 'package:shopping_list/core/design/theme.dart';
import 'package:shopping_list/core/design/tokens.dart';
import 'package:shopping_list/core/design/widgets/perforation.dart';
import 'package:shopping_list/core/util/money.dart';
import 'package:shopping_list/core/design/widgets/app_icon.dart';

/// Recording money arriving.
///
/// The expense sheet with everything unnecessary taken out. A typical month has
/// a hundred expenses and one salary, so this is not a place to invest in
/// features — no photo, no category, no location, no business toggle. Four
/// facts and a keypad that is already open, because there is no camera to open
/// first.
class IncomeSheet extends ConsumerStatefulWidget {
  const IncomeSheet({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => const IncomeSheet(),
      ),
    );
  }

  @override
  ConsumerState<IncomeSheet> createState() => _IncomeSheetState();
}

class _IncomeSheetState extends ConsumerState<IncomeSheet> {
  final _sourceController = TextEditingController();

  AmountEntry _amount = AmountEntry();
  int? _accountId;
  DateTime _occurredAt = DateTime.now();
  bool _keypadOpen = true;
  bool _saving = false;
  List<String> _suggestions = const [];
  Timer? _suggestDebounce;

  @override
  void initState() {
    super.initState();
    _sourceController.addListener(_onSourceChanged);
    unawaited(_loadSuggestions(''));
    unawaited(_preselectAccount());
  }

  @override
  void dispose() {
    _suggestDebounce?.cancel();
    _sourceController.dispose();
    super.dispose();
  }

  /// One account is the overwhelmingly common case, so choosing it is not a
  /// decision worth asking for.
  Future<void> _preselectAccount() async {
    final accounts = await ref.read(accountsProvider.future);
    if (!mounted || accounts.length != 1) return;
    setState(() => _accountId = accounts.single.id);
  }

  void _onSourceChanged() {
    setState(() {});
    _suggestDebounce?.cancel();
    _suggestDebounce = Timer(
      const Duration(milliseconds: 250),
      () => _loadSuggestions(_sourceController.text.trim()),
    );
  }

  Future<void> _loadSuggestions(String query) async {
    final found = await ref
        .read(expenseRepositoryProvider)
        .incomeSourceSuggestions(query);
    if (!mounted) return;
    setState(() => _suggestions = found);
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
      _sourceController.text.trim().isNotEmpty &&
      !_saving;

  String? get _hint {
    if (_amount.agorot == null) return 'Enter what arrived';
    if (_sourceController.text.trim().isEmpty) return 'Who paid you?';
    return null;
  }

  Future<void> _save() async {
    final amount = _amount.agorot;
    if (amount == null) return;

    setState(() => _saving = true);
    final navigator = Navigator.of(context);

    try {
      await ref.read(financeControllerProvider).addIncome(
            Income(
              occurredAt: _occurredAt,
              amountMinor: amount,
              sourceName: _sourceController.text.trim(),
              accountId: _accountId,
              createdAt: DateTime.now(),
            ),
          );
      navigator.pop();
      if (!mounted) return;
      showPaperSnack(context, message: 'Recorded · +${Money.format(amount)}');
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showPaperSnack(context, message: "That didn't save. Try again. ($e)");
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;
    final accounts = ref.watch(accountsProvider).valueOrNull ?? const [];

    return Scaffold(
      backgroundColor: palette.paper,
      appBar: AppBar(
        leading: IconButton(
          icon: const AppIcon(SolarIcons.CloseCircle),
          tooltip: 'Discard',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Record income'),
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
                  sign: '+',
                  onTap: () => setState(() => _keypadOpen = true),
                ),
                const PerforatedRule(),
                const SizedBox(height: Space.lg),
                SheetBlock(
                  label: 'FROM',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SheetField(
                        controller: _sourceController,
                        hintText: 'Salary, tax return, …',
                        onTap: () => setState(() => _keypadOpen = false),
                      ),
                      if (_suggestions.isNotEmpty) ...[
                        const SizedBox(height: Space.sm),
                        Wrap(
                          spacing: Space.sm,
                          runSpacing: Space.sm,
                          children: [
                            for (final source in _suggestions)
                              SheetChip(
                                label: source,
                                selected:
                                    source == _sourceController.text.trim(),
                                onTap: () => setState(() {
                                  _sourceController.text = source;
                                  _keypadOpen = false;
                                }),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                if (accounts.isNotEmpty)
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
                  ),
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
              label: 'Record income',
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
