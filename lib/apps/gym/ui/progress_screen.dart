import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:shopping_list/apps/gym/data/models/progress.dart';
import 'package:shopping_list/apps/gym/state/providers.dart';
import 'package:shopping_list/core/design/theme.dart';
import 'package:shopping_list/core/design/tokens.dart';
import 'package:shopping_list/core/design/widgets/perforation.dart';
import 'package:shopping_list/core/util/load.dart';

/// Per-exercise progress and the week's training, on one screen.
///
/// Not a dashboard. Each row is one movement: last working set, best, and
/// what this week added. The paper sparkline is the last sessions' top sets
/// in a row of mono numbers — order is the information.
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
            'Progress fills in once you have logged a set.',
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
    final best = _bestLabel(item);
    final lastWhen = item.lastAt == null ? '' : ' · ${_ago(item.lastAt!)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          item.exercise.name,
          style: Type.item.copyWith(color: palette.print),
        ),
        const SizedBox(height: Space.xs),
        Text(
          'Last $last$lastWhen',
          style: Type.caption.copyWith(color: palette.faded),
        ),
        Text(
          'Best $best'
          '${item.weekSets == 0 ? '' : ' · this week ${Load.formatVolume(item.weekVolumeGramReps)}'}',
          style: Type.caption.copyWith(color: palette.faded),
        ),
        if (item.recentTopWeights.length >= 2) ...[
          const SizedBox(height: Space.sm),
          _Spark(weights: item.recentTopWeights),
        ],
      ],
    );
  }

  static String _bestLabel(ExerciseProgress item) {
    if (item.bestWeightG != null && item.bestWeightG! > 0) {
      return Load.format(item.bestWeightG!);
    }
    if (item.bestReps != null && item.bestReps! > 0) {
      return '${item.bestReps} reps';
    }
    return '—';
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

/// Last sessions' top sets, oldest to newest. A row of numbers, not a chart —
/// you can read the actual loads.
class _Spark extends StatelessWidget {
  const _Spark({required this.weights});

  final List<int> weights;

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;
    return Wrap(
      spacing: Space.sm,
      runSpacing: Space.xs,
      children: [
        for (var i = 0; i < weights.length; i++)
          Text(
            Load.formatBare(weights[i]),
            style: Type.mono.copyWith(
              color: i == weights.length - 1 ? palette.print : palette.faded,
            ),
          ),
      ],
    );
  }
}
