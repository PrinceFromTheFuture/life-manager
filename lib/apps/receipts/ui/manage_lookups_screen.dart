import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shopping_list/apps/receipts/data/models/expense_category.dart';
import 'package:shopping_list/apps/receipts/state/providers.dart';
import 'package:shopping_list/core/design/theme.dart';
import 'package:shopping_list/core/design/tokens.dart';
import 'package:shopping_list/core/design/widgets/perforation.dart';

/// Add, rename, reorder and remove the expense categories.
///
/// This screen used to serve accounts too. Accounts outgrew a name and a sort
/// order — they carry a balance, a ledger and the methods you pay from them —
/// so they moved to their own section, and this one went back to doing the one
/// thing a flat list of names needs.
class ManageLookupsScreen extends ConsumerWidget {
  const ManageLookupsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.thermal;

    return Scaffold(
      backgroundColor: palette.paper,
      appBar: AppBar(title: const Text('Expense categories')),
      body: ref.watch(categoriesProvider).when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Text(
                '$e',
                style: Type.caption.copyWith(color: palette.faded),
              ),
            ),
            data: (rows) => rows.isEmpty
                ? Center(
                    child: Text(
                      'No categories yet.',
                      style: Type.body.copyWith(color: palette.faded),
                    ),
                  )
                : _ReorderableList(rows: rows),
          ),
      bottomNavigationBar: const SafeArea(
        child: Padding(
          padding:
              EdgeInsets.fromLTRB(Space.lg, Space.md, Space.lg, Space.md),
          child: _AddRow(),
        ),
      ),
    );
  }
}

class _ReorderableList extends ConsumerWidget {
  const _ReorderableList({required this.rows});

  final List<ExpenseCategory> rows;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(lookupsControllerProvider);

    return ReorderableListView.builder(
      padding: const EdgeInsets.symmetric(vertical: Space.md),
      itemCount: rows.length,
      onReorder: (oldIndex, newIndex) {
        if (newIndex > oldIndex) newIndex -= 1;
        final ids = rows.map((r) => r.id!).toList();
        final id = ids.removeAt(oldIndex);
        ids.insert(newIndex, id);
        controller.reorderCategories(ids);
      },
      itemBuilder: (context, index) {
        final row = rows[index];
        return Container(
          key: ValueKey('lookup-${row.id}'),
          color: context.thermal.paper,
          child: Column(
            children: [
              _LookupTile(row: row),
              const PerforatedRule(indent: Space.lg),
            ],
          ),
        );
      },
    );
  }
}

class _LookupTile extends ConsumerWidget {
  const _LookupTile({required this.row});

  final ExpenseCategory row;

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
    await ref.read(lookupsControllerProvider).renameCategory(row.id!, name);
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final lookups = ref.read(lookupsControllerProvider);
    final usage = await lookups.categoryUsage(row.id!);

    if (!context.mounted) return;
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
        title: Text('Delete "${row.name}"?'),
        content: Text(
          usage == 0
              ? 'Nothing uses this category yet.'
              : '$usage ${usage == 1 ? 'expense' : 'expenses'} '
                  '${usage == 1 ? 'uses' : 'use'} this category. '
                  "They keep their record; they'll just show no category.",
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

    if (confirmed ?? false) await lookups.deleteCategory(row.id!);
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
  const _AddRow();

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
    await ref.read(lookupsControllerProvider).addCategory(name);
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
            decoration: const InputDecoration(hintText: 'New category name'),
          ),
        ),
        const SizedBox(width: Space.sm),
        FilledButton(onPressed: _submit, child: const Text('Add')),
      ],
    );
  }
}
