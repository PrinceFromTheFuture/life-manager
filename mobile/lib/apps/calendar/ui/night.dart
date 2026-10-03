import 'package:flutter/material.dart';

import 'package:shopping_list/apps/calendar/data/models/place.dart';
import 'package:shopping_list/apps/calendar/data/models/ticket.dart';
import 'package:shopping_list/apps/home/ui/home_palette.dart';
import 'package:shopping_list/core/design/night_theme.dart';
import 'package:shopping_list/core/design/stamp_ink.dart';
import 'package:shopping_list/core/design/theme.dart';
import 'package:shopping_list/core/design/tokens.dart';

/// Every colour the calendar paints. Moving to a shared night palette later
/// only touches this file.
abstract final class Night {
  static const Color ground = HomePalette.ground;
  static const Color tile = HomePalette.tile;
  static const Color mist = HomePalette.mist;
  static const Color bone = HomePalette.bone;
  static const Color ink = HomePalette.ink;
  static const Color line = HomePalette.line;

  /// Half-hour rules and column seams. Present, never read.
  static const Color hairline = Color(0x0DFFFFFF);

  /// Fields and wells inside the drawer, one step above [tile].
  static const Color well = Color(0xFF1E1E21);

  /// A soft overlap. Personal calendars allow it; this only says so.
  static const Color caution = Color(0xFFE3B65E);

  static const Color danger = Color(0xFFE5776B);

  /// The ink an event is printed in: its own stamp, else its place's, else
  /// bone. Night paper takes the light pads.
  static Color inkOf(Ticket ticket, Place? place) {
    if (ticket.inkId != null) return StampInk.byId(ticket.inkId).dark;
    if (place != null) return place.ink.dark;
    return bone;
  }

  static Color cardFill(Color ink) =>
      Color.alphaBlend(ink.withValues(alpha: 0.20), tile);

  static Color cardEdge(Color ink) => ink.withValues(alpha: 0.9);
}

/// The shared night surface, finished for the calendar. Everything under it —
/// the drawer, the date picker, text fields — reads the same palette.
class NightTheme extends StatelessWidget {
  const NightTheme({super.key, required this.child});

  final Widget child;

  static const ThermalPalette palette = ThermalPalette(
    paper: Night.ground,
    paperShade: Night.tile,
    print: Night.bone,
    faded: Night.mist,
    carbon: Night.bone,
    perforation: Night.line,
    scorch: Color(0xFF3A3A3C),
    settled: Color(0xFF1C1C1F),
  );

  static ThemeData of(ThemeData base) {
    final night = nightTheme(base);
    return night.copyWith(
      brightness: Brightness.dark,
      extensions: [palette],
      colorScheme: const ColorScheme.dark(
        primary: Night.bone,
        onPrimary: Night.ink,
        secondary: Night.bone,
        onSecondary: Night.ink,
        surface: Night.tile,
        onSurface: Night.bone,
        surfaceContainerHigh: Night.well,
        error: Night.danger,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Night.ground,
        foregroundColor: Night.bone,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: Type.display.copyWith(fontSize: 22, color: Night.bone),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Night.well,
        hintStyle: Type.item.copyWith(color: Night.mist),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Space.lg,
          vertical: Space.md,
        ),
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide.none,
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide.none,
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide(color: Night.mist, width: 1),
        ),
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: Night.bone,
        selectionColor: Color(0x55F3F3F1),
        selectionHandleColor: Night.bone,
      ),
      snackBarTheme: night.snackBarTheme.copyWith(
        backgroundColor: Night.bone,
        contentTextStyle: Type.body.copyWith(color: Night.ink),
        actionTextColor: Night.ink,
      ),
      datePickerTheme: const DatePickerThemeData(
        backgroundColor: Night.tile,
        surfaceTintColor: Colors.transparent,
      ),
      timePickerTheme: const TimePickerThemeData(
        backgroundColor: Night.tile,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: Night.tile,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(data: of(Theme.of(context)), child: child);
  }
}
