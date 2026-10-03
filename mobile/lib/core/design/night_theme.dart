import 'package:flutter/material.dart';

import 'package:shopping_list/apps/home/ui/home_palette.dart';
import 'package:shopping_list/core/design/theme.dart';
import 'package:shopping_list/core/design/tokens.dart';

/// The Home night surface, laid over an app that already has its own ink.
///
/// Paper, type and fields go to the night ground. The app's carbon stays, so
/// a plot or a stamp keeps its accent. Primary buttons follow Home: bone fill,
/// ink text.
ThemeData nightTheme(ThemeData base) {
  final carbon = base.extension<ThermalPalette>()?.carbon ?? HomePalette.bone;
  const shape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(14)),
  );

  return base.copyWith(
    scaffoldBackgroundColor: HomePalette.ground,
    iconTheme: base.iconTheme.copyWith(color: HomePalette.bone),
    textTheme: base.textTheme.apply(
      bodyColor: HomePalette.bone,
      displayColor: HomePalette.bone,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: HomePalette.tile,
      surfaceTintColor: Colors.transparent,
      shape: shape,
      titleTextStyle: Type.display.copyWith(
        fontSize: 22,
        color: HomePalette.bone,
      ),
      contentTextStyle: Type.body.copyWith(color: HomePalette.mist),
    ),
    inputDecorationTheme: base.inputDecorationTheme.copyWith(
      fillColor: HomePalette.tile,
      hintStyle: Type.item.copyWith(color: HomePalette.mist),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
        borderSide: BorderSide(color: HomePalette.bone, width: 2),
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: HomePalette.ground,
      foregroundColor: HomePalette.bone,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: Type.display.copyWith(
        fontSize: 22,
        color: HomePalette.bone,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: HomePalette.bone,
        foregroundColor: HomePalette.ink,
        disabledBackgroundColor: HomePalette.bone.withValues(alpha: 0.38),
        disabledForegroundColor: HomePalette.ink.withValues(alpha: 0.45),
        textStyle: Type.button.copyWith(color: HomePalette.ink),
        minimumSize: const Size(0, 54),
        elevation: 0,
        shape: shape,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        backgroundColor: HomePalette.tile,
        foregroundColor: HomePalette.bone,
        disabledBackgroundColor: HomePalette.tile.withValues(alpha: 0.5),
        disabledForegroundColor: HomePalette.mist,
        textStyle: Type.button,
        minimumSize: const Size(0, 54),
        side: BorderSide.none,
        shape: shape,
      ),
    ),
    extensions: [
      ThermalPalette(
        paper: HomePalette.ground,
        paperShade: HomePalette.tile,
        print: HomePalette.bone,
        faded: HomePalette.mist,
        carbon: carbon,
        perforation: HomePalette.line,
        scorch: const Color(0xFFC4B08A),
        settled: const Color(0xFF1C1C1F),
      ),
    ],
  );
}
