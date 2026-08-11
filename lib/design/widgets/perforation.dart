import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../tokens.dart';

/// The divider used between rows.
///
/// Dots rather than a solid hairline: a solid rule reads as a table, and a
/// table is not what a receipt is. This is also the detail that keeps the
/// layout from collapsing into a generic broadsheet look.
class PerforatedRule extends StatelessWidget {
  const PerforatedRule({
    super.key,
    this.dotRadius = 0.9,
    this.gap = 5,
    this.indent = 0,
    this.color,
  });

  final double dotRadius;
  final double gap;
  final double indent;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: indent),
      child: CustomPaint(
        size: const Size(double.infinity, 1),
        painter: _PerforationPainter(
          color: color ?? context.thermal.perforation,
          dotRadius: dotRadius,
          gap: gap,
        ),
      ),
    );
  }
}

class _PerforationPainter extends CustomPainter {
  const _PerforationPainter({
    required this.color,
    required this.dotRadius,
    required this.gap,
  });

  final Color color;
  final double dotRadius;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final step = dotRadius * 2 + gap;
    final count = (size.width / step).floor();
    // Distribute the remainder so the run of dots is centred rather than
    // trailing off short on the right.
    final inset = (size.width - (count - 1) * step) / 2;

    for (var i = 0; i < count; i++) {
      canvas.drawCircle(
        Offset(inset + i * step, size.height / 2),
        dotRadius,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_PerforationPainter old) =>
      old.color != color || old.dotRadius != dotRadius || old.gap != gap;
}

/// The torn edge that separates what's still to buy from what's already in the
/// cart.
///
/// This is the structural half of the app's signature: the tear line isn't
/// decoration sitting at a fixed spot, it moves down the list as items are
/// checked off, so its position *is* the progress indicator. There is no
/// separate progress bar because this already is one.
class TearEdge extends StatelessWidget {
  const TearEdge({
    super.key,
    this.amplitude = 4,
    this.wavelength = 11,
    this.color,
  });

  final double amplitude;
  final double wavelength;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;
    return CustomPaint(
      size: Size(double.infinity, amplitude * 2 + 2),
      painter: _TearPainter(
        color: color ?? palette.perforation,
        amplitude: amplitude,
        wavelength: wavelength,
      ),
    );
  }
}

class _TearPainter extends CustomPainter {
  const _TearPainter({
    required this.color,
    required this.amplitude,
    required this.wavelength,
  });

  final Color color;
  final double amplitude;
  final double wavelength;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeJoin = StrokeJoin.miter;

    // A fixed seed keeps the tear identical across rebuilds. Re-randomising
    // every frame would make the edge shimmer, which reads as a rendering bug
    // rather than as torn paper.
    final random = math.Random(7);
    final path = Path();
    final midY = size.height / 2;

    path.moveTo(0, midY);
    var x = 0.0;
    var up = true;
    while (x < size.width) {
      x += wavelength / 2;
      final jitter = (random.nextDouble() - 0.5) * amplitude * 0.5;
      path.lineTo(
        math.min(x, size.width),
        midY + (up ? -amplitude : amplitude) + jitter,
      );
      up = !up;
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_TearPainter old) =>
      old.color != color ||
      old.amplitude != amplitude ||
      old.wavelength != wavelength;
}
