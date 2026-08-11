// FontVariation comes through material.dart; see Type below for why the
// variable-font axes are set explicitly.
import 'package:flutter/material.dart';

import 'tokens.dart';

/// The type scale.
///
/// Three faces, three jobs, no overlap. Bricolage is the display voice and is
/// used sparingly — screen titles and the checkout total, nothing else.
/// Instrument Sans carries every readable sentence. Space Mono owns anything
/// numeric, because receipt printers are dot-matrix descendants and because
/// monospace is the only way price columns actually line up.
abstract final class Type {
  /// Bricolage and Instrument Sans ship as variable fonts, where weight lives
  /// on the `wght` axis. `fontWeight` alone is honoured inconsistently across
  /// platforms for variable faces, so every style below sets both — otherwise
  /// the app renders at a flat regular weight on some devices and looks
  /// nothing like the design.
  static const TextStyle display = TextStyle(
    fontFamily: Fonts.display,
    fontSize: 34,
    height: 1.05,
    letterSpacing: -0.8,
    fontWeight: FontWeight.w700,
    // Slightly condensed: titles hold more of a long list name on one line,
    // and the narrower cut is where Bricolage's character actually shows.
    fontVariations: [FontVariation('wght', 700), FontVariation('wdth', 92)],
  );

  /// The checkout total — the one number the whole trip resolves to.
  static const TextStyle totalDisplay = TextStyle(
    fontFamily: Fonts.mono,
    fontSize: 44,
    height: 1.0,
    letterSpacing: -1.5,
    fontWeight: FontWeight.w700,
  );

  /// Section headers on paper. Small, spaced, uppercase at call sites.
  static const TextStyle eyebrow = TextStyle(
    fontFamily: Fonts.mono,
    fontSize: 11,
    height: 1.2,
    letterSpacing: 1.6,
    fontWeight: FontWeight.w700,
  );

  /// An item name in the list.
  static const TextStyle item = TextStyle(
    fontFamily: Fonts.body,
    fontSize: 17,
    height: 1.25,
    letterSpacing: -0.1,
    fontWeight: FontWeight.w500,
    fontVariations: [FontVariation('wght', 500)],
  );

  /// An item name in Pick-Up Mode — read at arm's length, one-handed.
  static const TextStyle itemLarge = TextStyle(
    fontFamily: Fonts.body,
    fontSize: 22,
    height: 1.2,
    letterSpacing: -0.2,
    fontWeight: FontWeight.w600,
    fontVariations: [FontVariation('wght', 600)],
  );

  static const TextStyle body = TextStyle(
    fontFamily: Fonts.body,
    fontSize: 15,
    height: 1.45,
    fontWeight: FontWeight.w400,
    fontVariations: [FontVariation('wght', 400)],
  );

  /// Quantities, dates, counters, prices.
  static const TextStyle mono = TextStyle(
    fontFamily: Fonts.mono,
    fontSize: 14,
    height: 1.2,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle monoBold = TextStyle(
    fontFamily: Fonts.mono,
    fontSize: 14,
    height: 1.2,
    fontWeight: FontWeight.w700,
  );

  /// Captions and helper text.
  static const TextStyle caption = TextStyle(
    fontFamily: Fonts.body,
    fontSize: 13,
    height: 1.35,
    fontWeight: FontWeight.w400,
    fontVariations: [FontVariation('wght', 400)],
  );

  static const TextStyle button = TextStyle(
    fontFamily: Fonts.body,
    fontSize: 15,
    height: 1.1,
    letterSpacing: 0.1,
    fontWeight: FontWeight.w600,
    fontVariations: [FontVariation('wght', 600)],
  );
}

ThemeData buildTheme(ThermalPalette p, Brightness brightness) {
  final scheme = ColorScheme(
    brightness: brightness,
    primary: p.carbon,
    onPrimary: brightness == Brightness.light ? p.paper : p.print,
    secondary: p.carbon,
    onSecondary: brightness == Brightness.light ? p.paper : p.print,
    // Errors speak in ink, not in a colour we otherwise never use. The one
    // exception is destructive confirmation, where red is genuinely earned.
    error: const Color(0xFFB3382A),
    onError: const Color(0xFFF2F3EE),
    surface: p.paper,
    onSurface: p.print,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: p.paper,
    canvasColor: p.paper,
    extensions: <ThemeExtension<dynamic>>[p],
    fontFamily: Fonts.body,
    splashFactory: InkSparkle.splashFactory,

    textTheme: TextTheme(
      displayLarge: Type.display.copyWith(color: p.print),
      titleLarge: Type.display.copyWith(fontSize: 22, color: p.print),
      bodyLarge: Type.item.copyWith(color: p.print),
      bodyMedium: Type.body.copyWith(color: p.print),
      bodySmall: Type.caption.copyWith(color: p.faded),
      labelLarge: Type.button.copyWith(color: p.print),
      labelSmall: Type.eyebrow.copyWith(color: p.faded),
    ),

    // Paper has no elevation and no rounded corners.
    appBarTheme: AppBarTheme(
      backgroundColor: p.paper,
      foregroundColor: p.print,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: Type.display.copyWith(fontSize: 22, color: p.print),
    ),

    dividerTheme: DividerThemeData(color: p.perforation, thickness: 1, space: 1),

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: p.carbon,
        foregroundColor: brightness == Brightness.light ? p.paper : p.print,
        textStyle: Type.button,
        minimumSize: const Size(0, 52),
        padding: const EdgeInsets.symmetric(horizontal: Space.lg),
        shape: const RoundedRectangleBorder(borderRadius: Radii.control),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: p.print,
        textStyle: Type.button,
        minimumSize: const Size(0, 52),
        padding: const EdgeInsets.symmetric(horizontal: Space.lg),
        side: BorderSide(color: p.print, width: 1.5),
        shape: const RoundedRectangleBorder(borderRadius: Radii.control),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: p.carbon,
        textStyle: Type.button,
        minimumSize: const Size(0, 44),
      ),
    ),

    // Inset fields read as pressed into the paper, not floated above it.
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.paperShade,
      hintStyle: Type.item.copyWith(color: p.faded),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: Space.lg,
        vertical: Space.md,
      ),
      border: const OutlineInputBorder(
        borderRadius: Radii.control,
        borderSide: BorderSide.none,
      ),
      enabledBorder: const OutlineInputBorder(
        borderRadius: Radii.control,
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: Radii.control,
        borderSide: BorderSide(color: p.carbon, width: 2),
      ),
    ),

    snackBarTheme: SnackBarThemeData(
      backgroundColor: p.print,
      contentTextStyle: Type.body.copyWith(color: p.paper),
      actionTextColor: p.carbon == ThermalPalette.light.carbon
          ? const Color(0xFFB9A8F0)
          : p.carbon,
      behavior: SnackBarBehavior.floating,
      shape: const RoundedRectangleBorder(borderRadius: Radii.control),
    ),

    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.paper,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
    ),

    // Dialogs are styled at their single call site rather than here: the
    // theme-level class was renamed between Flutter versions (DialogTheme ->
    // DialogThemeData), and there is exactly one dialog in this app.

    listTileTheme: ListTileThemeData(
      iconColor: p.faded,
      textColor: p.print,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
    ),
  );
}

ThemeData get lightTheme => buildTheme(ThermalPalette.light, Brightness.light);
ThemeData get darkTheme => buildTheme(ThermalPalette.dark, Brightness.dark);
