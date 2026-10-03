import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:shopping_list/apps/calendar/data/expand/days.dart';
import 'package:shopping_list/apps/calendar/data/expand/weekdays.dart';
import 'package:shopping_list/apps/calendar/ui/drawer/drawer_parts.dart';
import 'package:shopping_list/apps/calendar/ui/drawer/event_session.dart';
import 'package:shopping_list/apps/calendar/ui/night.dart';
import 'package:shopping_list/core/design/theme.dart';
import 'package:shopping_list/core/design/tokens.dart';
import 'package:shopping_list/core/design/widgets/app_icon.dart';
import 'package:shopping_list/core/design/widgets/multi_view_drawer.dart';

/// Never, or how often. Choosing a rule turns the event into a routine.
class RepeatView extends StatelessWidget {
  const RepeatView({super.key, required this.session});

  final EventSession session;

  static const _names = {
    RepeatFreq.never: 'Never',
    RepeatFreq.daily: 'Daily',
    RepeatFreq.weekly: 'Weekly',
    RepeatFreq.monthly: 'Monthly',
  };

  static const _icons = {
    RepeatFreq.never: SolarIcons.CalendarMark,
    RepeatFreq.daily: SolarIcons.Refresh,
    RepeatFreq.weekly: SolarIcons.Repeat,
    RepeatFreq.monthly: SolarIcons.CalendarDate,
  };

  Future<void> _pickEnd(BuildContext context) async {
    final rule = session.repeat;
    final first = Days.startOfDay(session.startsAt);
    final picked = await showDatePicker(
      context: context,
      initialDate: rule.endsOn ?? Days.addDays(first, 30),
      firstDate: first,
      lastDate: DateTime(first.year + 20),
    );
    if (picked == null) return;
    session.update((d) => d.repeat = d.repeat.copyWith(endsOn: Days.startOfDay(picked)));
  }

  @override
  Widget build(BuildContext context) {
    final drawer = MultiViewDrawer.of(context);
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final rule = session.repeat;
        final unit = switch (rule.freq) {
          RepeatFreq.daily => rule.interval == 1 ? 'day' : 'days',
          RepeatFreq.weekly => rule.interval == 1 ? 'week' : 'weeks',
          RepeatFreq.monthly => rule.interval == 1 ? 'month' : 'months',
          RepeatFreq.never => '',
        };

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const DrawerViewHeader(title: 'Repeat'),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: Space.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DrawerGroup(
                      children: [
                        for (final freq in RepeatFreq.values)
                          if (freq != RepeatFreq.never || session.canBeOneOff)
                            DrawerRow(
                              icon: _icons[freq]!,
                              iconColor: rule.freq == freq ? Night.bone : null,
                              label: _names[freq]!,
                              chevron: false,
                              trailing: AnimatedOpacity(
                                duration: const Duration(milliseconds: 150),
                                opacity: rule.freq == freq ? 1 : 0,
                                child: const AppIcon(SolarIcons.CheckCircle, size: 20, color: Night.bone),
                              ),
                              onTap: () => session.update(
                                (d) => d.repeat = d.repeat.withFreq(freq, d.startsAt),
                              ),
                            ),
                      ],
                    ),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeInOut,
                      alignment: Alignment.topCenter,
                      child: !rule.repeats
                          ? const SizedBox(width: double.infinity)
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (rule.freq == RepeatFreq.weekly) ...[
                                  const DrawerLabel('On'),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      for (var i = 0; i < 7; i++)
                                        DrawerChoice(
                                          label: Weekdays.short[i].substring(0, 1),
                                          size: 40,
                                          selected: rule.weekdays & Weekdays.bits[i] != 0,
                                          onTap: () => session.update((d) {
                                            final next = d.repeat.weekdays ^ Weekdays.bits[i];
                                            d.repeat = d.repeat.copyWith(
                                              weekdays: next == 0 ? Weekdays.bits[i] : next,
                                            );
                                          }),
                                        ),
                                    ],
                                  ),
                                ],
                                const DrawerLabel('Rhythm'),
                                DrawerGroup(
                                  children: [
                                    DrawerRow(
                                      icon: SolarIcons.Refresh,
                                      label: 'Every',
                                      chevron: false,
                                      trailing: DrawerStepper(
                                        value: '${rule.interval} $unit',
                                        onMinus: rule.interval > 1
                                            ? () => session.update(
                                                  (d) => d.repeat = d.repeat.copyWith(interval: d.repeat.interval - 1),
                                                )
                                            : null,
                                        onPlus: rule.interval < 52
                                            ? () => session.update(
                                                  (d) => d.repeat = d.repeat.copyWith(interval: d.repeat.interval + 1),
                                                )
                                            : null,
                                      ),
                                    ),
                                    if (rule.freq == RepeatFreq.monthly)
                                      DrawerRow(
                                        icon: SolarIcons.CalendarDate,
                                        label: 'On day',
                                        chevron: false,
                                        trailing: DrawerStepper(
                                          value: '${rule.monthDay}',
                                          onMinus: rule.monthDay > 1
                                              ? () => session.update(
                                                    (d) => d.repeat = d.repeat.copyWith(monthDay: d.repeat.monthDay - 1),
                                                  )
                                              : null,
                                          onPlus: rule.monthDay < 31
                                              ? () => session.update(
                                                    (d) => d.repeat = d.repeat.copyWith(monthDay: d.repeat.monthDay + 1),
                                                  )
                                              : null,
                                        ),
                                      ),
                                    DrawerRow(
                                      icon: SolarIcons.Stop,
                                      label: 'Ends',
                                      value: rule.endsOn == null
                                          ? 'Never'
                                          : DateFormat('EEE d MMM y').format(rule.endsOn!),
                                      valueColor: rule.endsOn == null ? null : Night.bone,
                                      trailing: rule.endsOn == null
                                          ? null
                                          : GestureDetector(
                                              onTap: () => session.update(
                                                (d) => d.repeat = d.repeat.copyWith(clearEnd: true),
                                              ),
                                              child: const AppIcon(
                                                SolarIcons.CloseCircle,
                                                size: 20,
                                                color: Night.mist,
                                              ),
                                            ),
                                      chevron: rule.endsOn == null,
                                      onTap: () => _pickEnd(context),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: Space.sm),
                                Text(
                                  rule.describe(),
                                  style: Type.caption.copyWith(color: Night.mist),
                                ),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            ),
            DrawerFooter(
              children: [DrawerPrimaryButton(label: 'Done', onTap: drawer.pop)],
            ),
          ],
        );
      },
    );
  }
}
