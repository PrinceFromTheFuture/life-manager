import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:shopping_list/core/design/tokens.dart';

/// The shape of a command key: a plate with a printed edge, and on primary
/// keys a die-cut inner hairline — the mark a rubber stamp leaves on paper,
/// quiet enough to be hardware rather than a celebration.
///
/// Paper is square; inputs are pilled wells. This radius and the inner rule
/// are what make a button a key instead of either.
class InkPlateBorder extends OutlinedBorder {
  const InkPlateBorder({
    super.side = BorderSide.none,
    this.borderRadius = Radii.key,
    this.insetColor,
  });

  final BorderRadiusGeometry borderRadius;
  final Color? insetColor;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(side.width);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    final rrect = borderRadius.resolve(textDirection).toRRect(rect);
    return Path()..addRRect(rrect.deflate(side.width));
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    return Path()
      ..addRRect(borderRadius.resolve(textDirection).toRRect(rect));
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final resolved = borderRadius.resolve(textDirection);

    if (side.style == BorderStyle.solid && side.width > 0) {
      final rrect = resolved.toRRect(rect).deflate(side.width / 2);
      canvas.drawRRect(rrect, side.toPaint());
    }

    final inset = insetColor;
    if (inset == null || inset.a == 0) return;

    const insetPad = 4.0;
    final inner = rect.deflate(insetPad);
    if (inner.width <= 0 || inner.height <= 0) return;

    final shrink = insetPad - side.width / 2;
    final innerRadius = Radius.circular(
      math.max(0, resolved.topLeft.x - shrink),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(inner, innerRadius),
      Paint()
        ..color = inset
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  ShapeBorder scale(double t) {
    return InkPlateBorder(
      side: side.scale(t),
      borderRadius: borderRadius * t,
      insetColor: insetColor,
    );
  }

  @override
  OutlinedBorder copyWith({BorderSide? side}) {
    return InkPlateBorder(
      side: side ?? this.side,
      borderRadius: borderRadius,
      insetColor: insetColor,
    );
  }

  @override
  ShapeBorder? lerpFrom(ShapeBorder? a, double t) {
    if (a is InkPlateBorder) {
      return InkPlateBorder(
        side: BorderSide.lerp(a.side, side, t),
        borderRadius: BorderRadiusGeometry.lerp(
              a.borderRadius,
              borderRadius,
              t,
            ) ??
            borderRadius,
        insetColor: Color.lerp(a.insetColor, insetColor, t),
      );
    }
    return super.lerpFrom(a, t);
  }

  @override
  ShapeBorder? lerpTo(ShapeBorder? b, double t) {
    if (b is InkPlateBorder) {
      return InkPlateBorder(
        side: BorderSide.lerp(side, b.side, t),
        borderRadius: BorderRadiusGeometry.lerp(
              borderRadius,
              b.borderRadius,
              t,
            ) ??
            borderRadius,
        insetColor: Color.lerp(insetColor, b.insetColor, t),
      );
    }
    return super.lerpTo(b, t);
  }

  @override
  bool operator ==(Object other) {
    return other is InkPlateBorder &&
        other.side == side &&
        other.borderRadius == borderRadius &&
        other.insetColor == insetColor;
  }

  @override
  int get hashCode => Object.hash(side, borderRadius, insetColor);
}

/// Shared sizes so a lone plate (add, step) matches a themed [FilledButton].
abstract final class Plate {
  static const double height = 54;
  static const EdgeInsets padding = EdgeInsets.symmetric(
    horizontal: Space.lg,
    vertical: Space.md,
  );

  /// Printed edge on an inked primary key.
  static Color edge(ThermalPalette p) =>
      Color.lerp(p.carbon, p.print, 0.38)!;

  /// Die-cut hairline inside a primary key. [onInk] is the label colour.
  static Color inset(Color onInk) => onInk.withValues(alpha: 0.28);
}

/// A compact inked plate — the add control beside a field, a stepper.
///
/// Same material as a [FilledButton], for places a Material button would be
/// the wrong size or would only hold an icon.
class InkPlate extends StatelessWidget {
  const InkPlate({
    super.key,
    required this.onPressed,
    required this.child,
    this.primary = true,
    this.size,
    this.semanticLabel,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final bool primary;
  final Size? size;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;
    final enabled = onPressed != null;
    final light = Theme.of(context).brightness == Brightness.light;
    final onInk = light ? palette.paper : palette.print;

    final fill = primary
        ? (enabled ? palette.carbon : palette.carbon.withValues(alpha: 0.38))
        : (enabled
            ? palette.paperShade
            : palette.paperShade.withValues(alpha: 0.5));
    final edge = primary
        ? Plate.edge(palette).withValues(alpha: enabled ? 1 : 0.38)
        : palette.print.withValues(alpha: enabled ? 1 : 0.35);

    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticLabel,
      child: Material(
        color: fill,
        shape: InkPlateBorder(
          borderRadius: Radii.key,
          side: BorderSide(color: edge, width: 1.5),
          insetColor: primary && enabled ? Plate.inset(onInk) : null,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          overlayColor: WidgetStatePropertyAll(
            palette.scorch.withValues(alpha: 0.22),
          ),
          customBorder: InkPlateBorder(
            borderRadius: Radii.key,
            side: BorderSide(color: edge, width: 1.5),
          ),
          child: SizedBox(
            width: size?.width,
            height: size?.height ?? Plate.height,
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}
