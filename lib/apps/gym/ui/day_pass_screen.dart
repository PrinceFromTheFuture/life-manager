import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:shopping_list/apps/gym/data/gym_activity.dart';
import 'package:shopping_list/apps/gym/data/models/gym_set.dart';
import 'package:shopping_list/apps/gym/state/providers.dart';
import 'package:shopping_list/apps/gym/ui/exercises_screen.dart';
import 'package:shopping_list/apps/gym/ui/progress_screen.dart';
import 'package:shopping_list/apps/gym/ui/record_set_screen.dart';
import 'package:shopping_list/core/design/theme.dart';
import 'package:shopping_list/core/design/tokens.dart';
import 'package:shopping_list/core/design/widgets/perforation.dart';
import 'package:shopping_list/core/util/load.dart';

/// Today's day pass — the session is the calendar day.
///
/// The pass is blank until the first set is stamped onto it. Stepping the
/// date looks at earlier passes. Recording a set lands on today unless you
/// pick another day on the stamp itself.
class DayPassScreen extends ConsumerStatefulWidget {
  const DayPassScreen({super.key, this.day});

  /// When opened from the hub feed, the pass for that day. Otherwise today.
  final DateTime? day;

  @override
  ConsumerState<DayPassScreen> createState() => _DayPassScreenState();
}

class _DayPassScreenState extends ConsumerState<DayPassScreen> {
  @override
  void initState() {
    super.initState();
    final target = GymActivity.startOfDay(widget.day ?? DateTime.now());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(selectedDayProvider.notifier).state = target;
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;
    final blocks = ref.watch(dayBlocksProvider);

    return Scaffold(
      backgroundColor: palette.paper,
      appBar: AppBar(
        title: const Text('Gym'),
        actions: [
          IconButton(
            tooltip: 'Progress',
            icon: const Icon(Icons.bar_chart_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const ProgressScreen()),
            ),
          ),
          IconButton(
            tooltip: 'Exercises',
            icon: const Icon(Icons.tune),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const ExercisesScreen()),
            ),
          ),
          const SizedBox(width: Space.sm),
        ],
      ),
      body: Column(
        children: [
          const _DaySelector(),
          const PerforatedRule(),
          Expanded(
            child: blocks.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(Space.lg),
                  child: Text(
                    '$e',
                    style: Type.caption.copyWith(color: palette.faded),
                  ),
                ),
              ),
              data: (items) =>
                  items.isEmpty ? const _BlankPass() : _PassBody(blocks: items),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        color: palette.paper,
        padding: EdgeInsets.fromLTRB(
          Space.lg,
          Space.md,
          Space.lg,
          Space.md + MediaQuery.paddingOf(context).bottom,
        ),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => RecordSetScreen.open(context),
            icon: const Icon(Icons.add, size: 20),
            label: const Text('Record a set'),
          ),
        ),
      ),
    );
  }
}

class _DaySelector extends ConsumerWidget {
  const _DaySelector();

  Future<void> _jump(BuildContext context, WidgetRef ref, DateTime day) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: day,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year, now.month, now.day),
      helpText: 'Which day?',
      useRootNavigator: false,
    );
    if (picked == null) return;
    ref.read(selectedDayProvider.notifier).state =
        GymActivity.startOfDay(picked);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.thermal;
    final day = ref.watch(selectedDayProvider);
    final volume = ref.watch(dayVolumeProvider);
    final blocks = ref.watch(dayBlocksProvider);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isToday = day == today;

    final setCount = blocks.maybeWhen(
      data: (items) => items.fold<int>(0, (n, b) => n + b.sets.length),
      orElse: () => 0,
    );
    final setWord = setCount == 1 ? 'set' : 'sets';

    return Padding(
      padding:
          const EdgeInsets.fromLTRB(Space.lg, Space.md, Space.lg, Space.md),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                tooltip: 'Previous day',
                onPressed: () => ref.read(selectedDayProvider.notifier).state =
                    day.subtract(const Duration(days: 1)),
              ),
              Expanded(
                child: InkWell(
                  onTap: () => _jump(context, ref, day),
                  child: Column(
                    children: [
                      Text(
                        _dayLabel(day).toUpperCase(),
                        style: Type.eyebrow.copyWith(color: palette.faded),
                      ),
                      const SizedBox(height: Space.xs),
                      Text(
                        '$setCount $setWord',
                        style: Type.totalDisplay.copyWith(
                          color: palette.print,
                          fontSize: 32,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        volume.maybeWhen(
                          data: Load.formatVolume,
                          orElse: () => '—',
                        ),
                        style: Type.caption.copyWith(color: palette.faded),
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                tooltip: 'Next day',
                onPressed: isToday
                    ? null
                    : () => ref.read(selectedDayProvider.notifier).state =
                        day.add(const Duration(days: 1)),
              ),
            ],
          ),
          // Always on the switcher, not inside the date picker — paging back
          // one day at a time is how you look around, not how you come home.
          if (!isToday)
            TextButton(
              onPressed: () => ref.read(selectedDayProvider.notifier).state =
                  GymActivity.startOfDay(DateTime.now()),
              child: const Text('Return to today'),
            ),
        ],
      ),
    );
  }

  static String _dayLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final difference = today.difference(date).inDays;
    if (difference == 0) return 'Today';
    if (difference == 1) return 'Yesterday';
    if (difference < 7) return DateFormat('EEEE d MMM').format(date);
    return DateFormat('EEE d MMM yyyy').format(date);
  }
}

