import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutty_solar_icons/solar_icons_flutter.dart';

import 'package:shopping_list/apps/home/ui/home_palette.dart';
import 'package:shopping_list/core/design/tokens.dart';

class HomeNavItem {
  const HomeNavItem({required this.icon, required this.label});

  final SolarIconData icon;
  final String label;
}

/// Black bar. The bone pill swings to the selected app and its name fades in.
class HomeNavBar extends StatefulWidget {
  const HomeNavBar({
    super.key,
    required this.items,
    required this.index,
    required this.onChanged,
  });

  static const double barHeight = 40;
  static const double verticalPadding = 10;

  /// Height of the painted bar, including the system gesture inset it covers.
  static double occupiedHeight(BuildContext context) =>
      MediaQuery.paddingOf(context).bottom + verticalPadding * 2 + barHeight;

  final List<HomeNavItem> items;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  State<HomeNavBar> createState() => _HomeNavBarState();
}

class _HomeNavBarState extends State<HomeNavBar>
    with SingleTickerProviderStateMixin {
  static const _swingDuration = Duration(milliseconds: 280);
  static const _labelDuration = Duration(milliseconds: 200);
  static const _labelDelay = Duration(milliseconds: 80);
  static const _glyph = 20.0;
  static const _idlePad = 8.0;
  static const _activePad = 12.0;

  static const _labelStyle = TextStyle(
    fontFamily: Fonts.body,
    fontSize: 13,
    height: 1,
    letterSpacing: 0.1,
    fontWeight: FontWeight.w600,
    fontVariations: [FontVariation('wght', 600)],
    color: HomePalette.ink,
  );

  late final AnimationController _swing;
  late final List<double> _labelWidths;
  late List<double> _openFrom;

  int _current = 0;
  Rect? _fromRect;
  Rect? _pill;
  var _moved = false;

  @override
  void initState() {
    super.initState();
    _current = widget.index;
    _openFrom = [
      for (var i = 0; i < widget.items.length; i++) i == _current ? 1.0 : 0.0,
    ];
    _swing = AnimationController(
      vsync: this,
      duration: _swingDuration,
      value: 1,
    );
    _labelWidths = [
      for (final item in widget.items) _measure(item.label),
    ];
  }

  @override
  void didUpdateWidget(HomeNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) _swingTo(widget.index);
  }

  @override
  void dispose() {
    _swing.dispose();
    super.dispose();
  }

  double _measure(String text) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: _labelStyle),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    return painter.width;
  }

  double _swung() => Curves.easeOutCubic.transform(_swing.value);

  double _open(int index) {
    final t = _swung().clamp(0.0, 1.0);
    final target = index == _current ? 1.0 : 0.0;
    return lerpDouble(_openFrom[index], target, t)!;
  }

  void _swingTo(int index) {
    if (index == _current && !_swing.isAnimating) return;
    final t = _swung().clamp(0.0, 1.0);
    final captured = <double>[
      for (var i = 0; i < widget.items.length; i++)
        lerpDouble(_openFrom[i], i == _current ? 1.0 : 0.0, t)!,
    ];
    setState(() {
      _openFrom = captured;
      _fromRect = _pill;
      _current = index;
      _moved = true;
    });
    if (MediaQuery.disableAnimationsOf(context)) {
      _swing.value = 1;
      return;
    }
    _swing.forward(from: 0);
  }

  List<int> get _flexes => [
        4,
        for (var i = 0; i < widget.items.length - 1; i++) 2,
        4,
      ];

  _NavFrame _frame(double maxWidth, List<double> opens) {
    final widths = <double>[
      for (var i = 0; i < widget.items.length; i++) _slotWidth(i, opens[i]),
    ];
    final used = widths.fold<double>(0, (sum, width) => sum + width);
    final free = math.max(0.0, maxWidth - used);
    final flexes = _flexes;
    final flexTotal = flexes.fold<int>(0, (sum, flex) => sum + flex);
    final unit = flexTotal == 0 ? 0.0 : free / flexTotal;

    final slots = <_NavSlotBox>[];
    var x = flexes.first * unit;
    for (var i = 0; i < widths.length; i++) {
      final pad = lerpDouble(_idlePad, _activePad, opens[i])!;
      slots.add(_NavSlotBox(left: x, width: widths[i], pad: pad));
      x += widths[i];
      if (i != widths.length - 1) x += flexes[i + 1] * unit;
    }
    return _NavFrame(slots);
  }

  double _slotWidth(int index, double open) {
    final pad = lerpDouble(_idlePad, _activePad, open)!;
    return pad * 2 + _glyph + open * (6 + _labelWidths[index]);
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: HomePalette.ground,
        border: Border(top: BorderSide(color: HomePalette.line)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: HomeNavBar.verticalPadding,
          ),
          child: AnimatedBuilder(
            animation: _swing,
            builder: (context, _) {
              return LayoutBuilder(
                builder: (context, constraints) {
                  final liveOpens = [
                    for (var i = 0; i < widget.items.length; i++) _open(i),
                  ];
                  final live = _frame(constraints.maxWidth, liveOpens);
                  final restOpens = [
                    for (var i = 0; i < widget.items.length; i++)
                      i == _current ? 1.0 : 0.0,
                  ];
                  final rest = _frame(constraints.maxWidth, restOpens);
                  final dest = rest.slots[_current].rect;
                  final from = _fromRect ?? dest;
                  final pill = Rect.lerp(from, dest, _swung())!;
                  _pill = pill;

                  return SizedBox(
                    height: HomeNavBar.barHeight,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        _SwingingPill(
                          controller: _swing,
                          from: from,
                          to: dest,
                        ),
                        for (var i = 0; i < widget.items.length; i++)
                          _NavButton(
                            item: widget.items[i],
                            box: live.slots[i],
                            open: liveOpens[i],
                            labelWidth: _labelWidths[i],
                            selected: i == _current,
                            introSettled: !_moved && i == _current,
                            tone: _tone(
                              index: i,
                              open: liveOpens[i],
                              box: live.slots[i],
                              pill: pill,
                            ),
                            showLabel: liveOpens[i] > 0.01 ||
                                i == _current ||
                                (_swing.isAnimating && _openFrom[i] > 0.01),
                            onTap: () => widget.onChanged(i),
                          ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  double _tone({
    required int index,
    required double open,
    required _NavSlotBox box,
    required Rect pill,
  }) {
    final icon = Rect.fromLTWH(
      box.left + box.pad,
      0,
      _glyph,
      HomeNavBar.barHeight,
    );
    final overlap =
        math.min(pill.right, icon.right) - math.max(pill.left, icon.left);
    final cover =
        icon.width <= 0 ? 0.0 : (overlap / icon.width).clamp(0.0, 1.0);
    return index == _current ? math.max(cover, open) : cover;
  }
}

class _NavFrame {
  const _NavFrame(this.slots);
  final List<_NavSlotBox> slots;
}

class _NavSlotBox {
  const _NavSlotBox({
    required this.left,
    required this.width,
    required this.pad,
  });

  final double left;
  final double width;
  final double pad;

  Rect get rect => Rect.fromLTWH(left, 0, width, HomeNavBar.barHeight);
}

class _SwingingPill extends StatelessWidget {
  const _SwingingPill({
    required this.controller,
    required this.from,
    required this.to,
  });

  final AnimationController controller;
  final Rect from;
  final Rect to;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: const DecoratedBox(
        decoration: BoxDecoration(
          color: HomePalette.bone,
          borderRadius: BorderRadius.all(Radius.circular(999)),
        ),
      ).animate(controller: controller, autoPlay: false).custom(
            duration: _HomeNavBarState._swingDuration,
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              final rect = Rect.lerp(from, to, value)!;
              return Stack(
                fit: StackFit.expand,
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: rect.left,
                    width: math.max(rect.width, 0),
                    top: 0,
                    bottom: 0,
                    child: child,
                  ),
                ],
              );
            },
          ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.box,
    required this.open,
    required this.labelWidth,
    required this.selected,
    required this.introSettled,
    required this.tone,
    required this.showLabel,
    required this.onTap,
  });

  final HomeNavItem item;
  final _NavSlotBox box;
  final double open;
  final double labelWidth;
  final bool selected;
  final bool introSettled;
  final double tone;
  final bool showLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = Color.lerp(HomePalette.mist, HomePalette.ink, tone)!;

    return Positioned(
      left: box.left,
      width: box.width,
      top: 0,
      bottom: 0,
      child: Semantics(
        button: true,
        selected: selected,
        label: item.label,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(999),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: box.pad),
              child: Row(
                children: [
                  SolarIcon(
                    item.icon,
                    weight: SolarIconWeight.linear,
                    color: color,
                    size: _HomeNavBarState._glyph,
                  ),
                  if (showLabel)
                    SizedBox(
                      width: open * (6 + labelWidth),
                      child: ClipRect(
                        child: OverflowBox(
                          alignment: Alignment.centerLeft,
                          minWidth: 0,
                          maxWidth: 6 + labelWidth,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(width: 6),
                              Text(item.label,
                                      style: _HomeNavBarState._labelStyle)
                                  .animate(
                                    key: ValueKey('nav-label-${item.label}'),
                                    target: selected ? 1 : 0,
                                    value: introSettled ? 1 : null,
                                    autoPlay: false,
                                  )
                                  .fade(
                                    delay: _HomeNavBarState._labelDelay,
                                    duration: _HomeNavBarState._labelDuration,
                                    begin: 0,
                                    end: 1,
                                    curve: Curves.easeOut,
                                  )
                                  .slideX(
                                    delay: _HomeNavBarState._labelDelay,
                                    duration: _HomeNavBarState._labelDuration,
                                    begin: -0.2,
                                    end: 0,
                                    curve: Curves.easeOutCubic,
                                  ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
