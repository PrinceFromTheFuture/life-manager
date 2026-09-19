import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shopping_list/apps/calendar/state/providers.dart';
import 'package:shopping_list/apps/calendar/ui/places/place_sheet.dart';
import 'package:shopping_list/core/design/theme.dart';
import 'package:shopping_list/core/design/tokens.dart';
import 'package:shopping_list/core/design/widgets/app_icon.dart';
import 'package:shopping_list/core/design/widgets/inset_drawer.dart';

/// Pick a place from the store. Returns `0` for none, null if cancelled.
Future<int?> showPlacePicker(BuildContext context, {int? selectedId}) {
  return showInsetDrawer<int>(
    context: context,
    primary: (_) => _PlaceMenu(selectedId: selectedId),
  );
}

class _PlaceMenu extends ConsumerWidget {
  const _PlaceMenu({this.selectedId});

  final int? selectedId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.thermal;
    final places = ref.watch(placesProvider).valueOrNull ?? const [];

    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.lg, Space.sm, Space.lg, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('PLACE', style: Type.eyebrow.copyWith(color: palette.faded)),
          const SizedBox(height: Space.md),
          _row(
            context,
            icon: SolarIcons.CloseCircle,
            title: 'None',
            selected: selectedId == null,
            ink: palette.faded,
            onTap: () => Navigator.pop(context, 0),
          ),
          for (final place in places)
            _row(
              context,
              icon: place.mark.icon,
              title: place.title,
              selected: place.id == selectedId,
              ink: place.ink.of(Theme.of(context).brightness),
              onTap: () => Navigator.pop(context, place.id),
            ),
          _row(
            context,
            icon: SolarIcons.AddCircle,
            title: 'New place',
            selected: false,
            ink: palette.print,
            onTap: () async {
              final id = await PlaceSheet.open(context);
              if (id != null && context.mounted) Navigator.pop(context, id);
            },
          ),
        ],
      ),
    );
  }

  Widget _row(
    BuildContext context, {
    required SolarIconData icon,
    required String title,
    required bool selected,
    required Color ink,
    required VoidCallback onTap,
  }) {
    final palette = context.thermal;
    return InkWell(
      onTap: onTap,
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
                child: AppIcon(icon, size: 18, color: ink),
              ),
            ),
            const SizedBox(width: Space.md),
            Expanded(
              child: Text(
                title,
                style: Type.item.copyWith(color: palette.print),
              ),
            ),
            if (selected)
              AppIcon(SolarIcons.CheckCircle, size: 18, color: palette.print),
          ],
        ),
      ),
    );
  }
}
