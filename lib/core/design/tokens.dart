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
    required this.settled,
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

  /// The hot leading edge of the burn — the glow directly under the print
  /// head. Only ever seen mid-sweep, which is what keeps the animation from
  /// reading as a plain colour fade.
  final Color scorch;

  /// Where a burned row comes to rest.
  ///
  /// Deliberately close to [paper] rather than at full [print]. Testing the
  /// first build on a phone made the problem obvious: burning all the way to
  /// print made everything already in the trolley the highest-contrast thing
  /// on screen, which is backwards. What you still have to find is what
  /// matters. The sweep keeps the drama; the resting state gets out of the way.
  final Color settled;

  /// Light theme — a fresh receipt.
  static const ThermalPalette light = ThermalPalette(
    paper: Color(0xFFF2F3EE),
    paperShade: Color(0xFFE4E6DF),
    print: Color(0xFF2B2A26),
    faded: Color(0xFF8C8879),
    carbon: Color(0xFF5B4B8A),
    perforation: Color(0xFFC9CCC2),
    scorch: Color(0xFF9A8B6F),
    settled: Color(0xFFE2DBCA),
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
    settled: Color(0xFF2F2A20),
  );

  /// Background a row settles to once burned. The sweep itself is drawn by
  /// [ThermalSurface], which paints [scorch] as a moving leading edge over
  /// this.
  Color burnGround(double t) => Color.lerp(paper, settled, t.clamp(0.0, 1.0))!;

  /// Text colour at heat level [t]. Recedes toward [faded] rather than
  /// inverting — the row stays perfectly readable, it just stops competing
  /// with the things still to buy.
  Color burnInk(double t) =>
      Color.lerp(print, faded, t.clamp(0.0, 1.0))!;

  @override
  ThermalPalette copyWith({
    Color? paper,
    Color? paperShade,
    Color? print,
    Color? faded,
    Color? carbon,
    Color? perforation,
    Color? scorch,
    Color? settled,
  }) {
    return ThermalPalette(
      paper: paper ?? this.paper,
      paperShade: paperShade ?? this.paperShade,
      print: print ?? this.print,
      faded: faded ?? this.faded,
      carbon: carbon ?? this.carbon,
      perforation: perforation ?? this.perforation,
      scorch: scorch ?? this.scorch,
      settled: settled ?? this.settled,
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
      settled: Color.lerp(settled, other.settled, t)!,
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
