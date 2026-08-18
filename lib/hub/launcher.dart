import 'package:flutter/material.dart';

import 'package:shopping_list/core/app/mini_app.dart';
import 'package:shopping_list/core/app/mini_app_host.dart';
import 'package:shopping_list/core/design/paper_snack.dart';
import 'package:shopping_list/core/design/theme.dart';
import 'package:shopping_list/core/design/tokens.dart';

/// The hub's way into the mini-apps: a 2×3 cluster, not a scrolling strip.
///
/// Six slots, always. Live apps fill from the top-left; anything left is
/// **Coming soon**. The cluster reads as one block that has been scored into
/// tiles — outer corners of the block are open (large radius), corners that
/// face a neighbour are tight. Tiles do not touch; the gap is the score line.
class Launcher extends StatelessWidget {
  const Launcher({super.key, required this.apps});

  final List<MiniApp> apps;

  static const int _columns = 2;
  static const int _rows = 3;
  static const int _slots = _columns * _rows;

  /// Width / height. Wider than square — the empty 1:1 tile was the problem.
  static const double _aspect = 1.4; //1.1

  /// Corners that form the silhouette of the whole block.
  static const double _outer = 22;

  /// Corners that sit next to another tile.
  static const double _inner = 8;

  static const double _gap = 8;

  @override
  Widget build(BuildContext context) {
    final slots = <_Slot>[
      for (final app in apps.take(_slots)) _Slot.app(app),
      for (var i = apps.length; i < _slots; i++) const _Slot.soon(),
    ];

    return Padding(
      padding:
          const EdgeInsets.fromLTRB(Space.lg, Space.xl, Space.lg, Space.lg),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tileWidth =
              (constraints.maxWidth - _gap * (_columns - 1)) / _columns;

          return Column(
            children: [
              for (var row = 0; row < _rows; row++) ...[
                Row(
                  children: [
                    for (var col = 0; col < _columns; col++) ...[
                      SizedBox(
                        width: tileWidth,
                        child: AspectRatio(
                          aspectRatio: _aspect,
                          child: _Tile(
                            slot: slots[row * _columns + col],
                            radius: _radiusFor(row: row, col: col),
                          ),
                        ),
                      ),
                      if (col != _columns - 1) const SizedBox(width: _gap),
                    ],
                  ],
                ),
                if (row != _rows - 1) const SizedBox(height: _gap),
              ],
            ],
          );
        },
      ),
    );
  }

  static BorderRadius _radiusFor({required int row, required int col}) {
    final top = row == 0;
    final bottom = row == _rows - 1;
    final left = col == 0;
    final right = col == _columns - 1;

    Radius corner(bool outer) => Radius.circular(outer ? _outer : _inner);

    return BorderRadius.only(
      topLeft: corner(top && left),
      topRight: corner(top && right),
      bottomLeft: corner(bottom && left),
      bottomRight: corner(bottom && right),
    );
  }
}

class _Slot {
  const _Slot.app(this.app) : soon = false;
  const _Slot.soon()
      : app = null,
        soon = true;

  final MiniApp? app;
  final bool soon;

  String get title => app?.name ?? 'Coming soon';

  String get tagline => app?.tagline ?? 'Not in this build yet.';
}

class _Tile extends StatelessWidget {
  const _Tile({required this.slot, required this.radius});

  final _Slot slot;
  final BorderRadius radius;

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;
    final app = slot.app;
    final brightness = Theme.of(context).brightness;
    final ink = app?.ink.of(brightness) ?? palette.faded;

    return Semantics(
      button: !slot.soon,
      label: slot.soon
          ? 'Coming soon. ${slot.tagline}'
          : 'Open ${slot.title}. ${slot.tagline}',
      child: Material(
        color: palette.paperShade,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: slot.soon
              ? () => showPaperSnack(
                    context,
                    message: 'Not in this build yet.',
                  )
              : () => openMiniApp(context, app!),
          child: Padding(
            padding: const EdgeInsets.all(Space.lg - 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _IconWell(
                  icon: app?.icon ?? Icons.more_horiz,
                  fill: slot.soon ? palette.perforation : ink,
                  glyph: slot.soon ? palette.faded : palette.paper,
                ),
                const SizedBox(height: Space.xs),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      slot.title,
                      style: Type.item.copyWith(
                        color: slot.soon ? palette.faded : palette.print,
                        fontFamily: Fonts.display,
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      slot.tagline,
                      style: Type.caption.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: palette.faded,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The app's ink, as a small pad the icon sits on — not a floating glyph.
class _IconWell extends StatelessWidget {
  const _IconWell({
    required this.icon,
    required this.fill,
    required this.glyph,
  });

  final IconData icon;
  final Color fill;
  final Color glyph;

  static const double _radius = 8;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(_radius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Space.sm),
        child: Icon(icon, size: 19, color: glyph),
      ),
    );
  }
}
