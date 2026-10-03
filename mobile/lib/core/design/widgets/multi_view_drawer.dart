import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutty_solar_icons/solar_icons_flutter.dart';

import 'package:shopping_list/core/design/theme.dart';
import 'package:shopping_list/core/design/tokens.dart';

/// One screen inside a [showMultiViewDrawer].
class DrawerView {
  const DrawerView({required this.builder, this.heightFactor});

  final WidgetBuilder builder;

  /// Fixed height as a fraction of the screen. Null follows the content.
  final double? heightFactor;
}

/// Stack navigation for the drawer a view sits in.
///
/// Views never push routes of their own: a deeper step is [push], coming back
/// is [pop], and the drawer animates its height to whatever the new view needs.
class MultiViewDrawer extends InheritedWidget {
  const MultiViewDrawer._({
    required _DrawerSheetState state,
    required this.depth,
    required this.current,
    required super.child,
  }) : _state = state;

  final _DrawerSheetState _state;

  /// Views on the stack, the current one included.
  final int depth;

  final String current;

  static MultiViewDrawer of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<MultiViewDrawer>();
    assert(scope != null, 'MultiViewDrawer.of used outside a drawer');
    return scope!;
  }

  static MultiViewDrawer? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MultiViewDrawer>();

  void push(String key) => _state._push(key);

  /// Back one view. On the first view this closes the drawer.
  void pop() => _state._pop();

  /// Swap the current view without growing the stack.
  void replace(String key) => _state._replace(key);

  /// Back to the nearest [key] below the current view.
  void popTo(String key) => _state._popTo(key);

  void close([Object? result]) => _state._close(result);

  void dragUpdate(DragUpdateDetails details) => _state._dragUpdate(details);

  void dragEnd(DragEndDetails details) => _state._dragEnd(details);

  @override
  bool updateShouldNotify(MultiViewDrawer old) =>
      old.depth != depth || old.current != current;
}

/// A bottom drawer that swaps between views in place.
///
/// The motion is vaul's: half a second on its own ease, dismissed by dragging
/// the handle or a view header past a quarter of the height or with a quick
/// flick. Inner scrollables keep their gestures, so a time grid inside the
/// drawer scrolls instead of closing it.
///
/// The drawer inherits the caller's theme, so it is night inside a night app
/// without the app having to say so.
Future<T?> showMultiViewDrawer<T>({
  required BuildContext context,
  required Map<String, DrawerView> views,
  required String initial,
}) {
  assert(views.containsKey(initial), 'No drawer view named $initial');
  final navigator = Navigator.of(context);
  final themes = InheritedTheme.capture(from: context, to: navigator.context);
  return navigator.push<T>(
    _DrawerRoute<T>(
      views: views,
      initial: initial,
      themes: themes,
      reduced: MediaQuery.disableAnimationsOf(context),
    ),
  );
}

const Cubic _ease = Cubic(0.32, 0.72, 0, 1);
const Duration _slide = Duration(milliseconds: 500);
const Duration _morph = Duration(milliseconds: 220);
const Duration _swap = Duration(milliseconds: 150);
const double _swapShift = 20;
const double _closeFraction = 0.25;

/// vaul's velocity threshold, 0.4 px/ms.
const double _closeVelocity = 400;
const double _maxFraction = 0.94;
const double _inset = 8;
const double _radius = 28;

class _DrawerRoute<T> extends PopupRoute<T> {
  _DrawerRoute({
    required this.views,
    required this.initial,
    required this.themes,
    required this.reduced,
  });

  final Map<String, DrawerView> views;
  final String initial;
  final CapturedThemes themes;
  final bool reduced;

  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => false;

  @override
  String? get barrierLabel => null;

  @override
  Duration get transitionDuration => reduced ? Duration.zero : _slide;

  @override
  Duration get reverseTransitionDuration => reduced ? Duration.zero : _slide;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return themes.wrap(_DrawerSheet(route: this));
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) =>
      child;
}

class _DrawerSheet extends StatefulWidget {
  const _DrawerSheet({required this.route});

  final _DrawerRoute<dynamic> route;

