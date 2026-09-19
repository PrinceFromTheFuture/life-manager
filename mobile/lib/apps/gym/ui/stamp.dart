import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:shopping_list/core/design/theme.dart';
import 'package:shopping_list/core/design/tokens.dart';
import 'package:shopping_list/core/util/load.dart';

/// The gym app's signature moment.
///
/// Groceries burns. Receipts print. This one **stamps**: a day-pass punch
/// lands on the set you just logged, holds long enough to read, and lifts.
/// It is the locker-tag mark, not a replay of either sibling.
///
/// Short, tappable to skip, and skipped entirely under reduced motion.
Future<void> showSetStamp(
  BuildContext context, {
  required String exercise,
  required int weightG,
  required int reps,
}) {
  if (MediaQuery.disableAnimationsOf(context)) return Future<void>.value();

  unawaited(HapticFeedback.mediumImpact());

  return Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.transparent,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: const Duration(milliseconds: 140),
      pageBuilder: (_, __, ___) => _SetStamp(
        exercise: exercise,
        weightG: weightG,
        reps: reps,
      ),
    ),
  );
}

class _SetStamp extends StatefulWidget {
  const _SetStamp({
    required this.exercise,
    required this.weightG,
    required this.reps,
  });

  final String exercise;
  final int weightG;
  final int reps;

  @override
  State<_SetStamp> createState() => _SetStampState();
}

class _SetStampState extends State<_SetStamp>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );

  Timer? _exit;

  @override
  void initState() {
    super.initState();
    _controller.forward();
    _exit = Timer(const Duration(milliseconds: 720), _close);
  }

  @override
  void dispose() {
    _exit?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _close() {
    _exit?.cancel();
    if (mounted && Navigator.of(context).canPop()) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;
    final ink = palette.carbon;

    return GestureDetector(
      onTap: _close,
      child: Material(
        color: palette.paper.withValues(alpha: 0.92),
        child: SafeArea(
          child: Center(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final t = Curves.easeOutBack.transform(_controller.value);
                final scale = 1.28 - 0.28 * t;
                final opacity = _controller.value.clamp(0.0, 1.0);
                return Opacity(
                  opacity: opacity,
                  child: Transform.rotate(
                    angle: -0.06 * (1 - t),
                    child: Transform.scale(
                      scale: scale,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(
                          Space.xl,
                          Space.lg,
                          Space.xl,
                          Space.lg,
                        ),
                        decoration: BoxDecoration(
                          color: palette.paper,
                          border: Border.all(color: ink, width: 3),
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: Space.lg,
                            vertical: Space.md,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: ink, width: 1),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'SET',
                                style: Type.eyebrow.copyWith(color: ink),
                              ),
                              const SizedBox(height: Space.sm),
                              Text(
                                widget.exercise.toUpperCase(),
                                style: Type.item.copyWith(color: palette.print),
                              ),
                              const SizedBox(height: Space.xs),
                              Text(
                                '${Load.format(widget.weightG)}  ×  ${widget.reps}',
                                style: Type.monoBold.copyWith(
                                  color: palette.print,
                                  fontSize: 18,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
