import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shopping_list/apps/calendar/data/clock.dart';
import 'package:shopping_list/apps/calendar/data/expand/days.dart';
import 'package:shopping_list/apps/calendar/data/models/place.dart';
import 'package:shopping_list/apps/calendar/data/models/ticket.dart';
import 'package:shopping_list/apps/calendar/state/providers.dart';
import 'package:shopping_list/apps/calendar/ui/board/day_board.dart';
import 'package:shopping_list/apps/calendar/ui/board/week_board.dart';
import 'package:shopping_list/apps/calendar/ui/board/week_rail.dart';
import 'package:shopping_list/apps/calendar/ui/event_sheet.dart';
import 'package:shopping_list/apps/receipts/ui/ledger_plate.dart';
import 'package:shopping_list/core/design/paper_snack.dart';
import 'package:shopping_list/core/design/theme.dart';
import 'package:shopping_list/core/design/tokens.dart';
import 'package:shopping_list/core/design/widgets/perforation.dart';

class BoardSection extends ConsumerStatefulWidget {
  const BoardSection({super.key, this.initialDay});

  final DateTime? initialDay;

  @override
  ConsumerState<BoardSection> createState() => _BoardSectionState();
}

class _Lift {
  _Lift({
    required this.ticket,
    required this.start,
    required this.duration,
    required this.originY,
  });

  final Ticket ticket;
  DateTime start;
  int duration;
  final double originY;
}

class _BoardSectionState extends ConsumerState<BoardSection> {
  late DateTime _day;
  final _scroll = ScrollController();
  final _railKey = GlobalKey();
  final _boardKey = GlobalKey();
  _Lift? _lift;
  DateTime? _hoverDay;
  bool _didScroll = false;
  bool _pinching = false;
  bool _confirming = false;
  double _hourHeight = DayBoard.defaultHourHeight;
  double _pinchBase = DayBoard.defaultHourHeight;
  double _pinchOffset = 0;
  double _pinchFocal = 0;
  Timer? _nudge;
  final _pointers = <int, Offset>{};
  double? _pinchSpan;