  @override
  State<_DrawerSheet> createState() => _DrawerSheetState();
}

class _DrawerSheetState extends State<_DrawerSheet>
    with SingleTickerProviderStateMixin {
  late final List<String> _stack = [widget.route.initial];
  final _sheetKey = GlobalKey();
  bool _forward = true;
  bool _closing = false;
  double _drag = 0;

  late final AnimationController _settle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  )..addListener(() => setState(() => _drag = _settleFrom * (1 - _settleCurve)));
  double _settleFrom = 0;

  double get _settleCurve => _ease.transform(_settle.value);

  late final CurvedAnimation _shown = CurvedAnimation(
    parent: widget.route.animation!,
    curve: _ease,
    reverseCurve: _ease.flipped,
  );

  @override
  void dispose() {
    _shown.dispose();
    _settle.dispose();
    super.dispose();
  }

  void _push(String key) {
    assert(widget.route.views.containsKey(key), 'No drawer view named $key');
    setState(() {
      _forward = true;
      _stack.add(key);
    });
  }

  void _pop() {
    if (_stack.length <= 1) {
      _close(null);
      return;
    }
    setState(() {
      _forward = false;
      _stack.removeLast();
    });
  }

  void _replace(String key) {
    setState(() {
      _forward = true;
      _stack[_stack.length - 1] = key;
    });
  }

  void _popTo(String key) {
    final index = _stack.lastIndexOf(key);
    if (index == -1 || index == _stack.length - 1) return;
    setState(() {
      _forward = false;
      _stack.removeRange(index + 1, _stack.length);
    });
  }

  void _close(Object? result) {
    if (_closing || !mounted) return;
    _closing = true;
    _settle.stop();
    Navigator.of(context).pop(result);
  }

  double get _sheetHeight {
    final box = _sheetKey.currentContext?.findRenderObject() as RenderBox?;
    return box?.hasSize == true ? box!.size.height : 400;
  }

  void _dragUpdate(DragUpdateDetails details) {
    if (_closing) return;
    _settle.stop();
    final dy = details.delta.dy;
    // Upward is allowed a little give, so the sheet does not feel welded.
    setState(() {
      _drag = _drag + dy < 0 ? math.max(-12.0, _drag + dy * 0.2) : _drag + dy;
    });
  }

  void _dragEnd(DragEndDetails details) {
    if (_closing) return;
    final velocity = details.velocity.pixelsPerSecond.dy;
    if (velocity >= _closeVelocity || _drag > _sheetHeight * _closeFraction) {
      HapticFeedback.selectionClick();
      _close(null);
      return;
    }
    _settleFrom = _drag;
    if (MediaQuery.disableAnimationsOf(context)) {
      setState(() => _drag = 0);
      return;
    }
    _settle.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;
    final media = MediaQuery.of(context);
    final reduced = media.disableAnimations;
    final key = _stack.last;
    final view = widget.route.views[key]!;
    final bottom =
        math.max(media.viewInsets.bottom, media.padding.bottom) + _inset;
    final available = media.size.height - media.padding.top - _inset - bottom;
    final maxHeight = math.max(0.0, available * _maxFraction);
    final factor = view.heightFactor;

    Widget body = KeyedSubtree(
      key: ValueKey('${_stack.length}:$key'),
      child: Builder(builder: view.builder),
    );
    if (factor != null) {
      body = SizedBox(
        height: math.min(maxHeight - 28, media.size.height * factor),
        child: body,
      );
    }

    final sheet = Material(
      key: _sheetKey,
      color: palette.paperShade,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(_radius)),
        side: BorderSide(color: palette.perforation),
      ),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Handle(onUpdate: _dragUpdate, onEnd: _dragEnd),
            Flexible(
              child: AnimatedSize(
                duration: reduced ? Duration.zero : _morph,
                curve: Curves.easeInOut,
                alignment: Alignment.topCenter,
                child: AnimatedSwitcher(
                  duration: reduced ? Duration.zero : _swap,
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  layoutBuilder: (current, previous) => Stack(
                    clipBehavior: Clip.hardEdge,
                    alignment: Alignment.topCenter,
                    children: [
                      // Outgoing views must not hold the height open, or the
                      // morph would wait for the fade to finish.
                      for (final child in previous)
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(maxHeight: maxHeight),
                            child: child,
                          ),
                        ),
                      if (current != null) current,
                    ],
                  ),
                  transitionBuilder: (child, animation) {
                    final incoming =
                        child.key == ValueKey('${_stack.length}:$key');
                    final sign = incoming == _forward ? 1.0 : -1.0;
                    return FadeTransition(
                      opacity: animation,
                      child: AnimatedBuilder(
                        animation: animation,
                        builder: (context, child) => Transform.translate(
                          offset: Offset(
                            _swapShift * sign * (1 - animation.value),
                            0,
                          ),
                          child: child,
                        ),
                        child: child,
                      ),
                    );
                  },
                  child: body,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return MultiViewDrawer._(
      state: this,
      depth: _stack.length,
      current: key,
      child: PopScope(
        canPop: _stack.length <= 1,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _pop();
        },
        child: AnimatedBuilder(
          animation: _shown,
          builder: (context, child) {
            final t = _shown.value.clamp(0.0, 1.0);
            final height = _sheetHeight;
            final dragFade = _drag <= 0 ? 1.0 : (1 - _drag / height).clamp(0.0, 1.0);
            final shade = t * dragFade;
            return Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _close(null),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 4 * shade, sigmaY: 4 * shade),
                      child: ColoredBox(
                        color: Colors.black.withValues(alpha: 0.10 * shade),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: _inset,
                  right: _inset,
                  bottom: bottom,
                  child: FractionalTranslation(
                    translation: Offset(0, 1 - _shown.value),
                    child: Transform.translate(
                      offset: Offset(0, _drag + (1 - _shown.value) * (bottom + _inset)),
                      child: child,
                    ),
                  ),
                ),
              ],
            );
          },
          child: sheet,
        ),
      ),
    );
  }
}

