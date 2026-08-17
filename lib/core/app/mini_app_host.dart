import 'package:flutter/material.dart';

import 'package:shopping_list/core/app/mini_app.dart';
import 'package:shopping_list/core/design/ink_scope.dart';
import 'package:shopping_list/core/design/slip_route.dart';

/// Runs one mini-app inside its own navigation stack and its own ink.
///
/// The nested [Navigator] is what makes per-app ink actually hold. Wrapping
/// only the app's home screen is not enough: a pushed `MaterialPageRoute`
/// builds under whichever Navigator owns it, and the root Navigator sits
/// *above* the [InkScope] — so every pushed screen silently reverted to the
/// default accent. That showed up on device as a violet control inside the blue
/// Receipts app, and it would have recurred in every app added later.
///
/// With the Navigator *inside* the scope, everything an app pushes inherits its
/// ink automatically and there is nothing for a future module to remember.
class MiniAppHost extends StatefulWidget {
  const MiniAppHost({super.key, required this.app, this.initialScreen});

  final MiniApp app;

  /// Opens straight to this screen instead of the app's home — used by hub
  /// quick actions, so "Add expense" lands on the sheet rather than on the
  /// list with the sheet stacked on top of it.
  final WidgetBuilder? initialScreen;

  @override
  State<MiniAppHost> createState() => _MiniAppHostState();
}

class _MiniAppHostState extends State<MiniAppHost> {
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return InkScope(
      ink: widget.app.ink,
      // The system back gesture has to unwind the app's own stack first, and
      // only leave the mini-app once that stack is empty. Without this, back
      // from a detail screen would drop you all the way to the hub.
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          final navigator = _navigatorKey.currentState;
          if (navigator != null && navigator.canPop()) {
            navigator.pop();
          } else {
            Navigator.of(context).pop();
          }
        },
        child: Navigator(
          key: _navigatorKey,
          onGenerateRoute: (settings) => MaterialPageRoute<void>(
            settings: settings,
            builder: (context) =>
                widget.initialScreen?.call(context) ??
                widget.app.buildHome(context),
          ),
        ),
      ),
    );
  }
}

/// Opens a mini-app on the hub's navigator, inside its own ink.
///
/// Feed taps, launcher stubs and quick actions all go through here so a
/// detail opened from the hub is not painted in the shell's colourless ink.
Future<T?> openMiniApp<T>(
  BuildContext context,
  MiniApp app, {
  WidgetBuilder? initialScreen,
  bool fullscreenDialog = false,
}) {
  return Navigator.of(context).push<T>(
    SlipRoute(
      fullscreenDialog: fullscreenDialog,
      builder: (_) => MiniAppHost(app: app, initialScreen: initialScreen),
    ),
  );
}
