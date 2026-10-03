import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:shopping_list/apps/calendar/data/expand/days.dart';
import 'package:shopping_list/apps/calendar/data/expand/weekdays.dart';
import 'package:shopping_list/apps/calendar/data/models/block.dart';
import 'package:shopping_list/apps/calendar/data/models/place.dart';
import 'package:shopping_list/apps/calendar/data/models/series.dart';
import 'package:shopping_list/apps/calendar/data/models/ticket.dart';
import 'package:shopping_list/apps/calendar/state/providers.dart';
import 'package:shopping_list/apps/calendar/ui/calendar_screen.dart';
import 'package:shopping_list/apps/calendar/ui/drawer/event_drawer.dart';
import 'package:shopping_list/apps/calendar/ui/drawer/time_picker_view.dart';
import 'package:shopping_list/apps/calendar/ui/grid/grid_metrics.dart';
import 'package:shopping_list/core/settings/api_keys.dart';
import 'package:shopping_list/apps/calendar/ui/grid/week_grid.dart';
import 'package:shopping_list/apps/calendar/ui/grid/week_nav.dart';
import 'package:shopping_list/apps/calendar/ui/night.dart';
import 'package:shopping_list/apps/calendar/ui/week_strip.dart';
import 'package:shopping_list/core/design/paper_snack.dart';
import 'package:shopping_list/core/design/widgets/multi_view_drawer.dart';

/// A week that never contains today, so the grid opens on Sunday.
final DateTime _week = Days.startOfWeek(DateTime(2031, 3, 12));

final Finder _candidate = find.byWidgetPredicate(
  (w) =>
      w is Semantics &&
      (w.properties.label?.startsWith('Candidate time') ?? false),
);

List<Override> get _empty => [
      weekTicketsProvider.overrideWith((ref, week) async => const <Ticket>[]),
      monthTicketsProvider.overrideWith((ref, month) async => const <Ticket>[]),
      placesProvider.overrideWith((ref) async => const <Place>[]),
    ];

/// Writes are recorded rather than stored; the grid's own state is under test.
class _Recorder extends CalendarController {
  _Recorder(super.ref);

  DateTime? moved;
  int? movedMinutes;
  Ticket? undone;
  Block? added;

  @override
  Future<void> reschedule(
    Ticket ticket, {
    required DateTime startsAt,
    required int durationMinutes,
  }) async {
    moved = startsAt;
    movedMinutes = durationMinutes;
  }

  @override
  Future<void> undoMove(Ticket before) async => undone = before;

  @override
  Future<Block> addBlock({
    required String title,
    required DateTime startsAt,
    required int durationMinutes,
    int? locationId,
    String? note,
    String? inkId,
    String? iconId,
  }) async {
    return added = Block(
      id: 1,
      title: title,
      startsAt: startsAt,
      durationMinutes: durationMinutes,
      createdAt: DateTime.now(),
    );
  }
}

/// Strip over grid, the way the calendar screen stacks them.
class _Calendar extends StatefulWidget {
  const _Calendar({required this.onNav, this.onCreate});

  final ValueChanged<WeekNav> onNav;
  final Future<void> Function(DateTime start)? onCreate;

  @override
  State<_Calendar> createState() => _CalendarState();
}

class _CalendarState extends State<_Calendar> with TickerProviderStateMixin {
  late final WeekNav nav = WeekNav(vsync: this, week: _week);

  @override
  void initState() {
    super.initState();
    widget.onNav(nav);
  }

  @override
  void dispose() {
    nav.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        WeekStrip(
          key: const Key('strip'),
          nav: nav,
          loads: (_) => const [],
          onTapDay: (day) => nav.reveal(day),
        ),
        Expanded(
          child: WeekGrid(
            key: const Key('grid'),
            nav: nav,
            onOpenEvent: (_) {},
            onCreate: widget.onCreate ?? (_) async {},
          ),
        ),
      ],
    );
  }
}

Widget _app(Widget child, {bool reduced = false}) {
  return ProviderScope(
    overrides: _empty,
    child: MaterialApp(
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
          child: NightTheme(child: Scaffold(body: child)),
        ),
      ),
    ),
  );
}

