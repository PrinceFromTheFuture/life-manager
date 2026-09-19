import 'package:flutter/material.dart';

import 'package:shopping_list/core/app/mini_app.dart';
import 'package:shopping_list/core/design/theme.dart';
import 'package:shopping_list/core/design/tokens.dart';

/// Re-inks everything below it in this mini-app's accent.
///
/// Wraps an app's whole subtree and swaps exactly one token — `carbon` — so
/// buttons, focus rings, chips, cursors and stamps all pick up that app's ink
/// while paper, print, faded, perforation, scorch and settled stay identical
/// across the product.
///
/// It rebuilds the whole [ThemeData] rather than only overriding the
/// [ThermalPalette] extension, because [buildTheme] bakes `carbon` into the
/// button, input and snackbar themes. Overriding the extension alone would
/// re-ink text that reads `context.thermal.carbon` but leave every Material
/// control still violet — the kind of half-applied theme that is maddening to
/// track down later.
///
/// The result is cached against ink and brightness so a rebuild of the app
/// subtree doesn't construct a new ThemeData on every frame.
class InkScope extends StatefulWidget {
  const InkScope({super.key, required this.ink, required this.child});

  final AppInk ink;
  final Widget child;

  @override
  State<InkScope> createState() => _InkScopeState();
}

class _InkScopeState extends State<InkScope> {
  ThemeData? _cached;
  Color? _cachedColor;
  Brightness? _cachedBrightness;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final color = widget.ink.of(brightness);

    if (_cached == null ||
        _cachedColor != color ||
        _cachedBrightness != brightness) {
      final base = brightness == Brightness.light
          ? ThermalPalette.light
          : ThermalPalette.dark;
      _cached = buildTheme(base.copyWith(carbon: color), brightness);
      _cachedColor = color;
      _cachedBrightness = brightness;
    }

    return Theme(data: _cached!, child: widget.child);
  }
}

/// The hub's own "ink" is simply print black.
///
/// The shell deliberately has no colour of its own, so the only colour on the
/// hub is the apps' — which is what makes the stamps on the feed readable at a
/// glance as "which app was this".
AppInk get shellInk => AppInk(
      light: ThermalPalette.light.print,
      dark: ThermalPalette.dark.print,
    );
