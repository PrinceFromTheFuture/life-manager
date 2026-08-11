import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shopping_list/core/activity/activity_dao.dart';
import 'package:shopping_list/core/activity/activity_entry.dart';
import 'package:shopping_list/core/providers.dart';

final activityDaoProvider = Provider<ActivityDao>(
  (ref) => ActivityDao(ref.watch(databaseProvider).db),
);

/// The hub feed, grouped into days.
///
/// Invalidated by any app that writes an entry — see `ActivityWriter`. A
/// module finishing a piece of work calls `ref.invalidate(activityFeedProvider)`
/// so the hub reflects it without polling.
final activityFeedProvider = FutureProvider<List<ActivityDay>>(
  (ref) => ref.watch(activityDaoProvider).recentByDay(),
);