Future<WeekNav> _pumpCalendar(WidgetTester tester,
    {bool reduced = false}) async {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  late WeekNav nav;
  await tester
      .pumpWidget(_app(_Calendar(onNav: (n) => nav = n), reduced: reduced));
  await tester.pumpAndSettle();
  return nav;
}

/// A slow drag across the grid body, slow enough that only distance counts.
Future<void> _pull(WidgetTester tester, double dx) async {
  final grid = tester.getRect(find.byKey(const Key('grid')));
  final gesture =
      await tester.startGesture(Offset(grid.center.dx, grid.center.dy));
  const steps = 40;
  for (var i = 0; i < steps; i++) {
    await gesture.moveBy(Offset(dx / steps, 0));
    await tester.pump(const Duration(milliseconds: 40));
  }
  await tester.pump(const Duration(milliseconds: 200));
  await gesture.up();
  await tester.pumpAndSettle();
}

void main() {
  group('edge pull', () {
    testWidgets('a long pull past Sunday pages back and lands on Saturday',
        (tester) async {
      final nav = await _pumpCalendar(tester);
      expect(nav.lens.value.firstDay, 0);

      await _pull(tester, 400);

      expect(nav.week, Days.addDays(_week, -7));
      final lens = nav.lens.value;
      expect(lens.shows(6), isTrue,
          reason: 'Saturday is the last column in view');
      expect(lens.start + lens.span, closeTo(7, 0.01));
    });

    testWidgets('pulling past Saturday pages forward and lands on Sunday',
        (tester) async {
      final nav = await _pumpCalendar(tester);
      await _pull(tester, 400);
      expect(nav.week, Days.addDays(_week, -7));

      await _pull(tester, -400);

      expect(nav.week, _week);
      expect(nav.lens.value.start, closeTo(0, 0.01));
    });

    testWidgets('a short pull springs back to the same week', (tester) async {
      final nav = await _pumpCalendar(tester);

      await _pull(tester, 40);

      expect(nav.week, _week);
      expect(nav.lens.value.start, closeTo(0, 0.01));
    });

    testWidgets('reduced motion switches the week without a slide',
        (tester) async {
      final nav = await _pumpCalendar(tester, reduced: true);
      final grid = tester.getRect(find.byKey(const Key('grid')));
      final gesture = await tester.startGesture(grid.center);
      for (var i = 0; i < 40; i++) {
        await gesture.moveBy(const Offset(10, 0));
        await tester.pump(const Duration(milliseconds: 40));
      }
      await tester.pump(const Duration(milliseconds: 200));
      await gesture.up();
      await tester.pump();

      expect(nav.week, Days.addDays(_week, -7));
      expect(nav.transitioning, isFalse);
    });
  });

  group('week strip', () {
    testWidgets('a light swipe turns the week', (tester) async {
      final nav = await _pumpCalendar(tester);
      final strip = tester.getRect(find.byKey(const Key('strip')));

      await tester.timedDragFrom(strip.center, const Offset(-60, 0),
          const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(nav.week, Days.addDays(_week, 7));

      await tester.timedDragFrom(
          strip.center, const Offset(60, 0), const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(nav.week, _week);
    });

    testWidgets('a nudge under the threshold stays put', (tester) async {
      final nav = await _pumpCalendar(tester);
      final strip = tester.getRect(find.byKey(const Key('strip')));

      await tester.timedDragFrom(strip.center, const Offset(-20, 0),
          const Duration(milliseconds: 800));
      await tester.pumpAndSettle();

      expect(nav.week, _week);
    });

    testWidgets('tapping a chip brings its column into view', (tester) async {
      final nav = await _pumpCalendar(tester);
      expect(nav.lens.value.shows(5), isFalse);

      await tester.tap(find.descendant(
          of: find.byKey(const Key('strip')),
          matching: find.text('${Days.addDays(_week, 5).day}')));
      await tester.pumpAndSettle();

      expect(nav.week, _week);
      expect(nav.lens.value.shows(5), isTrue);
    });
  });

  group('on the grid', () {
    _Recorder? recorder;
    late List<Ticket> tickets;

    Future<WeekNav> pumpWith(WidgetTester tester, List<Ticket> rows) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      addTearDown(hidePaperSnacks);
      tickets = rows;
      recorder = null;
      late WeekNav nav;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            weekTicketsProvider.overrideWith(
              (ref, week) async => week == _week ? tickets : const <Ticket>[],
            ),
            placesProvider.overrideWith((ref) async => const <Place>[]),
            calendarControllerProvider
                .overrideWith((ref) => recorder = _Recorder(ref)),
          ],
          child: MaterialApp(
            home: NightTheme(
              child: Scaffold(
                body: Builder(
                  builder: (context) => _Calendar(
                    onNav: (n) => nav = n,
                    onCreate: (start) =>
                        showEventDrawer(context, startsAt: start),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return nav;
    }

    /// Near the time the grid opens on, so the card is on screen.
    DateTime visibleStart() {
      final now = DateTime.now();
      final minutes =
          GridMetrics.snap(Days.minutesOf(now) - 30, 15).clamp(0, 22 * 60);
      return Days.atMinutes(_week, minutes);
    }

    testWidgets(
        'long-press lifts an event, a drag moves it, and Undo puts it back',
        (tester) async {
      final start = visibleStart();
      await pumpWith(tester, [
        Ticket(
          key: 'block:1',
          title: 'Standup',
          startsAt: start,
          originalStart: start,
          durationMinutes: 60,
          blockId: 1,
        ),
      ]);

      final card = tester.getCenter(find.text('Standup'));
      final gesture = await tester.startGesture(card);
      await tester.pump(const Duration(milliseconds: 300));
      // 72 px an hour: 36 px is half an hour.
      for (var i = 0; i < 6; i++) {
        await gesture.moveBy(const Offset(0, 6));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await tester.pumpAndSettle();

      expect(recorder!.moved, start.add(const Duration(minutes: 30)));
      expect(recorder!.movedMinutes, 60);
      expect(find.text('Undo'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(recorder!.undone?.key, 'block:1');
    });

    testWidgets('a quick tap on an event does not lift it', (tester) async {
      final start = visibleStart();
      await pumpWith(tester, [
        Ticket(
          key: 'block:2',
          title: 'Lunch',
          startsAt: start,
          originalStart: start,
          durationMinutes: 60,
          blockId: 2,
        ),
      ]);

      await tester.tap(find.text('Lunch'));
      await tester.pumpAndSettle();

      expect(recorder?.moved, isNull);
    });

    testWidgets('tapping empty time opens a new event there and saves a block',
        (tester) async {
      await pumpWith(tester, const []);

      final grid = tester.getRect(find.byKey(const Key('grid')));
      await tester
          .tapAt(Offset(grid.left + GridMetrics.gutter + 30, grid.top + 200));
      await tester.pumpAndSettle();

      expect(find.text('New event'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, 'Dentist');
      await tester.pump();
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      expect(recorder?.added?.title, 'Dentist');
      final at = recorder!.added!.startsAt;
      expect(Days.isSameDay(at, _week), isTrue);
      expect(Days.minutesOf(at) % 15, 0);
      expect(find.text('New event'), findsNothing);
    });
  });

  testWidgets('the screen and every drawer render without layout errors',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(hidePaperSnacks);
    final now = DateTime.now();
    final start = Days.atMinutes(
        now, GridMetrics.snap(Days.minutesOf(now) - 30, 15).clamp(0, 22 * 60));
    final routine = Series(
      id: 4,
      title: 'Gym',
      startMinutes: 7 * 60,
      durationMinutes: 60,
      weekdays: Weekdays.monday | Weekdays.thursday,
      startsOn: DateTime(2026),
      createdAt: DateTime(2026),
    );
    final place = Place(
      id: 9,
      title: 'Home',
      iconId: 'home',
      inkId: 'teal',
      latitude: 32.08,
      longitude: 34.78,
      createdAt: DateTime(2026),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          weekTicketsProvider.overrideWith(
            (ref, week) async => [
              Ticket(
                key: 'block:1',
                title: 'Standup',
                startsAt: start,
                originalStart: start,
                durationMinutes: 45,
                locationId: 9,
                note: 'Bring the plan',
                blockId: 1,
              ),
            ],
          ),
          monthTicketsProvider
              .overrideWith((ref, month) async => const <Ticket>[]),
          placesProvider.overrideWith((ref) async => [place]),
          seriesProvider.overrideWith((ref) async => [routine]),
          apiKeyStoreProvider.overrideWithValue(const _NoKeys()),
        ],
        child: const MaterialApp(home: CalendarScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Standup'), findsWidgets);

    Future<void> close() async {
      await tester.tapAt(const Offset(195, 30));
      await tester.pumpAndSettle();
    }

    await tester.tap(find.byWidgetPredicate((w) =>
        w is Semantics && w.properties.label?.endsWith('open month') == true));
    await tester.pumpAndSettle();
    expect(find.text('Today'), findsWidgets);
    await close();

    await tester.tap(find.bySemanticsLabel('Routines'));
    await tester.pumpAndSettle();
    expect(find.text('Gym'), findsOneWidget);
    await tester.tap(find.text('Gym'));
    await tester.pumpAndSettle();
    expect(find.text('Routine'), findsOneWidget);
    await tester.tap(find.text('Repeat'));
    await tester.pumpAndSettle();
    expect(find.text('Weekly'), findsOneWidget);
    await close();

    await tester.tap(find.bySemanticsLabel('Places'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Home').last);
    await tester.pumpAndSettle();
    expect(find.text('Place'), findsOneWidget);
    await close();

    await tester.tap(find.text('Standup').first);
    await tester.pumpAndSettle();
    expect(find.text('Navigate'), findsOneWidget);
    await tester.tap(find.text('Move'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Move ·'), findsOneWidget);
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Stamp'));
    await tester.pumpAndSettle();
    expect(find.text('MARK'), findsOneWidget);
    await close();

    await tester.tap(find.bySemanticsLabel('New event'));
    await tester.pumpAndSettle();
    expect(find.text('New event'), findsWidgets);
    await close();
  });

  group('time picker', () {
    Future<TimePickerViewState> pumpPicker(WidgetTester tester,
        {required void Function(DateTime, int) onConfirm}) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () => showMultiViewDrawer<void>(
                  context: context,
                  initial: 'time',
                  views: {
                    'time': DrawerView(
                      heightFactor: 0.82,
                      builder: (_) => TimePickerView(
                        start: Days.atMinutes(_week, 9 * 60),
                        duration: 60,
                        onConfirm: onConfirm,
                      ),
                    ),
                  },
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return tester.state<TimePickerViewState>(find.byType(TimePickerView));
    }

    testWidgets('dragging the candidate moves it in five minute steps',
        (tester) async {
      final picker = await pumpPicker(tester, onConfirm: (_, __) {});
      expect(picker.start, 9 * 60);

      final block = _candidate;
      final top = tester.getRect(block).topCenter + const Offset(0, 20);
      final gesture = await tester.startGesture(top);
      // 72 px an hour: 13 px is 10.8 minutes, which snaps to 10.
      await gesture.moveBy(const Offset(0, 13));
      await tester.pump();
      expect(picker.start, 9 * 60 + 10);
      expect(picker.start % 5, 0);

      await gesture.moveBy(const Offset(0, 4));
      await tester.pump();
      expect(picker.start % 5, 0);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(picker.duration, 60);
    });

    testWidgets('the bottom edge stretches the duration in five minute steps',
        (tester) async {
      final picker = await pumpPicker(tester, onConfirm: (_, __) {});
      final block = _candidate;
      final edge = tester.getRect(block).bottomCenter - const Offset(0, 6);
      final gesture = await tester.startGesture(edge);
      await gesture.moveBy(const Offset(0, 37));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(picker.start, 9 * 60);
      expect(picker.duration, 90);
    });

    testWidgets('confirm returns the day, start and duration', (tester) async {
      DateTime? start;
      int? duration;
      await pumpPicker(tester, onConfirm: (s, d) {
        start = s;
        duration = d;
      });

      await tester.tap(find.textContaining('Set time'));
      await tester.pump();

      expect(start, Days.atMinutes(_week, 9 * 60));
      expect(duration, 60);
    });
  });
}

class _NoKeys extends ApiKeyStore {
  const _NoKeys() : super(const FlutterSecureStorage());

  @override
  Future<String?> read(ApiKeyKind kind) async => null;
}
