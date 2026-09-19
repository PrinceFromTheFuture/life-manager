import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shopping_list/apps/receipts/data/expense_repository.dart';
import 'package:shopping_list/apps/receipts/data/models/account.dart';
import 'package:shopping_list/apps/receipts/data/models/account_view.dart';
import 'package:shopping_list/apps/receipts/state/providers.dart';
import 'package:shopping_list/core/design/theme.dart';
import 'package:shopping_list/core/design/tokens.dart';
import 'package:shopping_list/core/design/widgets/app_icon.dart';
import 'package:shopping_list/core/design/widgets/inset_drawer.dart';
import 'package:shopping_list/core/design/widgets/perforation.dart';
import 'package:shopping_list/core/util/money.dart';

/// Pick a view, or make one. The page remembers whichever was used last.
Future<void> openAccountViewsDrawer(BuildContext context) {
  final editing = ValueNotifier<AccountView?>(null);
  return showInsetDrawer<void>(
    context: context,
    primary: (_) => _ViewsList(
      onEdit: (view, scope) {
        editing.value = view;
        scope.open('edit');
      },
    ),
    views: {
      'edit': (_) => ValueListenableBuilder<AccountView?>(
            valueListenable: editing,
            builder: (context, view, _) => _ViewEditor(
              initial: view ?? const AccountView(name: ''),
            ),
          ),
    },
  ).whenComplete(editing.dispose);
}

class _ViewsList extends ConsumerWidget {
  const _ViewsList({required this.onEdit});

  final void Function(AccountView view, DrawerScope scope) onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.thermal;
    final scope = DrawerScope.of(context);
    final views = ref.watch(accountViewsProvider).valueOrNull ?? const [];
    final activeId = ref.watch(activeAccountViewIdProvider).valueOrNull;
    final standings = ref.watch(accountStandingsProvider).valueOrNull ?? const [];
    final finance = ref.read(financeControllerProvider);

    int sumOf(AccountView? view) => standingsInView(
          standings,
          view,
          forHeadline: true,
        ).fold<int>(0, (sum, s) => sum + s.balanceMinor);

    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.lg, Space.sm, Space.lg, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Views',
            style: Type.display.copyWith(fontSize: 22, color: palette.print),
          ),
          const SizedBox(height: Space.xs),
          Text(
            'A view is a group of accounts. What you can spend is not the '
            'same as what you own.',
            style: Type.caption.copyWith(color: palette.faded),
          ),
          const SizedBox(height: Space.lg),
          _ViewRow(
            name: AccountView.allLabel,
            amountMinor: sumOf(null),
            selected: activeId == null,
            onSelect: () async {
              await finance.selectAccountView(null);
              if (context.mounted) scope.close();
            },
          ),
          const PerforatedRule(),
          for (final view in views) ...[
            _ViewRow(
              name: view.name,
              amountMinor: sumOf(view),
              selected: view.id == activeId,
              onSelect: () async {
                await finance.selectAccountView(view.id);
                if (context.mounted) scope.close();
              },
              onEdit: () => onEdit(view, scope),
            ),
            const PerforatedRule(),
          ],
          const SizedBox(height: Space.md),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => onEdit(const AccountView(name: ''), scope),
              child: const Text('New view'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ViewRow extends StatelessWidget {
  const _ViewRow({
    required this.name,
    required this.amountMinor,
    required this.selected,
    required this.onSelect,
    this.onEdit,
  });

  final String name;
  final int amountMinor;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;

    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onSelect();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.md),
        child: Row(
          children: [
            SizedBox(
              width: 26,
              child: selected
                  ? AppIcon(
                      SolarIcons.CheckCircle,
                      size: 18,
                      color: palette.print,
                    )
                  : null,
            ),
            Expanded(
              child: Text(
                name,
                style: Type.item.copyWith(color: palette.print),
              ),
            ),
            Text(
              Money.format(amountMinor),
              style: Type.monoBold.copyWith(color: palette.faded, fontSize: 13),
            ),
            if (onEdit != null)
              IconButton(
                tooltip: 'Edit $name',
                visualDensity: VisualDensity.compact,
                icon: AppIcon(
                  SolarIcons.AltArrowRight,
                  size: 18,
                  color: palette.faded,
                ),
                onPressed: onEdit,
              ),
          ],
        ),
      ),
    );
  }
}

