import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shopping_list/apps/receipts/state/providers.dart';
import 'package:shopping_list/core/design/theme.dart';
import 'package:shopping_list/core/design/tokens.dart';
import 'package:shopping_list/core/design/widgets/perforation.dart';

enum LookupKind { category, account }

/// One entry in either editable list — just enough to render and act on.
class _Row {
  const _Row({required this.id, required this.name, required this.sort});

  final int id;
  final String name;
  final int sort;
}

/// Add, rename, reorder and remove the categories or the accounts.
///
/// One screen for both lists rather than two near-identical ones: the two
/// differ only in which words they use and which provider they read, so a
/// single [LookupKind] parameter carries that difference and everything else
/// — the drag handle, the swipe, the rename dialog, the usage-aware delete
/// warning — is written once.
class ManageLookupsScreen extends ConsumerWidget {
  const ManageLookupsScreen({super.key, required this.kind});

  final LookupKind kind;

  String get _title =>
      kind == LookupKind.category ? 'Expense categories' : 'Accounts';

  String get _addHint =>
      kind == LookupKind.category ? 'New category name' : 'New account name';

  String get _emptyText =>
      kind == LookupKind.category ? 'No categories yet.' : 'No accounts yet.';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.thermal;
    final AsyncValue<List<_Row>> source = kind == LookupKind.category
        ? ref.watch(categoriesProvider).whenData(
              (items) => [
                for (final c in items)
                  _Row(id: c.id!, name: c.name, sort: c.sort),
              ],
            )
        : ref.watch(accountsProvider).whenData(
              (items) => [
                for (final a in items)
                  _Row(id: a.id!, name: a.name, sort: a.sort),
              ],
            );

    return Scaffold(
      backgroundColor: palette.paper,
      appBar: AppBar(title: Text(_title)),
      body: source.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('$e', style: Type.caption.copyWith(color: palette.faded)),
        ),
        data: (rows) => rows.isEmpty
            ? Center(
                child: Text(
                  _emptyText,
                  style: Type.body.copyWith(color: palette.faded),
                ),
              )
            : _ReorderableList(kind: kind, rows: rows),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding:
              const EdgeInsets.fromLTRB(Space.lg, Space.md, Space.lg, Space.md),
          child: _AddRow(kind: kind, hint: _addHint),
        ),
      ),
    );
  }
}

class _ReorderableList extends ConsumerWidget {
  const _ReorderableList({required this.kind, required this.rows});

  final LookupKind kind;
  final List<_Row> rows;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(lookupsControllerProvider);

    return ReorderableListView.builder(
      padding: const EdgeInsets.symmetric(vertical: Space.md),
      itemCount: rows.length,
      // onReorderItem's newIndex already accounts for the removed item at
      // oldIndex, unlike the deprecated onReorder — no manual adjustment.
      onReorderItem: (oldIndex, newIndex) {
        final ids = rows.map((r) => r.id).toList();
        final id = ids.removeAt(oldIndex);
        ids.insert(newIndex, id);
        if (kind == LookupKind.category) {
          controller.reorderCategories(ids);
        } else {
          controller.reorderAccounts(ids);
        }
      },
      itemBuilder: (context, index) {
        final row = rows[index];
        return Container(
          key: ValueKey('lookup-${row.id}'),
          color: context.thermal.paper,
          child: Column(
            children: [
              _LookupTile(kind: kind, row: row),
              const PerforatedRule(indent: Space.lg),
            ],
          ),
        );
      },
    );
  }
}

class _LookupTile extends ConsumerWidget {
  const _LookupTile({required this.kind, required this.row});

  final LookupKind kind;
  final _Row row;

  Future<void> _rename(BuildContext context, WidgetRef ref) async {
    final palette = context.thermal;
    final controller = TextEditingController(text: row.name);

    final name = await showDialog<String>(
      context: context,
      useRootNavigator: false,
      builder: (context) => AlertDialog(
        backgroundColor: palette.paper,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        titleTextStyle:
            Type.display.copyWith(fontSize: 20, color: palette.print),
        title: const Text('Rename'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          style: Type.item.copyWith(color: palette.print),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (name == null || name.isEmpty || name == row.name) return;
    final lookups = ref.read(lookupsControllerProvider);
    if (kind == LookupKind.category) {
      await lookups.renameCategory(row.id, name);
    } else {
      await lookups.renameAccount(row.id, name);
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final lookups = ref.read(lookupsControllerProvider);
    final usage = kind == LookupKind.category
        ? await lookups.categoryUsage(row.id)
        : await lookups.accountUsage(row.id);

    if (!context.mounted) return;
    final palette = context.thermal;
    final noun = kind == LookupKind.category ? 'category' : 'account';

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
        title: Text('Delete "${row.name}"?'),
        content: Text(
          usage == 0
              ? 'Nothing uses this $noun yet.'
              : '$usage ${usage == 1 ? 'expense' : 'expenses'} '
                  '${usage == 1 ? 'uses' : 'use'} this $noun. '
                  "They keep their record; they'll just show no $noun.",
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

    if (confirmed ?? false) {
      if (kind == LookupKind.category) {
        await lookups.deleteCategory(row.id);
      } else {
        await lookups.deleteAccount(row.id);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.thermal;

    return Padding(
      padding:
          const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.sm),
      child: Row(
        children: [
          Icon(Icons.drag_indicator, size: 18, color: palette.faded),
          const SizedBox(width: Space.md),
          Expanded(
            child: InkWell(
              onTap: () => _rename(context, ref),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: Space.xs),
                child: Text(
                  row.name,
                  style: Type.item.copyWith(color: palette.print),
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            color: palette.faded,
            tooltip: 'Delete',
            onPressed: () => _delete(context, ref),
          ),
        ],
      ),
    );
  }
}

class _AddRow extends ConsumerStatefulWidget {
  const _AddRow({required this.kind, required this.hint});

  final LookupKind kind;
  final String hint;

  @override
  ConsumerState<_AddRow> createState() => _AddRowState();
}

class _AddRowState extends ConsumerState<_AddRow> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    final lookups = ref.read(lookupsControllerProvider);
    if (widget.kind == LookupKind.category) {
      await lookups.addCategory(name);
    } else {
      await lookups.addAccount(name);
    }
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            textCapitalization: TextCapitalization.words,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(hintText: widget.hint),
          ),
        ),
        const SizedBox(width: Space.sm),
        FilledButton(onPressed: _submit, child: const Text('Add')),
      ],
    );
  }
}
