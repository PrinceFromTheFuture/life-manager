import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:shopping_list/apps/gym/data/models/progress.dart';
import 'package:shopping_list/apps/gym/state/providers.dart';
import 'package:shopping_list/apps/gym/ui/day_pass_screen.dart';
import 'package:shopping_list/apps/gym/ui/workout_plot.dart';
import 'package:shopping_list/core/design/theme.dart';
import 'package:shopping_list/core/design/tokens.dart';
import 'package:shopping_list/core/design/widgets/perforation.dart';
import 'package:shopping_list/core/util/load.dart';

/// One movement's history across workouts.
///
/// The plot is the same language as the list — stamps on a plate — scaled
/// so you can tap a session and read the pass it came from.
class ExerciseProgressScreen extends ConsumerStatefulWidget {
  const ExerciseProgressScreen({super.key, required this.item});

  final ExerciseProgress item;

  @override
  ConsumerState<ExerciseProgressScreen> createState() =>
      _ExerciseProgressScreenState();
}

class _ExerciseProgressScreenState
    extends ConsumerState<ExerciseProgressScreen> {
  int? _selected;

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;
    final exercise = widget.item.exercise;
    final history = ref.watch(exerciseWorkoutsProvider(exercise.id!));

    return Scaffold(
      backgroundColor: palette.paper,
      appBar: AppBar(title: Text(exercise.name)),
      body: history.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('$e', style: Type.caption.copyWith(color: palette.faded)),
        ),
        data: (marks) {
          if (marks.isEmpty) {
            return const _EmptyHistory();
          }
          final selected = (_selected ?? marks.length - 1)
              .clamp(0, marks.length - 1);
          final mark = marks[selected];
          final byReps = WorkoutMark.plotByReps(marks);

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              Space.lg,
              Space.md,
              Space.lg,
              Space.xxl,
            ),
            children: [
              Text(
                byReps ? 'REPS ACROSS WORKOUTS' : 'LOAD ACROSS WORKOUTS',
                style: Type.eyebrow.copyWith(color: palette.faded),
              ),
              const SizedBox(height: Space.md),
              WorkoutPlot(
                marks: marks,
                compact: false,
                height: 168,
                selectedIndex: selected,
                onSelect: (i) => setState(() => _selected = i),
              ),
              const SizedBox(height: Space.md),
              Text(
                _selectedCaption(mark, byReps),
                style: Type.item.copyWith(color: palette.print),
              ),
              const SizedBox(height: 2),
              Text(
                DateFormat('EEEE d MMMM yyyy').format(mark.day),
                style: Type.caption.copyWith(color: palette.faded),
              ),
              const SizedBox(height: Space.sm),
              Text(
                _deltaSinceLast(marks, selected) ??
                    _bestCaption(widget.item, byReps),
                style: Type.caption.copyWith(color: palette.carbon),
              ),
              const SizedBox(height: Space.lg),
              const PerforatedRule(),
              const SizedBox(height: Space.lg),
              Text(
                'WORKOUTS',
                style: Type.eyebrow.copyWith(color: palette.faded),
              ),
              const SizedBox(height: Space.md),
              for (var i = marks.length - 1; i >= 0; i--) ...[
                if (i != marks.length - 1) ...[
                  const PerforatedRule(indent: 0),
                ],
                _WorkoutRow(
                  mark: marks[i],
                  byReps: byReps,
                  selected: i == selected,
                  onTap: () => setState(() => _selected = i),
                  onOpenPass: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => DayPassScreen(day: marks[i].day),
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  static String _selectedCaption(WorkoutMark mark, bool byReps) {
    final top = byReps
        ? '${mark.topReps} reps'
        : '${Load.format(mark.topWeightG)} × ${mark.topReps}';
    final setWord = mark.sets == 1 ? 'set' : 'sets';
    return '$top · ${mark.sets} $setWord';
  }

  static String _bestCaption(ExerciseProgress item, bool byReps) {
    if (byReps && item.bestReps != null) {
      return 'Best ${item.bestReps} reps';
    }
    if (item.bestWeightG != null && item.bestWeightG! > 0) {
      return 'Best ${Load.format(item.bestWeightG!)}';
    }
    return 'First workout of this movement.';
  }

  static String? _deltaSinceLast(List<WorkoutMark> marks, int selected) {
    if (selected <= 0) return null;
    final byReps = WorkoutMark.plotByReps(marks);
    final last = marks[selected];
    final prev = marks[selected - 1];
    if (byReps) {
      final d = last.topReps - prev.topReps;
      if (d == 0) return 'Same reps as the previous workout';
      if (d > 0) return '+$d reps from the previous workout';
      return '$d reps from the previous workout';
    }
    final d = last.topWeightG - prev.topWeightG;
    if (d == 0) return 'Same load as the previous workout';
    final signed = d > 0 ? '+${Load.formatBare(d)}' : Load.formatBare(d);
    return '$signed kg from the previous workout';
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

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
            'No workouts yet.',
            style: Type.display.copyWith(color: palette.print, fontSize: 26),
          ),
        ],
      ),
    );
  }
}

class _WorkoutRow extends StatelessWidget {
  const _WorkoutRow({
    required this.mark,
    required this.byReps,
    required this.selected,
    required this.onTap,
    required this.onOpenPass,
  });

  final WorkoutMark mark;
  final bool byReps;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onOpenPass;

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;
    final top = byReps
        ? '${mark.topReps} reps'
        : '${Load.format(mark.topWeightG)} × ${mark.topReps}';
    final setWord = mark.sets == 1 ? 'set' : 'sets';

    return Material(
      color: selected ? palette.paperShade : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onOpenPass,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Space.md),
          child: Row(
            children: [
              Container(
                width: 3,
                height: 26,
                color: selected ? palette.carbon : palette.perforation,
              ),
              const SizedBox(width: Space.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('d MMM yyyy').format(mark.day),
                      style: Type.item.copyWith(color: palette.print),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$top · ${mark.sets} $setWord'
                      '${byReps ? '' : ' · ${Load.formatVolume(mark.volumeGramReps)}'}',
                      style: Type.caption.copyWith(color: palette.faded),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Open this day',
                icon: const Icon(Icons.chevron_right),
                color: palette.faded,
                onPressed: onOpenPass,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
