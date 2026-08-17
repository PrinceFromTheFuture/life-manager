import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shopping_list/apps/gym/data/models/exercise.dart';
import 'package:shopping_list/apps/gym/state/providers.dart';
import 'package:shopping_list/core/design/theme.dart';
import 'package:shopping_list/core/design/tokens.dart';
import 'package:shopping_list/core/design/widgets/perforation.dart';

/// The catalogue. What is on the rack is what the recorder offers.
class ExercisesScreen extends ConsumerWidget {
  const ExercisesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.thermal;
    final source = ref.watch(exercisesProvider);

    return Scaffold(
      backgroundColor: palette.paper,
      appBar: AppBar(title: const Text('Exercises')),
      body: source.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('$e', style: Type.caption.copyWith(color: palette.faded)),
        ),
        data: (rows) => rows.isEmpty
            ? Center(
                child: Text(
                  'No exercises yet.',
                  style: Type.body.copyWith(color: palette.faded),
                ),
              )
            : _ReorderableList(rows: rows),
      ),
      bottomNavigationBar: const SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(Space.lg, Space.md, Space.lg, Space.md),
          child: _AddRow(),
        ),
      ),
    );
  }
}

class _ReorderableList extends ConsumerWidget {
  const _ReorderableList({required this.rows});

  final List<Exercise> rows;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(gymControllerProvider);

    return ReorderableListView.builder(
      padding: const EdgeInsets.symmetric(vertical: Space.md),
      itemCount: rows.length,
      onReorderItem: (oldIndex, newIndex) {
        final ids = rows.map((r) => r.id!).toList();
        final id = ids.removeAt(oldIndex);
        ids.insert(newIndex, id);
        controller.reorderExercises(ids);
      },
      itemBuilder: (context, index) {
        final row = rows[index];
        return Container(
          key: ValueKey('exercise-${row.id}'),
          color: context.thermal.paper,
          child: Column(
            children: [
              _ExerciseTile(row: row),
              const PerforatedRule(indent: Space.lg),
            ],
          ),
        );
      },
    );
  }
}

class _ExerciseTile extends ConsumerWidget {
  const _ExerciseTile({required this.row});

  final Exercise row;

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
    await ref.read(gymControllerProvider).renameExercise(row.id!, name);
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final gym = ref.read(gymControllerProvider);
    final usage = await gym.exerciseUsage(row.id!);
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
              ? 'Nothing uses this exercise yet.'
              : '$usage ${usage == 1 ? 'set' : 'sets'} will be deleted with it.',
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
      await gym.deleteExercise(row.id!);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.thermal;

    return Padding(
      padding:
          const EdgeInsets.fromLTRB(Space.lg, Space.sm, Space.sm, Space.sm),
      child: Row(
        children: [
          Icon(Icons.drag_indicator, size: 18, color: palette.faded),
          const SizedBox(width: Space.md),
          Expanded(
            child: InkWell(
              onTap: () => _rename(context, ref),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: Space.xs),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.name,
                      style: Type.item.copyWith(color: palette.print),
                    ),
                    Text(
                      row.onRack ? 'On the rack' : 'Off the rack',
                      style: Type.caption.copyWith(color: palette.faded),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Switch(
            value: row.onRack,
            onChanged: (v) =>
                ref.read(gymControllerProvider).setOnRack(row.id!, v),
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
    await ref.read(gymControllerProvider).addExercise(name);
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
            decoration: const InputDecoration(hintText: 'New exercise name'),
          ),
        ),
        const SizedBox(width: Space.sm),
        FilledButton(onPressed: _submit, child: const Text('Add')),
      ],
    );
  }
}
