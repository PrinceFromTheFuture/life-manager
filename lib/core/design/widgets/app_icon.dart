import 'package:flutter/material.dart';
import 'package:flutty_solar_icons/solar_icons_flutter.dart';

import 'package:shopping_list/core/design/tokens.dart';

export 'package:flutty_solar_icons/solar_icons_flutter.dart'
    show SolarIconData, SolarIcons;

/// Solar Bold Duotone — the only icon language in the app.
///
/// One filled weight, two inks: print on the primary path, spent thermal on
/// the second. That is the same carbon-and-fade the paper already speaks, so
/// the glyphs belong on a slip rather than floating above it.
class AppIcon extends StatelessWidget {
  const AppIcon(
    this.icon, {
    super.key,
    this.size,
    this.color,
    this.secondaryColor,
  });

  final SolarIconData icon;
  final double? size;
  final Color? color;
  final Color? secondaryColor;

  @override
  Widget build(BuildContext context) {
    final theme = IconTheme.of(context);
    final palette = Theme.of(context).extension<ThermalPalette>();
    final primary = color ?? theme.color ?? palette?.print;
    final secondary = secondaryColor ??
        (color != null
            ? color!.withValues(alpha: 0.42)
            : palette?.faded);

    return SolarIcon(
      icon,
      weight: SolarIconWeight.boldDuotone,
      size: size ?? theme.size ?? 24,
      color: primary,
      secondaryColor: secondary,
    );
  }
}
