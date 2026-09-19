import 'package:flutter/material.dart';

import 'package:shopping_list/core/design/theme.dart';
import 'package:shopping_list/core/design/tokens.dart';
import 'package:shopping_list/core/design/widgets/perforation.dart';
import 'package:shopping_list/core/design/widgets/app_icon.dart';

/// Navigation inside an [showInsetDrawer] — lets a view swap the drawer's
/// contents without opening a new screen.
class DrawerScope extends InheritedWidget {
  const DrawerScope({
    super.key,
    required this.open,
    required this.back,
    required this.close,
    required this.isSecondary,
    required super.child,
  });

  /// Slide to a named secondary view.
  final void Function(String key) open;

  /// Return to the primary view.
  final VoidCallback back;

  /// Dismiss the drawer entirely.
  final VoidCallback close;

  final bool isSecondary;

  static DrawerScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<DrawerScope>();
    assert(scope != null, 'DrawerScope used outside of showInsetDrawer');
    return scope!;
  }

  @override
  bool updateShouldNotify(DrawerScope old) => old.isSecondary != isSecondary;
}

/// A drawer that floats clear of the screen edges and can swap between views
/// in place.
///
/// Two deliberate departures from a stock bottom sheet:
///
/// - **It is inset on all sides**, so it reads as a card resting above the app
///   rather than a panel welded to the bottom edge. That is what makes it feel
///   like a thing you can dismiss.
/// - **The grab handle is a perforated strip**, not the usual rounded pill. A
///   pill would be the one piece of generic mobile chrome in an interface built
///   entirely out of paper; a row of punch-holes is what the top of a receipt
///   pad actually looks like, and it reuses a device already used throughout.
///
/// Swapping views animates horizontally — the primary view leaves to the right,
/// secondary views arrive from the left — so the direction of travel says
/// whether you went deeper or came back.
Future<T?> showInsetDrawer<T>({
  required BuildContext context,
  required WidgetBuilder primary,
  Map<String, WidgetBuilder> views = const {},
}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.transparent,
    // The drawer draws its own surface, so the sheet itself must not.
    elevation: 0,
    isScrollControlled: true,
    // Stays inside the owning mini-app's ink; the root navigator sits above it.
    useRootNavigator: false,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (context) => _InsetDrawer(primary: primary, views: views),
  );
}

class _InsetDrawer extends StatefulWidget {
  const _InsetDrawer({required this.primary, required this.views});

  final WidgetBuilder primary;
  final Map<String, WidgetBuilder> views;

  @override
  State<_InsetDrawer> createState() => _InsetDrawerState();
}

class _InsetDrawerState extends State<_InsetDrawer> {
  String? _active;

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;
    final isSecondary = _active != null;
    final body = isSecondary ? widget.views[_active] : widget.primary;

    return DrawerScope(
      open: (key) => setState(() => _active = key),
      back: () => setState(() => _active = null),
      close: () => Navigator.of(context).pop(),
      isSecondary: isSecondary,
      child: Padding(
        padding: EdgeInsets.only(
          left: Space.md,
          right: Space.md,
          bottom: Space.md + MediaQuery.paddingOf(context).bottom,
          // Never let the drawer reach the status bar, however tall it grows.
          top: MediaQuery.paddingOf(context).top + Space.xxl,
        ),
        child: Material(
          color: palette.paper,
          // Enough to read as a floating card; far short of the fully rounded
          // sheet that would make it generic.
          borderRadius: const BorderRadius.all(Radius.circular(16)),
          clipBehavior: Clip.antiAlias,
          child: SafeArea(
            top: false,
            bottom: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: Space.md),
                // The handle: a short run of punch-holes.
                const SizedBox(
                  width: 48,
                  child: PerforatedRule(dotRadius: 1.4, gap: 5),
                ),
                const SizedBox(height: Space.sm),
                Flexible(
                  child: AnimatedSize(
                    duration: Motion.quick,
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.topCenter,
                    child: AnimatedSwitcher(
                      duration: Motion.quick,
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      layoutBuilder: (current, previous) => Stack(
                        alignment: Alignment.topCenter,
                        children: [...previous, if (current != null) current],
                      ),
                      transitionBuilder: (child, animation) {
                        // Direction of travel encodes depth: forward slides in
                        // from the right, back from the left.
                        final incoming =
                            child.key == ValueKey(_active ?? '__primary__');
                        final sign = isSecondary
                            ? (incoming ? 1.0 : -1.0)
                            : (incoming ? -1.0 : 1.0);
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: Offset(0.06 * sign, 0),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        );
                      },
                      child: KeyedSubtree(
                        key: ValueKey(_active ?? '__primary__'),
                        child: body?.call(context) ?? const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: Space.md),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Header for a secondary drawer view: a back affordance and a title.
class DrawerViewHeader extends StatelessWidget {
  const DrawerViewHeader({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;
    final scope = DrawerScope.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.sm, 0, Space.lg, Space.sm),
      child: Row(
        children: [
          IconButton(
            icon: const AppIcon(SolarIcons.AltArrowLeft, size: 20),
            tooltip: 'Back',
            onPressed: scope.back,
          ),
          const SizedBox(width: Space.xs),
          Text(
            title,
            style: Type.display.copyWith(fontSize: 20, color: palette.print),
          ),
        ],
      ),
    );
  }
}