class _ViewEditor extends ConsumerStatefulWidget {
  const _ViewEditor({required this.initial});

  final AccountView initial;

  @override
  ConsumerState<_ViewEditor> createState() => _ViewEditorState();
}

class _ViewEditorState extends ConsumerState<_ViewEditor> {
  late final TextEditingController _name =
      TextEditingController(text: widget.initial.name);
  late final Set<int> _ids = {...widget.initial.accountIds};
  bool _saving = false;

  bool get _isNew => widget.initial.id == null;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool get _canSave =>
      _name.text.trim().isNotEmpty && _ids.isNotEmpty && !_saving;

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _saving = true);
    await ref.read(financeControllerProvider).saveAccountView(
          widget.initial.copyWith(
            name: _name.text.trim(),
            accountIds: _ids.toList(),
          ),
        );
    if (mounted) DrawerScope.of(context).back();
  }

  Future<void> _delete() async {
    final id = widget.initial.id;
    if (id == null) return;
    final palette = context.thermal;
    final confirmed = await showDialog<bool>(
      context: context,
      useRootNavigator: false,
      builder: (context) => AlertDialog(
        backgroundColor: palette.paper,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        titleTextStyle:
            Type.display.copyWith(fontSize: 20, color: palette.print),
        contentTextStyle: Type.body.copyWith(color: palette.print),
        title: const Text('Delete this view?'),
        content: const Text(
          'The accounts stay. Only the grouping goes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref.read(financeControllerProvider).deleteAccountView(id);
    if (mounted) DrawerScope.of(context).back();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;
    final accounts = (ref.watch(accountsProvider).valueOrNull ?? const [])
        .where((a) => a.archivedAt == null)
        .toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DrawerViewHeader(title: _isNew ? 'New view' : 'Edit view'),
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, 0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Name it for what the number means.',
                style: Type.caption.copyWith(color: palette.faded),
              ),
              const SizedBox(height: Space.md),
              TextField(
                controller: _name,
                textCapitalization: TextCapitalization.sentences,
                style: Type.item.copyWith(color: palette.print),
                cursorColor: palette.carbon,
                decoration: InputDecoration(
                  hintText: 'To spend',
                  filled: false,
                  contentPadding: EdgeInsets.zero,
                  border: InputBorder.none,
                  hintStyle: Type.item.copyWith(color: palette.faded),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: Space.sm),
              const PerforatedRule(),
              const SizedBox(height: Space.lg),
              Text(
                'ACCOUNTS',
                style: Type.eyebrow.copyWith(color: palette.faded),
              ),
              const SizedBox(height: Space.sm),
              for (final account in accounts) ...[
                _AccountToggle(
                  account: account,
                  selected: _ids.contains(account.id),
                  onTap: () => setState(() {
                    final id = account.id!;
                    if (!_ids.remove(id)) _ids.add(id);
                  }),
                ),
                if (account != accounts.last) const PerforatedRule(),
              ],
              const SizedBox(height: Space.md),
              FilledButton(
                onPressed: _canSave ? _save : null,
                child: Text(_saving ? 'Saving…' : 'Save'),
              ),
              if (!_isNew)
                TextButton(
                  onPressed: _delete,
                  child: const Text('Delete view'),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AccountToggle extends StatelessWidget {
  const _AccountToggle({
    required this.account,
    required this.selected,
    required this.onTap,
  });

  final Account account;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;
    final brightness = Theme.of(context).brightness;
    final mark = account.stamp;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.md),
        child: Row(
          children: [
            AppIcon(
              mark.icon,
              size: 20,
              color: mark.ink.of(brightness),
            ),
            const SizedBox(width: Space.md),
            Expanded(
              child: Text(
                account.name,
                style: Type.item.copyWith(color: palette.print),
              ),
            ),
            AppIcon(
              selected ? SolarIcons.CheckCircle : SolarIcons.AddCircle,
              size: 20,
              color: selected ? palette.print : palette.faded,
            ),
          ],
        ),
      ),
    );
  }
}
