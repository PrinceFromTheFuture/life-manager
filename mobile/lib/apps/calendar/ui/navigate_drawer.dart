import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shopping_list/apps/calendar/data/models/place.dart';
import 'package:shopping_list/apps/calendar/state/providers.dart';
import 'package:shopping_list/apps/calendar/ui/navigate_open.dart';
import 'package:shopping_list/core/design/theme.dart';
import 'package:shopping_list/core/design/tokens.dart';
import 'package:shopping_list/core/design/widgets/app_icon.dart';
import 'package:shopping_list/core/design/widgets/inset_drawer.dart';

Future<void> showNavigateDrawer(BuildContext context) {
  return showInsetDrawer<void>(
    context: context,
    primary: (_) => const _PlacesList(),
  );
}

class _PlacesList extends ConsumerWidget {
  const _PlacesList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.thermal;
    final places = ref.watch(placesProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.lg, Space.sm, Space.lg, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('GO', style: Type.eyebrow.copyWith(color: palette.faded)),
          const SizedBox(height: Space.md),
          places.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(Space.xl),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Text('$e', style: Type.caption.copyWith(color: palette.faded)),
            data: (items) {
              if (items.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: Space.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'No places yet.',
                        style: Type.display.copyWith(
                          fontSize: 22,
                          color: palette.print,
                        ),
                      ),
                      const SizedBox(height: Space.sm),
                      Text(
                        'Name them in Calendar. Then this opens the map.',
                        style: Type.body.copyWith(color: palette.faded),
                      ),
                    ],
                  ),
                );
              }
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final place in items)
                    _PlaceRow(place: place),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PlaceRow extends StatelessWidget {
  const _PlaceRow({required this.place});

  final Place place;

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;
    final brightness = Theme.of(context).brightness;
    final ink = place.ink.of(brightness);

    return InkWell(
      onTap: () async {
        Navigator.of(context).pop();
        await NavigateOpen.to(place);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.md),
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
            AppIcon(SolarIcons.Route, size: 18, color: palette.faded),
          ],
        ),
      ),
    );
  }
}
