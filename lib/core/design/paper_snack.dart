import 'dart:async';

import 'package:flutter/material.dart';

import 'package:shopping_list/core/design/theme.dart';
import 'package:shopping_list/core/design/tokens.dart';

/// Root navigator. [showPaperSnack] uses its overlay so a snack can still
/// appear after the screen that triggered it has popped.
final GlobalKey<NavigatorState> paperSnackNavigatorKey =
    GlobalKey<NavigatorState>();

/// A snack that drops in under the status bar, not up from the home indicator.
///
/// Material's [SnackBar] is hard-wired to the bottom of the scaffold. Every
/// call site goes through here so the whole product agrees.
void showPaperSnack(
  BuildContext context, {
  required String message,
  String? actionLabel,
  VoidCallback? onAction,
}) {
  _PaperSnack.show(
    context,
    message: message,
    actionLabel: actionLabel,
    onAction: onAction,
  );
}

void hidePaperSnacks() => _PaperSnack.hide();

class _PaperSnack {
  static OverlayEntry? _entry;
  static Timer? _timer;

  static void show(
    BuildContext context, {
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    hide();

    final overlay = _overlay(context);
    if (overlay == null) return;

    final theme = _theme(context);
    final duration = actionLabel == null
        ? const Duration(seconds: 4)
        : const Duration(seconds: 6);

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _PaperSnackBar(
        message: message,
        actionLabel: actionLabel,
        theme: theme,
        onAction: onAction == null
            ? null
            : () {
                hide();
                onAction();
              },
        onDismissed: () {
          if (_entry == entry) hide();
        },
      ),
    );

    _entry = entry;
    overlay.insert(entry);
    _timer = Timer(duration, hide);
  }

  static void hide() {
    _timer?.cancel();
    _timer = null;
    final entry = _entry;
    _entry = null;
    if (entry != null && entry.mounted) entry.remove();
  }

  static OverlayState? _overlay(BuildContext context) {
    return paperSnackNavigatorKey.currentState?.overlay ??
        (context.mounted ? Overlay.of(context, rootOverlay: true) : null);
  }

  static ThemeData _theme(BuildContext context) {
    if (context.mounted) return Theme.of(context);
    final nav = paperSnackNavigatorKey.currentContext;
    if (nav != null) return Theme.of(nav);
    return ThemeData();
  }
}

class _PaperSnackBar extends StatefulWidget {
  const _PaperSnackBar({
    required this.message,
    required this.theme,
    required this.onDismissed,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final ThemeData theme;
  final VoidCallback onDismissed;

  @override
  State<_PaperSnackBar> createState() => _PaperSnackBarState();
}

class _PaperSnackBarState extends State<_PaperSnackBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Motion.settle,
  )..forward();

  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, -1),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _controller, curve: Motion.heat));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final snack = widget.theme.snackBarTheme;
    final contentStyle = snack.contentTextStyle ??
        TextStyle(color: widget.theme.colorScheme.surface);

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: ClipRect(
          child: SlideTransition(
            position: _slide,
            child: Padding(
              padding:
                  const EdgeInsets.fromLTRB(Space.md, Space.sm, Space.md, 0),
              child: Dismissible(
                key: const ValueKey('paper-snack'),
                direction: DismissDirection.up,
                onDismissed: (_) => widget.onDismissed(),
                child: Material(
                  color: snack.backgroundColor ??
                      widget.theme.colorScheme.onSurface,
                  elevation: 0,
                  shape: snack.shape ??
                      const RoundedRectangleBorder(
                        borderRadius: Radii.control,
                      ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Space.lg,
                      Space.md,
                      Space.sm,
                      Space.md,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(widget.message, style: contentStyle),
                        ),
                        if (widget.actionLabel != null)
                          TextButton(
                            onPressed: widget.onAction,
                            child: Text(
                              widget.actionLabel!,
                              style: Type.button.copyWith(
                                color: snack.actionTextColor,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
