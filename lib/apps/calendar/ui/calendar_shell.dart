import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shopping_list/apps/calendar/state/providers.dart';
import 'package:shopping_list/apps/calendar/ui/board/board_screen.dart';
import 'package:shopping_list/apps/calendar/ui/ask_screen.dart';
import 'package:shopping_list/apps/calendar/ui/places/place_sheet.dart';
import 'package:shopping_list/apps/calendar/ui/places/places_screen.dart';
import 'package:shopping_list/apps/calendar/ui/registry/registry_screen.dart';
import 'package:shopping_list/apps/calendar/ui/registry/series_sheet.dart';
import 'package:shopping_list/apps/receipts/ui/nav/divider_tabs.dart';
import 'package:shopping_list/core/design/tokens.dart';
import 'package:shopping_list/core/design/widgets/app_icon.dart';

/// Board, registry, places — locations are a peer, not a field on an event.
class CalendarShell extends ConsumerStatefulWidget {
  const CalendarShell({super.key, this.occurredAt});

  /// Opens the board on this day — used by the hub feed and today rail.
  final DateTime? occurredAt;

  static const List<String> _labels = ['Board', 'Registry', 'Places'];

  static const int board = 0;
  static const int registry = 1;
  static const int places = 2;

  @override
  ConsumerState<CalendarShell> createState() => _CalendarShellState();
}

class _CalendarShellState extends ConsumerState<CalendarShell>
    with SingleTickerProviderStateMixin {
  final _visited = <int>{};

  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: Motion.quick,
    value: 1,
  );

  @override
  void initState() {
    super.initState();
    if (widget.occurredAt != null) {
      ref.read(calendarTabProvider.notifier).state = CalendarShell.board;
    }
    _visited.add(ref.read(calendarTabProvider));
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  void _select(int index) {
    if (index == ref.read(calendarTabProvider)) return;
    setState(() => _visited.add(index));
    ref.read(calendarTabProvider.notifier).state = index;
    if (!MediaQuery.disableAnimationsOf(context)) {
      _fade.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;
    final index = ref.watch(calendarTabProvider);

    return Scaffold(
      backgroundColor: palette.paper,
      appBar: AppBar(title: const Text('Calendar')),
      body: Column(
        children: [
          DividerTabs(
            labels: CalendarShell._labels,
            index: index,
            onSelected: _select,
          ),
          Expanded(
            child: FadeTransition(
              opacity: _fade,
              child: IndexedStack(
                index: index,
                sizing: StackFit.expand,
                children: [
                  for (var i = 0; i < CalendarShell._labels.length; i++)
                    _visited.contains(i) ? _body(i) : const SizedBox.shrink(),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _ActionBar(index: index),
    );
  }

  Widget _body(int index) => switch (index) {
        CalendarShell.registry => const RegistrySection(),
        CalendarShell.places => const PlacesSection(),
        _ => BoardSection(initialDay: widget.occurredAt),
      };
}

class _ActionBar extends ConsumerWidget {
  const _ActionBar({required this.index});

  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.thermal;
    final day = ref.watch(boardDayProvider);

    final (label, icon, onPressed) = switch (index) {
      CalendarShell.registry => (
          'Add to registry',
          SolarIcons.Repeat,
          () => SeriesSheet.open(context),
        ),
      CalendarShell.places => (
          'Add place',
          SolarIcons.MapPointAdd,
          () => PlaceSheet.open(context),
        ),
      _ => (
          'Ask',
          SolarIcons.StarsMinimalistic,
          () => AskScreen.open(context, day: day),
        ),
    };

    final plate = FilledButton.icon(
      onPressed: onPressed,
      icon: AppIcon(icon, size: 20),
      label: Text(label),
    );

    return Container(
      color: palette.paper,
      padding: EdgeInsets.fromLTRB(
        Space.lg,
        Space.md,
        Space.lg,
        Space.md + MediaQuery.paddingOf(context).bottom,
      ),
      child: SizedBox(width: double.infinity, child: plate),
    );
  }
}
