import 'package:flutter/material.dart';
import 'package:flutty_solar_icons/solar_icons_flutter.dart';

import 'package:shopping_list/apps/home/ui/home_palette.dart';

export 'package:flutty_solar_icons/solar_icons_flutter.dart' show SolarIconData, SolarIcons;

/// The round header control from Home. Tile fill, linear glyph, same diameter
/// as the portrait.
class NightPlate extends StatelessWidget {
  const NightPlate({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
    this.size = 42,
  });

  final SolarIconData icon;
  final String label;
  final VoidCallback? onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: Material(
        color: HomePalette.tile,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: size,
            height: size,
            child: Center(
              child: SolarIcon(
                icon,
                weight: SolarIconWeight.linear,
                color: enabled ? HomePalette.bone : HomePalette.mist,
                size: size * 0.48,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
