import 'package:flutter/material.dart';

import 'package:shopping_list/core/app/mini_app.dart';
import 'package:shopping_list/core/design/ink_scope.dart';
import 'package:shopping_list/core/design/theme.dart';
import 'package:shopping_list/core/design/tokens.dart';

/// The row of mini-apps.
///
/// Each app is a **stub** — the torn-off counterfoil of a slip — rather than a
/// rounded icon tile, so the launcher belongs to the same paper world as
/// everything else. The ink bar down the left edge is the app's only colour,
/// and it is the same mark that identifies its rows in the feed below, so the
/// association is learned once.
class Launcher extends StatelessWidget {
  const Launcher({super.key, required this.apps});

  final List<MiniApp> apps;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.lg),
      child: Row(
        children: [
          for (final app in apps) ...[
            Expanded(child: _AppStub(app: app)),
            if (app != apps.last) const SizedBox(width: Space.md),
          ],
        ],
      ),
    );
  }
}

class _AppStub extends StatelessWidget {
  const _AppStub({required this.app});

  final MiniApp app;

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;
    final brightness = Theme.of(context).brightness;
    final ink = app.ink.of(brightness);

    return Semantics(
      button: true,
      label: 'Open ${app.name}',
      child: Material(
        color: palette.paperShade,
        // Paper has no rounded corners; only controls do. A stub is paper.
        borderRadius: BorderRadius.zero,
        child: InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => InkScope(
                ink: app.ink,
                child: Builder(builder: app.buildHome),
              ),
            ),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 4, color: ink),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Space.md,
                      Space.md,
                      Space.md,
                      Space.md,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(app.icon, size: 22, color: ink),
                        const SizedBox(height: Space.md),
                        Text(
                          app.name,
                          style: Type.item.copyWith(color: palette.print),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
