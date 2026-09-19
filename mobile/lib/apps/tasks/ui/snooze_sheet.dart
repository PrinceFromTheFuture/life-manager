import 'package:flutter/material.dart';

import 'package:shopping_list/core/design/theme.dart';
import 'package:shopping_list/core/design/tokens.dart';
import 'package:shopping_list/core/design/widgets/inset_drawer.dart';

/// Picks when a card should come back to the tray.
Future<DateTime?> showSnoozeSheet(BuildContext context) {
  return showInsetDrawer<DateTime>(
    context: context,
    primary: (context) => const _SnoozeBody(),
  );
}

class _SnoozeBody extends StatelessWidget {
  const _SnoozeBody();

  DateTime _tonight() {
    final now = DateTime.now();
    var at = DateTime(now.year, now.month, now.day, 18);
    if (!at.isAfter(now)) at = at.add(const Duration(days: 1));
    return at;
  }

  DateTime _tomorrowMorning() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, 9)
        .add(const Duration(days: 1));
  }

  DateTime _nextWeek() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, 9)
        .add(const Duration(days: 7));
  }

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: DateTime(now.year + 2),
    );
    if (date == null || !context.mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
    );
    if (!context.mounted) return;
    Navigator.pop(
      context,
      DateTime(
        date.year,
        date.month,
        date.day,
        time?.hour ?? 9,
        time?.minute ?? 0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.lg, Space.md, Space.lg, Space.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('SNOOZE', style: Type.eyebrow.copyWith(color: palette.faded)),
          const SizedBox(height: Space.sm),
          Text(
            'Slide the card back under the blotter.',
            style: Type.body.copyWith(color: palette.print),
          ),
          const SizedBox(height: Space.lg),
          _row(context, 'Tonight', _tonight()),
          _row(context, 'Tomorrow morning', _tomorrowMorning()),
          _row(context, 'In an hour', DateTime.now().add(const Duration(hours: 1))),
          _row(context, 'Next week', _nextWeek()),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Pick date and time'),
            onTap: () => _pick(context),
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String label, DateTime when) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      onTap: () => Navigator.pop(context, when),
    );
  }
}
