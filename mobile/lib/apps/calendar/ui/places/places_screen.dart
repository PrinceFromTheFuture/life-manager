import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shopping_list/apps/calendar/data/models/place.dart';
import 'package:shopping_list/apps/calendar/state/providers.dart';
import 'package:shopping_list/apps/calendar/ui/places/place_sheet.dart';
import 'package:shopping_list/core/design/theme.dart';
import 'package:shopping_list/core/design/tokens.dart';
import 'package:shopping_list/core/design/widgets/app_icon.dart';
import 'package:shopping_list/core/design/widgets/perforation.dart';

/// The store of places. Independent of events — events only point here.
class PlacesSection extends ConsumerWidget {
  const PlacesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.thermal;
    final places = ref.watch(placesProvider);

    return places.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text('$e', style: Type.caption.copyWith(color: palette.faded)),
      ),
      data: (items) {
        if (items.isEmpty) return const _NothingHere();
        return ListView.separated(
          padding: const EdgeInsets.only(bottom: Space.xxl),
          itemCount: items.length,
          separatorBuilder: (_, __) => const PerforatedRule(indent: Space.lg),
          itemBuilder: (context, i) => _PlaceRow(place: items[i]),
        );
      },
    );
  }
}

class _PlaceRow extends ConsumerWidget {
  const _PlaceRow({required this.place});

  final Place place;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.thermal;
    final ink = place.ink.of(Theme.of(context).brightness);

    return Dismissible(
      key: ValueKey('place-${place.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        color: palette.paperShade,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: Space.lg),
        child: AppIcon(SolarIcons.TrashBinMinimalistic, color: palette.faded),
      ),
      confirmDismiss: (_) => _confirm(context),
      onDismissed: (_) =>
          ref.read(calendarControllerProvider).deletePlace(place.id!),
      child: InkWell(
        onTap: () => PlaceSheet.open(context, existing: place),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Space.lg, Space.md, Space.lg, Space.md),
          child: Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: ink.withValues(alpha: 0.10),
                  borderRadius: Radii.key,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(Space.sm),
                  child: AppIcon(place.mark.icon, size: 20, color: ink),
                ),
              ),
              const SizedBox(width: Space.md),
              Expanded(
                child: Text(
                  place.title,
                  style: Type.item.copyWith(color: palette.print),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
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
          title: const Text('Remove this place?'),
          content: const Text(
            'Events that pointed here keep their time. They lose the pin.',
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

class _NothingHere extends StatelessWidget {
  const _NothingHere();

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
            'No places yet.',
            style: Type.display.copyWith(color: palette.print, fontSize: 26),
          ),
          const SizedBox(height: Space.md),
          Text(
            'Home, work, the gym, parents. Name them here. Events pick from this list.',
            style: Type.body.copyWith(color: palette.faded),
          ),
        ],
      ),
    );
  }
}
