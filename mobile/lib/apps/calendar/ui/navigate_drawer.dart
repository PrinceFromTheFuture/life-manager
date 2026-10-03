import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shopping_list/apps/calendar/data/models/place.dart';
import 'package:shopping_list/apps/calendar/state/providers.dart';
import 'package:shopping_list/apps/calendar/ui/drawer/drawer_parts.dart';
import 'package:shopping_list/apps/calendar/ui/navigate_open.dart';
import 'package:shopping_list/apps/calendar/ui/night.dart';
import 'package:shopping_list/core/design/theme.dart';
import 'package:shopping_list/core/design/tokens.dart';
import 'package:shopping_list/core/design/widgets/app_icon.dart';
import 'package:shopping_list/core/design/widgets/multi_view_drawer.dart';

/// Every place, one tap from the maps app.
Future<void> showNavigateDrawer(BuildContext context) {
  return showMultiViewDrawer<void>(
    context: context,
    initial: 'go',
    views: {'go': DrawerView(builder: (_) => const _PlacesList())},
  );
}

class _PlacesList extends ConsumerWidget {
  const _PlacesList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final places = ref.watch(placesProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const DrawerViewHeader(title: 'Go'),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.lg),
            child: places.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(Space.xl),
                child: Center(
                  child: CircularProgressIndicator(strokeWidth: 2, color: Night.mist),
                ),
              ),
              error: (e, _) => Text('$e', style: Type.caption.copyWith(color: Night.mist)),
              data: (items) {
                if (items.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: Space.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'No places yet.',
                          style: Type.display.copyWith(fontSize: 22, color: Night.bone),
                        ),
                        const SizedBox(height: Space.sm),
                        Text(
                          'Pin them in Calendar under Places. Then this opens the map.',
                          style: Type.body.copyWith(color: Night.mist),
                        ),
                      ],
                    ),
                  );
                }
                return DrawerGroup(
                  children: [for (final place in items) _PlaceRow(place: place)],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _PlaceRow extends StatelessWidget {
  const _PlaceRow({required this.place});

  final Place place;

  @override
  Widget build(BuildContext context) {
    return DrawerRow(
      icon: place.mark.icon,
      iconColor: place.ink.dark,
      label: place.title,
      chevron: false,
      trailing: const AppIcon(SolarIcons.Routing, size: 18, color: Night.mist),
      onTap: () async {
        MultiViewDrawer.of(context).close();
        await NavigateOpen.to(place);
      },
    );
  }
}
