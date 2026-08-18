import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:shopping_list/apps/gym/data/gym_activity.dart';
import 'package:shopping_list/apps/gym/data/models/progress.dart';
import 'package:shopping_list/apps/gym/state/providers.dart';
import 'package:shopping_list/apps/gym/ui/exercise_progress_screen.dart';
import 'package:shopping_list/apps/gym/ui/workout_plot.dart';
import 'package:shopping_list/core/design/theme.dart';
import 'package:shopping_list/core/design/tokens.dart';
import 'package:shopping_list/core/design/widgets/perforation.dart';
import 'package:shopping_list/core/util/load.dart';

/// Per-exercise progress across workouts, and this week's training.
///
/// Each movement is a row with its session plot — stamps on paper, not a
/// dashboard card. Tapping opens the full history for that lift.
class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.thermal;
    final week = ref.watch(weekSummaryProvider);
    final progress = ref.watch(progressProvider);

    return Scaffold(
      backgroundColor: palette.paper,
      appBar: AppBar(title: const Text('Progress')),
      body: progress.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('$e', style: Type.caption.copyWith(color: palette.faded)),
        ),
        data: (items) => items.isEmpty
            ? const _EmptyProgress()
            : ListView(
                padding: const EdgeInsets.fromLTRB(
                  Space.lg,
                  Space.lg,
                  Space.lg,
                  Space.xxl,
                ),
                children: [
                  Text(
                    'THIS WEEK',
                    style: Type.eyebrow.copyWith(color: palette.faded),
                  ),
                  const SizedBox(height: Space.sm),
                  week.maybeWhen(
                    data: (s) => _WeekHero(summary: s),
                    orElse: () => const SizedBox.shrink(),
                  ),
                  const SizedBox(height: Space.lg),
                  const PerforatedRule(),
                  const SizedBox(height: Space.xl),
                  Text(
                    'BY EXERCISE',
                    style: Type.eyebrow.copyWith(color: palette.faded),
                  ),
                  const SizedBox(height: Space.lg),
                  for (var i = 0; i < items.length; i++) ...[
                    _ExerciseProgressRow(item: items[i]),
                    if (i != items.length - 1) ...[
                      const SizedBox(height: Space.md),
                      const PerforatedRule(),
                      const SizedBox(height: Space.md),
                    ],
                  ],
                ],
              ),
      ),
    );
  }
}

class _EmptyProgress extends StatelessWidget {
  const _EmptyProgress();

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
            'Nothing to show yet.',
            style: Type.display.copyWith(color: palette.print, fontSize: 26),
          ),
          const SizedBox(height: Space.md),
          Text(
            'The line appears after a second workout of the same movement.',
            style: Type.body.copyWith(color: palette.faded),
          ),
        ],
      ),
    );
  }
}

class _WeekHero extends StatelessWidget {
  const _WeekHero({required this.summary});

  final WeekSummary summary;

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;
    final dayWord = summary.daysTrained == 1 ? 'day' : 'days';
    final setWord = summary.sets == 1 ? 'set' : 'sets';
    final trained = summary.trainedDayKeys.toSet();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          Load.formatVolume(summary.volumeGramReps),
          style: Type.totalDisplay.copyWith(color: palette.print, fontSize: 36),
        ),
        const SizedBox(height: Space.xs),
        Text(
          '${summary.daysTrained} $dayWord · ${summary.sets} $setWord',
          style: Type.caption.copyWith(color: palette.faded),
        ),
        const SizedBox(height: Space.md),
        Row(
          children: [
            for (var i = 0; i < 7; i++) ...[
              if (i > 0) const SizedBox(width: Space.xs),
              Expanded(
                child: _WeekPunch(
                  label: _weekdayLetter(i),
                  stamped: trained.contains(
                    GymActivity.dayKey(
                      summary.weekStart.add(Duration(days: i)),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  static String _weekdayLetter(int mondayOffset) {
    const letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return letters[mondayOffset];
  }
}

/// A day of the week, punched if you trained. The week's day pass.
class _WeekPunch extends StatelessWidget {
  const _WeekPunch({required this.label, required this.stamped});

  final String label;
  final bool stamped;

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 1.6,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: stamped ? palette.carbon : palette.paperShade,
              border: Border.all(
                color: stamped ? palette.carbon : palette.perforation,
                width: 1,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Type.mono.copyWith(
            color: stamped ? palette.print : palette.faded,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

class _ExerciseProgressRow extends StatelessWidget {
  const _ExerciseProgressRow({required this.item});

  final ExerciseProgress item;

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;
    final last = item.lastWeightG == null
        ? '—'
        : '${Load.format(item.lastWeightG!)} × ${item.lastReps}';
    final lastWhen = item.lastAt == null ? '' : ' · ${_ago(item.lastAt!)}';
    final delta = _deltaSinceLast(item.recentWorkouts);
    final workouts = item.workoutCount == 1
        ? '1 workout'
        : item.workoutCount > item.recentWorkouts.length
            ? 'last ${item.recentWorkouts.length} of ${item.workoutCount}'
            : '${item.workoutCount} workouts';

    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ExerciseProgressScreen(item: item),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.xs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.exercise.name,
                    style: Type.item.copyWith(color: palette.print),
                  ),
                ),
                Text(
                  workouts,
                  style: Type.mono.copyWith(color: palette.faded, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: Space.xs),
            Text(
              'Last $last$lastWhen',
              style: Type.caption.copyWith(color: palette.faded),
            ),
            if (delta != null)
              Text(
                delta,
                style: Type.caption.copyWith(color: palette.carbon),
              ),
            if (item.recentWorkouts.isNotEmpty) ...[
              const SizedBox(height: Space.sm),
              WorkoutPlot(marks: item.recentWorkouts, height: 64),
            ],
          ],
        ),
      ),
    );
  }

  static String _ago(DateTime at) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(at.year, at.month, at.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'today';
    if (diff == 1) return 'yesterday';
    if (diff < 7) return DateFormat('EEEE').format(at);
    return DateFormat('d MMM').format(at);
  }
}

String? _deltaSinceLast(List<WorkoutMark> marks) {
  if (marks.length < 2) return null;
  final byReps = WorkoutMark.plotByReps(marks);
  final last = marks.last;
  final prev = marks[marks.length - 2];
  if (byReps) {
    final d = last.topReps - prev.topReps;
    if (d == 0) return 'Same reps as last workout';
    if (d > 0) return '+$d reps from last workout';
    return '$d reps from last workout';
  }
  final d = last.topWeightG - prev.topWeightG;
  if (d == 0) return 'Same load as last workout';
  final signed = d > 0 ? '+${Load.formatBare(d)}' : Load.formatBare(d);
  return '$signed kg from last workout';
}