class _Handle extends StatelessWidget {
  const _Handle({required this.onUpdate, required this.onEnd});

  final GestureDragUpdateCallback onUpdate;
  final GestureDragEndCallback onEnd;

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragUpdate: onUpdate,
      onVerticalDragEnd: onEnd,
      child: SizedBox(
        height: 22,
        width: double.infinity,
        child: Center(
          child: Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: palette.faded.withValues(alpha: 0.45),
              borderRadius: const BorderRadius.all(Radius.circular(2)),
            ),
          ),
        ),
      ),
    );
  }
}

/// Title row for a drawer view. Carries a back affordance once the view is
/// deeper than the first, and drags the drawer like the handle does.
class DrawerViewHeader extends StatelessWidget {
  const DrawerViewHeader({
    super.key,
    required this.title,
    this.trailing,
    this.onBack,
  });

  final String title;
  final Widget? trailing;

  /// Overrides the default back, which pops one view.
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;
    final scope = MultiViewDrawer.of(context);
    final deep = scope.depth > 1;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragUpdate: scope.dragUpdate,
      onVerticalDragEnd: scope.dragEnd,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          deep ? Space.sm : Space.lg,
          0,
          Space.md,
          Space.md,
        ),
        child: SizedBox(
          height: 40,
          child: Row(
            children: [
              if (deep) ...[
                DrawerRoundButton(
                  icon: SolarIcons.AltArrowLeft,
                  label: 'Back',
                  onTap: onBack ?? scope.pop,
                ),
                const SizedBox(width: Space.sm),
              ],
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Type.display.copyWith(
                    fontSize: 22,
                    color: palette.print,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ),
    );
  }
}

/// The small round control drawer headers use.
class DrawerRoundButton extends StatelessWidget {
  const DrawerRoundButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.size = 36,
  });

  final SolarIconData icon;
  final String label;
  final VoidCallback? onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: palette.perforation,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: size,
            height: size,
            child: Center(
              child: SolarIcon(
                icon,
                weight: SolarIconWeight.linear,
                size: size * 0.5,
                color: onTap == null ? palette.faded : palette.print,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
