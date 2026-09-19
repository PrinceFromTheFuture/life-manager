import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shopping_list/apps/calendar/data/clock.dart';
import 'package:shopping_list/apps/calendar/data/models/series.dart';
import 'package:shopping_list/apps/calendar/state/providers.dart';
import 'package:shopping_list/apps/calendar/ui/registry/series_sheet.dart';
import 'package:shopping_list/core/design/theme.dart';
import 'package:shopping_list/core/design/tokens.dart';
import 'package:shopping_list/core/design/widgets/app_icon.dart';
import 'package:shopping_list/core/design/widgets/perforation.dart';

/// The things that keep happening.
class RegistrySection extends ConsumerWidget {
  const RegistrySection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.thermal;
    final series = ref.watch(seriesProvider);

    return series.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text('$e', style: Type.caption.copyWith(color: palette.faded)),
      ),
      data: (items) {
        if (items.isEmpty) return const _NothingStanding();
        return ListView.separated(
          padding: const EdgeInsets.only(bottom: Space.xxl),
          itemCount: items.length,
          separatorBuilder: (_, __) => const PerforatedRule(indent: Space.lg),
          itemBuilder: (context, i) => _SeriesRow(series: items[i]),
        );
      },
    );
  }
}

class _SeriesRow extends ConsumerWidget {
  const _SeriesRow({required this.series});

  final Series series;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.thermal;
    final ink = series.active ? palette.print : palette.faded;
    final places = ref.watch(placesProvider).valueOrNull ?? const [];
    final place = places.where((p) => p.id == series.locationId).firstOrNull;

    return Dismissible(
      key: ValueKey('series-${series.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        color: palette.paperShade,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: Space.lg),
        child: AppIcon(SolarIcons.TrashBinMinimalistic, color: palette.faded),
      ),
      confirmDismiss: (_) => _confirm(context),
      onDismissed: (_) =>
          ref.read(calendarControllerProvider).deleteSeries(series.id!),
      child: InkWell(
        onTap: () => SeriesSheet.open(context, existing: series),
        onLongPress: () => ref.read(calendarControllerProvider).setSeriesActive(
              series.id!,
              active: !series.active,
            ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Space.lg, Space.md, Space.lg, Space.md),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      series.title,
                      style: Type.item.copyWith(color: ink),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        Clock.seriesRule(series),
                        if (place != null) place.title,
                      ].join(' · '),
                      style: Type.caption.copyWith(color: palette.faded),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (!series.active)
                Text('PAUSED', style: Type.eyebrow.copyWith(color: palette.faded)),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool> _confirm(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        final palette = context.thermal;
        return AlertDialog(
          backgroundColor: palette.paper,
          title: const Text('Remove this from the registry?'),
          content: const Text(
            'Future tickets stop appearing. Overrides written for it leave with it.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep it'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );
    return ok ?? false;
  }
}

class _NothingStanding extends StatelessWidget {
  const _NothingStanding();

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;
    return Padding(
      padding: const EdgeInsets.all(Space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: Space.xl),
          Text(
            'The things that keep happening.',
            style: Type.display.copyWith(color: palette.print, fontSize: 26),
          ),
          const SizedBox(height: Space.md),
          Text(
            'A gym session. A shift. Dinner on Thursday. Write the rule once.',
            style: Type.body.copyWith(color: palette.faded),
          ),
        ],
      ),
    );
  }
}