class _BlankPass extends StatelessWidget {
  const _BlankPass();

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PerforatedRule(),
          const SizedBox(height: Space.lg),
          Text(
            'Blank pass.',
            style: Type.display.copyWith(color: palette.print, fontSize: 26),
          ),
          const SizedBox(height: Space.md),
          Text(
            'Record the first set. The day holds it.',
            style: Type.body.copyWith(color: palette.faded),
          ),
        ],
      ),
    );
  }
}

class _PassBody extends ConsumerWidget {
  const _PassBody({required this.blocks});

  final List<ExerciseBlock> blocks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.only(bottom: Space.xxl),
      children: [
        for (var i = 0; i < blocks.length; i++) ...[
          const SizedBox(height: Space.lg),
          if (i == 0) ...[
            const TearEdge(),
            const SizedBox(height: Space.md),
          ],
          _ExerciseBlock(
            block: blocks[i],
            onRecord: () => RecordSetScreen.open(
              context,
              exerciseId: blocks[i].exerciseId,
            ),
          ),
        ],
      ],
    );
  }
}

class _ExerciseBlock extends ConsumerWidget {
  const _ExerciseBlock({required this.block, required this.onRecord});

  final ExerciseBlock block;
  final VoidCallback onRecord;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.thermal;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.lg),
          child: InkWell(
            onTap: onRecord,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    block.name.toUpperCase(),
                    style: Type.eyebrow.copyWith(color: palette.faded),
                  ),
                ),
                Text(
                  '${block.sets.length}',
                  style: Type.mono.copyWith(color: palette.faded),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Space.sm),
        for (var i = 0; i < block.sets.length; i++) ...[
          _SetRow(set: block.sets[i], index: i + 1),
          if (i != block.sets.length - 1)
            const PerforatedRule(indent: Space.lg),
        ],
      ],
    );
  }
}

class _SetRow extends ConsumerWidget {
  const _SetRow({required this.set, required this.index});

  final GymSet set;
  final int index;

  /// A stamped set is a record of work. Swiping it away between sets is easy
  /// to do by accident, and there is no undo once the row is gone — so this
  /// asks first, same as deleting an expense or a standing order.
  Future<bool> _confirmDelete(BuildContext context) async {
    final palette = context.thermal;
    return await showDialog<bool>(
          context: context,
          useRootNavigator: false,
          builder: (context) => AlertDialog(
            backgroundColor: palette.paper,
            surfaceTintColor: Colors.transparent,
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
            titleTextStyle:
                Type.display.copyWith(fontSize: 20, color: palette.print),
            contentTextStyle: Type.body.copyWith(color: palette.print),
            title: const Text('Delete this set?'),
            content: Text(
              '${Load.format(set.weightG)} × ${set.reps} is deleted for good.',
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
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.thermal;

    return Dismissible(
      key: ValueKey('set-${set.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmDelete(context),
      onDismissed: (_) => ref.read(gymControllerProvider).deleteSet(set.id!),
      background: ColoredBox(
        color: palette.paperShade,
        child: Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.only(right: Space.lg),
            child: Text(
              'Remove',
              style: Type.caption.copyWith(color: palette.faded),
            ),
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Space.lg,
          vertical: Space.md,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 28,
              child: Text(
                '$index',
                style: Type.mono.copyWith(color: palette.faded),
              ),
            ),
            Expanded(
              child: Text(
                Load.format(set.weightG),
                style: Type.item.copyWith(color: palette.print),
              ),
            ),
            Text(
              '× ${set.reps}',
              style: Type.monoBold.copyWith(color: palette.print),
            ),
          ],
        ),
      ),
    );
  }
}
