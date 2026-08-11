import 'package:flutter/material.dart';

/// Thermal-receipt design tokens.
///
/// The palette is taken from the physical behaviour of thermal receipt paper:
/// a cool, faintly green off-white that darkens toward near-black under heat,
/// browning on its way through. That ramp is not decoration here — checking an
/// item off literally moves the row along it, so [ThermalPalette.burn] is the
/// single source of truth for both the animation and its end state.
@immutable
class ThermalPalette extends ThemeExtension<ThermalPalette> {
  const ThermalPalette({
    required this.paper,
    required this.paperShade,
    required this.print,
    required this.faded,
    required this.carbon,
    required this.perforation,
    required this.scorch,
  });

  /// Ground. Cool and slightly green — deliberately not a warm cream.
  final Color paper;

  /// Row banding and inset fields. One step down from [paper].
  final Color paperShade;

  /// Ink. Also the fully-burned state of the paper.
  final Color print;

  /// Secondary text — spent thermal, legible but receded.
  final Color faded;

  /// The only accent. Dusty carbon-copy violet, from duplicate-slip ink.
  /// Reserved for interactive and active states. Never decorative.
  final Color carbon;

  /// Perforation dots and tear edges.
  final Color perforation;

  /// The brown a receipt passes through before it goes black. Only ever seen
  /// mid-burn, which is exactly what keeps the animation from reading as a
  /// plain colour fade.
  final Color scorch;

  /// Light theme — a fresh receipt.
  static const ThermalPalette light = ThermalPalette(
    paper: Color(0xFFF2F3EE),
    paperShade: Color(0xFFE4E6DF),
    print: Color(0xFF2B2A26),
    faded: Color(0xFF8C8879),
    carbon: Color(0xFF5B4B8A),
    perforation: Color(0xFFC9CCC2),
    scorch: Color(0xFF9A8B6F),
  );

  /// Dark theme — the same materials, read in a dim kitchen.
  static const ThermalPalette dark = ThermalPalette(
    paper: Color(0xFF1C1B18),
    paperShade: Color(0xFF262521),
    print: Color(0xFFEDEEE8),
    faded: Color(0xFF8F8B7E),
    carbon: Color(0xFF9B8AD1),
    perforation: Color(0xFF3A3833),
    scorch: Color(0xFF7A6A50),
  );

  /// Background of a row at heat level [t] (0 = untouched paper, 1 = burned
  /// through). Passes through [scorch] so the transition browns before it
  /// blackens, the way real thermal paper does.
  Color burn(double t) {
    final c = t.clamp(0.0, 1.0);
    if (c <= 0.55) {
      return Color.lerp(paper, scorch, c / 0.55)!;
    }
    return Color.lerp(scorch, print, (c - 0.55) / 0.45)!;
  }

  /// Text colour on a row at heat level [t]. Inverts as the paper darkens, so
  /// the row stays readable the whole way through.
  Color burnInk(double t) {
    final c = t.clamp(0.0, 1.0);
    // Hold the ink dark until the paper is genuinely too dark for it, then
    // cross over. A linear lerp here would go muddy and unreadable mid-way.
    if (c <= 0.45) return print;
    return Color.lerp(print, paper, ((c - 0.45) / 0.55).clamp(0.0, 1.0))!;
  }

  @override
  ThermalPalette copyWith({
    Color? paper,
    Color? paperShade,
    Color? print,
    Color? faded,
    Color? carbon,
    Color? perforation,
    Color? scorch,
  }) {
    return ThermalPalette(
      paper: paper ?? this.paper,
      paperShade: paperShade ?? this.paperShade,
      print: print ?? this.print,
      faded: faded ?? this.faded,
      carbon: carbon ?? this.carbon,
      perforation: perforation ?? this.perforation,
      scorch: scorch ?? this.scorch,
    );
  }

  @override
  ThermalPalette lerp(ThermalPalette? other, double t) {
    if (other == null) return this;
    return ThermalPalette(
      paper: Color.lerp(paper, other.paper, t)!,
      paperShade: Color.lerp(paperShade, other.paperShade, t)!,
      print: Color.lerp(print, other.print, t)!,
      faded: Color.lerp(faded, other.faded, t)!,
      carbon: Color.lerp(carbon, other.carbon, t)!,
      perforation: Color.lerp(perforation, other.perforation, t)!,
      scorch: Color.lerp(scorch, other.scorch, t)!,
    );
  }
}

/// Convenience accessor. `context.thermal.carbon` reads better at call sites
/// than the full `Theme.of(context).extension<...>()!` incantation.
extension ThermalContext on BuildContext {
  ThermalPalette get thermal => Theme.of(this).extension<ThermalPalette>()!;
}

/// Spacing scale. Tight, because a receipt is tight.
abstract final class Space {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 20;
  static const double xl = 32;
  static const double xxl = 48;
}

/// Radius. Near-zero on paper surfaces, fully pilled on controls — the two
/// materials must never be confusable.
abstract final class Radii {
  /// Paper does not have rounded corners.
  static const Radius paper = Radius.zero;

  /// Controls are unmistakably controls.
  static const BorderRadius control = BorderRadius.all(Radius.circular(999));

  /// Receipt photos and other embedded media.
  static const BorderRadius media = BorderRadius.all(Radius.circular(4));
}

abstract final class Motion {
  /// The burn. Long enough to read as a physical process, short enough to
  /// fire thirty times in a shop without becoming a tax.
  static const Duration burn = Duration(milliseconds: 420);
  static const Duration quick = Duration(milliseconds: 160);
  static const Duration settle = Duration(milliseconds: 260);

  static const Curve heat = Curves.easeOutCubic;
}

/// Font families. Referenced by name so a swap happens in exactly one place.
///
/// Bricolage and Instrument Sans are variable fonts — see `Type` in theme.dart
/// for how weight is set on their `wght` axis.
abstract final class Fonts {
  static const String display = 'Bricolage';
  static const String body = 'Instrument';
  static const String mono = 'SpaceMono';
}
