import 'package:flutter/material.dart';

import 'package:shopping_list/core/app/mini_app.dart';
import 'package:shopping_list/core/design/ink_scope.dart';
import 'package:shopping_list/core/design/night_theme.dart';
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
  const MiniAppHost({
    super.key,
    required this.app,
    this.initialScreen,
    this.interceptBack = true,
    this.onExit,
    this.onStackDepth,
    this.lifeBarInset,
  });

  final MiniApp app;

  /// Opens straight to this screen instead of the app's home — used by hub
  /// quick actions, so "Add expense" lands on the sheet rather than on the
  /// list with the sheet stacked on top of it.
  final WidgetBuilder? initialScreen;

  /// When this host is kept alive off-screen, it must not eat the system back
  /// that belongs to the visible page.
  final bool interceptBack;

  /// Called when this host's own stack is empty and the user goes back.
  /// The life shell uses it to wipe home. A pushed app leaves the route instead.
  final VoidCallback? onExit;

  /// How many routes this host is showing, including its home. The life shell
  /// hides the bar once a drawer or another screen is on top.
  final ValueChanged<int>? onStackDepth;

  /// Space reserved under the home route for the life bar. Pushed screens and
  /// drawers are not inset, so they cover that bar. Null when this host is
  /// itself a full-screen route and there is no bar underneath it.
  final double Function(BuildContext context)? lifeBarInset;

  @override
  State<MiniAppHost> createState() => _MiniAppHostState();
}

class _MiniAppHostState extends State<MiniAppHost> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  late final NavigatorObserver _depth = _StackDepth(_reportDepth);

  void _reportDepth(int depth) => widget.onStackDepth?.call(depth);

  @override
  Widget build(BuildContext context) {
    final navigator = Navigator(
      key: _navigatorKey,
      observers: [_depth],
      onGenerateRoute: (settings) => MaterialPageRoute<void>(
        settings: settings,
        builder: (context) {
          final home = widget.initialScreen?.call(context) ??
              widget.app.buildHome(context);
          final insetOf = widget.lifeBarInset;
          if (insetOf == null) return home;
          return _LifeBarSeat(insetOf: insetOf, child: home);
        },
      ),
    );

    final stack = widget.interceptBack
        ? PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, result) async {
              if (didPop) return;
              final inner = _navigatorKey.currentState;
              if (inner == null) {
                _leave(context);
                return;
              }
              // maybePop, not pop: a register keypad (or anything else that
              // owns a PopScope) must get the back the way the system keyboard
              // does, instead of the page underneath leaving.
              final handled = await inner.maybePop();
              if (!handled && context.mounted) _leave(context);
            },
            child: navigator,
          )
        : navigator;

    return InkScope(
      ink: widget.app.ink,
      // The system back gesture has to unwind the app's own stack first, and
      // only leave the mini-app once that stack is empty. Without this, back
      // from a detail screen would drop you all the way to the hub.
      child: Builder(
        builder: (context) {
          if (!widget.app.useNightTheme) return stack;
          return Theme(data: nightTheme(Theme.of(context)), child: stack);
        },
      ),
    );
  }

  void _leave(BuildContext context) {
    final exit = widget.onExit;
    if (exit != null) {
      exit();
      return;
    }
    Navigator.of(context).pop();
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

/// Keeps the app's home sitting above the life bar. Routes pushed later are
/// siblings of this seat, so they use the full screen and cover the bar.
class _LifeBarSeat extends StatelessWidget {
  const _LifeBarSeat({required this.insetOf, required this.child});

  final double Function(BuildContext context) insetOf;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return MediaQuery(
      data: media.copyWith(
        padding: media.padding.copyWith(bottom: 0),
        viewPadding: media.viewPadding.copyWith(bottom: 0),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: insetOf(context)),
        child: child,
      ),
    );
  }
}

class _StackDepth extends NavigatorObserver {
  _StackDepth(this._onDepth);

  final ValueChanged<int> _onDepth;
  var _depth = 0;

  void _emit() => _onDepth(_depth);

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _depth++;
    _emit();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (_depth > 0) _depth--;
    _emit();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (_depth > 0) _depth--;
    _emit();
  }
}