  @override
  void initState() {
    super.initState();
    _day = Days.startOfDay(widget.initialDay ?? DateTime.now());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(boardDayProvider.notifier).state = _day;
    });
  }

  void _setDay(DateTime day) {
    final next = Days.startOfDay(day);
    setState(() {
      _day = next;
      _didScroll = false;
    });
    ref.read(boardDayProvider.notifier).state = next;
  }

  @override
  void dispose() {
    _nudge?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToRelevant(List<Ticket> tickets) {
    if (_didScroll || !_scroll.hasClients) return;
    _didScroll = true;
    final now = DateTime.now();
    final minutes = tickets.isEmpty
        ? (Days.isSameDay(_day, now) ? Days.minutesOf(now) - 60 : 8 * 60)
        : Days.minutesOf(tickets.first.startsAt) - 30;
    final offset = (minutes / 60) * _hourHeight;
    _scroll.jumpTo(offset.clamp(0, _scroll.position.maxScrollExtent));
  }

  DateTime? _dayUnder(Offset global) {
    final grain = ref.read(boardGrainProvider);
    if (grain == BoardGrain.week) {
      final box = _boardKey.currentContext?.findRenderObject() as RenderBox?;
      if (box == null) return null;
      final local = box.globalToLocal(global);
      if (local.dx < DayBoard.gutter ||
          local.dx > box.size.width ||
          local.dy < 0 ||
          local.dy > box.size.height) {
        return null;
      }
      final inner = local.dx - DayBoard.gutter;
      final width = box.size.width - DayBoard.gutter;
      final i = (inner / (width / 7)).floor().clamp(0, 6);
      return Days.weekOf(_day)[i];
    }
    final box = _railKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return null;
    final local = box.globalToLocal(global);
    if (local.dy < 0 ||
        local.dy > box.size.height ||
        local.dx < 0 ||
        local.dx > box.size.width) {
      return null;
    }
    final i = (local.dx / (box.size.width / 7)).floor().clamp(0, 6);
    return Days.weekOf(_day)[i];
  }

  void _onLongPress(Ticket ticket, LongPressStartDetails details) {
    HapticFeedback.mediumImpact();
    setState(() {
      _lift = _Lift(
        ticket: ticket,
        start: ticket.startsAt,
        duration: ticket.durationMinutes,
        originY: details.globalPosition.dy,
      );
      _hoverDay = Days.startOfDay(ticket.startsAt);
    });
  }

  void _armNudge(int direction) {
    if (_nudge != null) return;
    _nudge = Timer.periodic(const Duration(milliseconds: 650), (_) {
      if (!mounted || _lift == null) {
        _nudge?.cancel();
        _nudge = null;
        return;
      }
      HapticFeedback.selectionClick();
      final grain = ref.read(boardGrainProvider);
      final step = grain == BoardGrain.week ? 7 : 1;
      final next = _day.add(Duration(days: direction * step));
      final lift = _lift!;
      setState(() {
        _day = Days.startOfDay(next);
        ref.read(boardDayProvider.notifier).state = _day;
        lift.start = Days.atMinutes(next, Days.minutesOf(lift.start));
        _hoverDay = _day;
      });
    });
  }

  void _cancelNudge() {
    _nudge?.cancel();
    _nudge = null;
  }

  void _onPointerDown(PointerDownEvent event) {
    _pointers[event.pointer] = event.position;
  }

  void _onPointerMove(PointerMoveEvent event) {
    _pointers[event.pointer] = event.position;
    if (_lift == null && _pointers.length == 2 && !_confirming) {
      final pts = _pointers.values.toList();
      final span = (pts[0] - pts[1]).distance;
      if (_pinchSpan == null) {
        _pinchSpan = span;
        _pinchBase = _hourHeight;
        _pinchOffset = _scroll.hasClients ? _scroll.offset : 0;
        final box = _boardKey.currentContext?.findRenderObject() as RenderBox?;
        _pinchFocal = box == null
            ? 0
            : box.globalToLocal(event.position).dy;
        _pinching = true;
        return;
      }
      final next = (_pinchBase * (span / _pinchSpan!)).clamp(
        DayBoard.minHourHeight,
        DayBoard.maxHourHeight,
      );
      final contentY = _pinchOffset + _pinchFocal;
      final newOffset = contentY * (next / _pinchBase) - _pinchFocal;
      setState(() => _hourHeight = next);
      if (_scroll.hasClients) {
        _scroll.jumpTo(
          newOffset.clamp(0.0, _scroll.position.maxScrollExtent),
        );
      }
      return;
    }

    final lift = _lift;
    if (lift == null || _confirming) return;
    final dy = event.position.dy - lift.originY;
    final deltaMinutes = (dy / _hourHeight * 60).round();

    final box = _boardKey.currentContext?.findRenderObject() as RenderBox?;
    if (box != null) {
      final local = box.globalToLocal(event.position);
      const edge = 28.0;
      if (local.dx < edge) {
        _armNudge(-1);
      } else if (local.dx > box.size.width - edge) {
        _armNudge(1);
      } else {
        _cancelNudge();
      }
    }

    final hover = _dayUnder(event.position);
    final tentative = lift.ticket.startsAt.add(Duration(minutes: deltaMinutes));
    final day = hover ?? Days.startOfDay(tentative);
    final minutes = Days.snapMinutes(Days.minutesOf(tentative));
    setState(() {
      _hoverDay = hover ?? day;
      lift.start = Days.atMinutes(day, minutes);
    });
  }

  void _onPointerUp(PointerUpEvent event) {
    _pointers.remove(event.pointer);
    if (_pointers.length < 2) {
      _pinchSpan = null;
      _pinching = false;
    }
    if (_lift != null && _pointers.isEmpty) unawaited(_onPointerUpLift());
  }

  Future<void> _onPointerUpLift() async {
    _cancelNudge();
    final lift = _lift;
    if (lift == null || _confirming) return;
    final moved = lift.start != lift.ticket.startsAt ||
        lift.duration != lift.ticket.durationMinutes;
    if (!moved) {
      setState(() {
        _lift = null;
        _hoverDay = null;
      });
      return;
    }

    _confirming = true;
    final ok = await showDialog<bool>(
      context: context,
      useRootNavigator: false,
      builder: (context) {
        final palette = context.thermal;
        return AlertDialog(
          backgroundColor: palette.paper,
          surfaceTintColor: Colors.transparent,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          titleTextStyle:
              Type.display.copyWith(fontSize: 20, color: palette.print),
          contentTextStyle: Type.body.copyWith(color: palette.print),
          title: Text('Move ${lift.ticket.title}?'),
          content: Text(
            '${Clock.day(lift.start)}  ${Clock.span(lift.start, lift.duration)}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Keep'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Move'),
            ),
          ],
        );
      },
    );
    _confirming = false;
    if (!mounted) return;
    if (ok != true) {
      setState(() {
        _lift = null;
        _hoverDay = null;
      });
      return;
    }

    await ref.read(calendarControllerProvider).reschedule(
          lift.ticket,
          startsAt: lift.start,
          durationMinutes: lift.duration,
        );
    if (!mounted) return;
    setState(() {
      _lift = null;
      _hoverDay = null;
    });
    if (lift.ticket.fromRegistry) {
      showPaperSnack(
        context,
        message: 'This time. The series is unchanged.',
      );
    }
    if (!Days.isSameDay(lift.start, _day)) {
      _setDay(lift.start);
    }
  }

  void _swipe(DragEndDetails details) {
    if (_lift != null || _pinching) return;
    final v = details.primaryVelocity ?? 0;
    if (v.abs() < 200) return;
    final grain = ref.read(boardGrainProvider);
    final step = grain == BoardGrain.week ? 7 : 1;
    if (v < 0) {
      _setDay(_day.add(Duration(days: step)));
    } else {
      _setDay(_day.subtract(Duration(days: step)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;
    final grain = ref.watch(boardGrainProvider);
    final ticketsAsync = grain == BoardGrain.week
        ? ref.watch(weekTicketsProvider(_day))
        : ref.watch(dayTicketsProvider(_day));
    final places = {
      for (final place in ref.watch(placesProvider).valueOrNull ?? const <Place>[])
        if (place.id != null) place.id!: place,
    };

    return Listener(
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      onPointerCancel: (event) {
        _pointers.remove(event.pointer);
        _pinchSpan = null;
        _pinching = false;
        _cancelNudge();
        if (_lift != null && !_confirming) {
          setState(() {
            _lift = null;
            _hoverDay = null;
          });
        }
      },
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.lg, Space.sm, Space.lg, Space.sm),
            child: Row(
              children: [
                LedgerPlate(
                  label: 'Day',
                  selected: grain == BoardGrain.day,
                  onTap: () =>
                      ref.read(boardGrainProvider.notifier).state = BoardGrain.day,
                ),
                const SizedBox(width: Space.sm),
                LedgerPlate(
                  label: 'Week',
                  selected: grain == BoardGrain.week,
                  onTap: () =>
                      ref.read(boardGrainProvider.notifier).state = BoardGrain.week,
                ),
              ],
            ),
          ),
          KeyedSubtree(
            key: _railKey,
            child: WeekRail(
              anchor: _day,
              selected: _day,
              hover: _hoverDay,
              onSelected: _setDay,
            ),
          ),
          if (_lift != null) _LiftPreview(lift: _lift!),
          const PerforatedRule(),
          Expanded(
            child: ticketsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text(
                  '$e',
                  style: Type.caption.copyWith(color: palette.faded),
                ),
              ),
              data: (items) {
                final shown = _applyLift(items);
                WidgetsBinding.instance
                    .addPostFrameCallback((_) => _scrollToRelevant(shown));
                return GestureDetector(
                  onHorizontalDragEnd: _swipe,
                  child: KeyedSubtree(
                    key: _boardKey,
                    child: grain == BoardGrain.week
                        ? WeekBoard(
                            anchor: _day,
                            tickets: shown,
                            places: places,
                            controller: _scroll,
                            hourHeight: _hourHeight,
                            liftKey: _lift?.ticket.key,
                            onTap: (ticket) =>
                                EventSheet.open(context, ticket: ticket),
                            onBlankTap: (at) =>
                                EventSheet.open(context, startsAt: at),
                            onLongPressStart: _onLongPress,
                          )
                        : DayBoard(
                            day: _day,
                            tickets: shown,
                            places: places,
                            controller: _scroll,
                            hourHeight: _hourHeight,
                            liftKey: _lift?.ticket.key,
                            onTap: (ticket) =>
                                EventSheet.open(context, ticket: ticket),
                            onBlankTap: (at) =>
                                EventSheet.open(context, startsAt: at),
                            onLongPressStart: _onLongPress,
                          ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<Ticket> _applyLift(List<Ticket> items) {
    final lift = _lift;
    if (lift == null) return items;
    final moved = lift.ticket.copyWith(
      startsAt: lift.start,
      durationMinutes: lift.duration,
    );
    final rest = [
      for (final ticket in items)
        if (ticket.key != lift.ticket.key) ticket,
    ];
    return [...rest, moved];
  }
}

class _LiftPreview extends StatelessWidget {
  const _LiftPreview({required this.lift});

  final _Lift lift;

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;
    return Container(
      width: double.infinity,
      color: palette.paperShade,
      padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: 8),
      child: Text(
        '${Clock.day(lift.start)}   ${Clock.span(lift.start, lift.duration)}',
        style: Type.monoBold.copyWith(color: palette.print, fontSize: 13),
        textAlign: TextAlign.center,
      ),
    );
  }
}
