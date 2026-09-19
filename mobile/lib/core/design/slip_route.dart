import 'package:flutter/material.dart';

import 'package:shopping_list/core/design/tokens.dart';

/// How a mini-app arrives: a slip feeding out of the printer, not a
/// generic page sliding in from the side.
///
/// Used for every entry into a mini-app — launcher, feed tap, quick action —
/// so "opening an app" is one learned motion.
class SlipRoute<T> extends PageRouteBuilder<T> {
  SlipRoute({
    required WidgetBuilder builder,
    super.settings,
    super.fullscreenDialog,
  }) : super(
          transitionDuration: Motion.settle,
          reverseTransitionDuration: Motion.quick,
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final reduce = MediaQuery.disableAnimationsOf(context);
            if (reduce) return child;

            final curved = CurvedAnimation(
              parent: animation,
              curve: Motion.heat,
              reverseCurve: Curves.easeInCubic,
            );
            return FadeTransition(
              opacity: curved,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.04),
                  end: Offset.zero,
                ).animate(curved),
                child: child,
              ),
            );
          },
        );
}
