import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shopping_list/apps/calendar/data/models/place.dart';
import 'package:shopping_list/apps/calendar/state/providers.dart';
import 'package:shopping_list/apps/calendar/ui/drawer/drawer_parts.dart';
import 'package:shopping_list/apps/calendar/ui/night.dart';
import 'package:shopping_list/core/design/theme.dart';
import 'package:shopping_list/core/design/tokens.dart';
import 'package:shopping_list/core/design/widgets/app_icon.dart';
import 'package:shopping_list/core/design/widgets/multi_view_drawer.dart';


/// The places this life goes. Picks one for an event, or — with [onEdit] and
/// no [onPick] — manages the list.
class PlaceView extends ConsumerWidget {
  const PlaceView({
    super.key,
    required this.onNew,
    this.onPick,
    this.onEdit,
    this.selectedId,
    this.title = 'Place',
  });

  final VoidCallback onNew;
  final ValueChanged<Place?>? onPick;
  final ValueChanged<Place>? onEdit;
  final int? selectedId;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final places = ref.watch(placesProvider).valueOrNull ?? const <Place>[];
    final picking = onPick != null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DrawerViewHeader(title: title),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: Space.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (places.isEmpty && !picking)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: Space.xl),
                    child: Column(
                      children: [
                        const AppIcon(SolarIcons.MapPoint, size: 34, color: Night.mist),
                        const SizedBox(height: Space.md),
                        Text(
                          'No places yet',
                          style: Type.itemLarge.copyWith(color: Night.bone),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Pin home, work or the gym once. Events point at them\nand navigation is one tap away.',
                          textAlign: TextAlign.center,
                          style: Type.caption.copyWith(color: Night.mist),
                        ),
                      ],
                    ),
                  )
                else
                  DrawerGroup(
                    children: [
                      if (picking)
                        DrawerRow(
                          icon: SolarIcons.CloseCircle,
                          label: 'No place',
                          chevron: false,
                          trailing: _Check(on: selectedId == null),
                          onTap: () => onPick!(null),
                        ),
                      for (final place in places)
                        DrawerRow(
                          icon: place.mark.icon,
                          iconColor: place.ink.dark,
                          label: place.title,
                          chevron: !picking,
                          trailing: picking
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (onEdit != null)
                                      GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onTap: () => onEdit!(place),
                                        child: const Padding(
                                          padding: EdgeInsets.symmetric(horizontal: Space.sm),
                                          child: AppIcon(SolarIcons.Pen, size: 18, color: Night.mist),
                                        ),
                                      ),
                                    _Check(on: selectedId == place.id),
                                  ],
                                )
                              : null,
                          onTap: () => picking ? onPick!(place) : onEdit?.call(place),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        DrawerFooter(
          children: [
            DrawerSecondaryButton(
              label: 'New place',
              icon: SolarIcons.AddCircle,
              onTap: onNew,
            ),
          ],
        ),
      ],
    );
  }
}

class _Check extends StatelessWidget {
  const _Check({required this.on});

  final bool on;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      opacity: on ? 1 : 0,
      child: const AppIcon(SolarIcons.CheckCircle, size: 20, color: Night.bone),
    );
  }
}
