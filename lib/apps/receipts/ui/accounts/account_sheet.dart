import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shopping_list/apps/receipts/data/models/account.dart';
import 'package:shopping_list/apps/receipts/data/models/account_mark.dart';
import 'package:shopping_list/apps/receipts/state/providers.dart';
import 'package:shopping_list/apps/receipts/ui/register_keypad.dart';
import 'package:shopping_list/apps/receipts/ui/widgets/sheet_parts.dart';
import 'package:shopping_list/core/design/paper_snack.dart';
import 'package:shopping_list/core/design/theme.dart';
import 'package:shopping_list/core/design/tokens.dart';
import 'package:shopping_list/core/design/widgets/perforation.dart';

/// Setting up an account, or correcting what it started with.
///
/// The opening balance is the one field here that matters. Every balance the
/// app shows is derived from it, so an account added without one reads as
/// exactly what it is: what has moved since you started tracking, not what you
/// have.
class AccountSheet extends ConsumerStatefulWidget {
  const AccountSheet({super.key, this.existing});

  final Account? existing;

  static Future<void> open(BuildContext context, {Account? existing}) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => AccountSheet(existing: existing),
      ),
    );
  }

  @override
  ConsumerState<AccountSheet> createState() => _AccountSheetState();
}

class _AccountSheetState extends ConsumerState<AccountSheet> {
  static const _kinds = ['bank', 'cash', 'card', 'other'];

  final _nameController = TextEditingController();
  final _nameFocus = FocusNode();

  AmountEntry _opening = AmountEntry();
  String _kind = 'bank';
  String _mark = AccountMark.fallbackId;
  bool _keypadOpen = false;
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _nameController.text = existing.name;
      _kind = existing.kind;
      _mark = existing.mark;
      if (existing.openingMinor != 0) {
        _opening = AmountEntry.fromAgorot(existing.openingMinor);
      }
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

  bool get _canSave => _nameController.text.trim().isNotEmpty && !_saving;

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() => _saving = true);
    final navigator = Navigator.of(context);
    final finance = ref.read(financeControllerProvider);
    final opening = _opening.agorot ?? 0;

    try {
      final existing = widget.existing;
      if (existing != null) {
        await ref.read(lookupsControllerProvider).renameAccount(
              existing.id!,
              name,
            );
        await finance.setAccountMark(existing.id!, _mark);
        await finance.setOpeningBalance(existing.id!, opening);
      } else {
        final created =
            await finance.addAccount(name, kind: _kind, mark: _mark);
        if (opening != 0) {
          await finance.setOpeningBalance(created.id!, opening);
        }
      }
      navigator.pop();
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showPaperSnack(context, message: "That didn't save. Try again. ($e)");
    }
  }

  /// Retires rather than deletes.
  ///
  /// A closed account still owns everything that ever went through it, and a
  /// balance that silently loses six months of history is worse than one
  /// account too many in a list.
  Future<void> _retire() async {
    final account = widget.existing;
    if (account == null) return;

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

    if (confirmed != true || !mounted) return;
    await ref.read(financeControllerProvider).archiveAccount(account.id!);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;

    return Scaffold(
      backgroundColor: palette.paper,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Discard',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(_isEditing ? 'Edit account' : 'New account'),
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
                          label: _label(kind),
                          selected: kind == _kind,
                          onTap: () => setState(() {
                            _kind = kind;
                            if (!_isEditing) {
                              _mark = AccountMark.next(const [], kind: kind);
                            }
                            _keypadOpen = false;
                          }),
                        ),
                    ],
                  ),
                ),
                SheetBlock(
                  label: 'MARK',
                  child: Wrap(
                    spacing: Space.sm,
                    runSpacing: Space.sm,
                    children: [
                      for (final mark in AccountMark.all)
                        _MarkPad(
                          mark: mark,
                          selected: mark.id == _mark,
                          onTap: () => setState(() {
                            _mark = mark.id;
                            _keypadOpen = false;
                          }),
                        ),
                    ],
                  ),
                ),
                Text(
                  'OPENING BALANCE',
                  style: Type.eyebrow.copyWith(color: palette.faded),
                ),
                SheetAmountRow(
                  entry: _opening,
                  active: _keypadOpen,
                  onTap: () => setState(() => _keypadOpen = true),
                ),
                Text(
                  'What this account held the day you started tracking it. '
                  'Everything after it is worked out from your slips.',
                  style: Type.caption.copyWith(color: palette.faded),
                ),
                const SizedBox(height: Space.md),
                const PerforatedRule(),
                if (_isEditing) ...[
                  const SizedBox(height: Space.xl),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: _retire,
                      style: TextButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.error,
                      ),
                      child: const Text('Retire this account'),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (_keypadOpen)
            RegisterKeypad(
              entry: _opening,
              onChanged: (next) => setState(() => _opening = next),
              onDone: () => setState(() => _keypadOpen = false),
            )
          else
            SheetSaveBar(
              label: _isEditing ? 'Save changes' : 'Add account',
              enabled: _canSave,
              saving: _saving,
              hint: _canSave ? null : 'Give the account a name',
              onSave: _save,
            ),
        ],
      ),
    );
  }

  static String _label(String kind) => switch (kind) {
        'bank' => 'Bank',
        'cash' => 'Cash',
        'card' => 'Card',
        _ => 'Other',
      };
}

class _MarkPad extends StatelessWidget {
  const _MarkPad({
    required this.mark,
    required this.selected,
    required this.onTap,
  });

  final AccountMark mark;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;
    final ink = mark.ink.of(Theme.of(context).brightness);

    return Semantics(
      button: true,
      selected: selected,
      label: mark.label,
      child: Material(
        color: selected ? ink : palette.paperShade,
        shape: RoundedRectangleBorder(
          borderRadius: Radii.key,
          side: BorderSide(
            color: selected ? palette.print : Colors.transparent,
            width: 2,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: Radii.key,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(
              mark.icon,
              size: 20,
              color: selected ? palette.paper : palette.print,
            ),
          ),
        ),
      ),
    );
  }
}
