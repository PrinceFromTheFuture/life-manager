import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:shopping_list/core/activity/activity_entry.dart';
import 'package:shopping_list/core/app/registry.dart';
import 'package:shopping_list/core/design/theme.dart';
import 'package:shopping_list/core/design/tokens.dart';
import 'package:shopping_list/core/design/widgets/perforation.dart';

/// The spindle: everything that has happened, newest first.
///
/// Structure carries the meaning, as everywhere else in this app — a **tear
/// edge separates days**, a **perforated rule separates entries within a day**.
/// No date badges or coloured headers are needed because the divider already
/// says which kind of boundary you just crossed.
///
/// Rows are rendered by whichever module wrote them, so this widget never
/// learns what an expense or a shopping trip is.
class ActivityFeed extends ConsumerWidget {
  const ActivityFeed({super.key, required this.days});

  final List<ActivityDay> days;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final registry = ref.watch(registryProvider);
    final palette = context.thermal;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final day in days) ...[
          const SizedBox(height: Space.lg),
          const TearEdge(),
          const SizedBox(height: Space.md),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.lg),
            child: Text(
              _dayLabel(day.date),
              style: Type.eyebrow.copyWith(color: palette.faded),
            ),
          ),
          const SizedBox(height: Space.sm),
          for (final entry in day.entries) ...[
            Builder(
              builder: (context) {
                final app = registry.byId(entry.appId);
                // History written by an app no longer in this build. Skipping
                // beats crashing on someone's own data.
                if (app == null) return const SizedBox.shrink();
                return app.buildActivityRow(context, entry);
              },
            ),
            if (entry != day.entries.last)
              const PerforatedRule(indent: Space.lg),
          ],
        ],
      ],
    );
  }

  /// Relative for the two days people actually think in, absolute after that.
  /// "TUESDAY" three weeks ago is not information, a date is.
  static String _dayLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final difference = today.difference(date).inDays;

    if (difference == 0) return 'TODAY';
    if (difference == 1) return 'YESTERDAY';
    if (difference < 7) return DateFormat('EEEE').format(date).toUpperCase();
    return DateFormat('d MMM yyyy').format(date).toUpperCase();
  }
}
