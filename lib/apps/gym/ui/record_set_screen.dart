import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shopping_list/apps/gym/data/gym_activity.dart';
import 'package:shopping_list/apps/gym/data/models/exercise.dart';
import 'package:shopping_list/apps/gym/state/providers.dart';
import 'package:shopping_list/apps/gym/ui/exercises_screen.dart';
import 'package:shopping_list/apps/gym/ui/load_keypad.dart';
import 'package:shopping_list/apps/gym/ui/stamp.dart';
import 'package:shopping_list/core/design/paper_snack.dart';
import 'package:shopping_list/core/design/theme.dart';
import 'package:shopping_list/core/design/tokens.dart';
import 'package:shopping_list/core/design/widgets/perforation.dart';
import 'package:shopping_list/core/util/load.dart';

/// Log a set. Built for the rest between sets: pick from the rack, confirm
/// the last load, stamp. The screen stays on that exercise so set 2, 3 and 4
/// are one tap each.
class RecordSetScreen extends ConsumerStatefulWidget {
  const RecordSetScreen({super.key, this.exerciseId, this.forDay});

  final int? exerciseId;

  /// When set, the set lands on this day rather than whatever pass was last
  /// on screen. The hub shortcut always passes today so a leftover date from
  /// an earlier visit cannot steal the log.
  final DateTime? forDay;

  static Future<void> open(
    BuildContext context, {
    int? exerciseId,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => RecordSetScreen(exerciseId: exerciseId),
      ),
    );
  }

  @override
  ConsumerState<RecordSetScreen> createState() => _RecordSetScreenState();
}

class _RecordSetScreenState extends ConsumerState<RecordSetScreen> {
  int? _exerciseId;
  LoadEntry _load = LoadEntry();
  RepsEntry _reps = RepsEntry();
  KeypadField _field = KeypadField.weight;
  bool _logging = false;
  bool _didPrefill = false;

  @override
  void initState() {
    super.initState();
    _exerciseId = widget.exerciseId;
  }

  void _apply(Exercise exercise) {
    _exerciseId = exercise.id;
    _didPrefill = true;
    _load = exercise.lastWeightG != null
        ? LoadEntry.fromGrams(exercise.lastWeightG!)
        : LoadEntry();
    _reps = exercise.lastReps != null
        ? RepsEntry.fromValue(exercise.lastReps!)
        : RepsEntry.fromValue(8);
    _field = KeypadField.weight;
  }

  void _select(Exercise exercise) {
    setState(() => _apply(exercise));
  }

  Future<void> _log(Exercise exercise) async {
    if (_logging) return;
    final reps = _reps.value;
    if (reps <= 0) return;

    setState(() => _logging = true);
    final day = widget.forDay != null
        ? GymActivity.startOfDay(widget.forDay!)
        : ref.read(selectedDayProvider);
    try {
      await ref.read(gymControllerProvider).logSet(
            exerciseId: exercise.id!,
            reps: reps,
            weightG: _load.grams,
            day: day,
          );
      if (!mounted) return;
      await showSetStamp(
        context,
        exercise: exercise.name,
        weightG: _load.grams,
        reps: reps,
      );
    } on Exception catch (e) {
      if (!mounted) return;
      showPaperSnack(
        context,
        message: "That didn't save. Try again. ($e)",
      );
    } finally {
      if (mounted) setState(() => _logging = false);
    }
  }

  void _nudge(int direction) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_field == KeypadField.weight) {
        _load = _load.addGrams(direction * 2500);
      } else {
        _reps = _reps.add(direction);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;
    final rack = ref.watch(rackProvider);
    final all = ref.watch(exercisesProvider);
    final day = widget.forDay != null
        ? GymActivity.startOfDay(widget.forDay!)
        : ref.watch(selectedDayProvider);

    return Scaffold(
      backgroundColor: palette.paper,
      appBar: AppBar(
        title: const Text('Record a set'),
      ),
      body: rack.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('$e', style: Type.caption.copyWith(color: palette.faded)),
        ),
        data: (exercises) {
          if (exercises.isEmpty && _exerciseId == null) {
            return const _EmptyRack();
          }

          final catalogue =
              all.maybeWhen(data: (list) => list, orElse: () => exercises);
          Exercise? selected;
          for (final e in catalogue) {
            if (e.id == _exerciseId) {
              selected = e;
              break;
            }
          }

          if (!_didPrefill && selected != null) {
            _apply(selected);
          }

          final logging = selected;

          return Column(
            children: [
              Expanded(
                child: logging == null
                    ? _RackPicker(exercises: exercises, onSelect: _select)
                    : _SetEditor(
                        exercise: logging,
                        day: day,
                        load: _load,
                        reps: _reps,
                        field: _field,
                        onField: (f) => setState(() => _field = f),
                        onNudge: _nudge,
                        onSwitch: () => setState(() {
                          _exerciseId = null;
                          _didPrefill = false;
                        }),
                      ),
              ),
              if (logging != null)
                SetKeypad(
                  field: _field,
                  load: _load,
                  reps: _reps,
                  onLoad: (next) => setState(() => _load = next),
                  onReps: (next) => setState(() => _reps = next),
                  onLog: _logging ? () {} : () => _log(logging),
                  canLog: !_logging && _reps.value > 0,
                ),
            ],
          );
        },
      ),
    );
  }
}

class _EmptyRack extends StatelessWidget {
  const _EmptyRack();

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PerforatedRule(),
          const SizedBox(height: Space.lg),
          Text(
            'Nothing on the rack.',
            style: Type.display.copyWith(color: palette.print, fontSize: 26),
          ),
          const SizedBox(height: Space.md),
          Text(
            'Put exercises on it from the list, then come back to log.',
            style: Type.body.copyWith(color: palette.faded),
          ),
          const SizedBox(height: Space.xl),
          FilledButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const ExercisesScreen()),
            ),
            child: const Text('Open exercises'),
          ),
        ],
      ),
    );
  }
}

class _RackPicker extends StatelessWidget {
  const _RackPicker({required this.exercises, required this.onSelect});

  final List<Exercise> exercises;
  final ValueChanged<Exercise> onSelect;

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;

    return ListView(
      padding: const EdgeInsets.only(bottom: Space.xxl),
      children: [
        Padding(
          padding:
              const EdgeInsets.fromLTRB(Space.lg, Space.lg, Space.lg, Space.sm),
          child: Text(
            'ON THE RACK',
            style: Type.eyebrow.copyWith(color: palette.faded),
          ),
        ),
        const PerforatedRule(),
        for (var i = 0; i < exercises.length; i++) ...[
          _RackRow(exercise: exercises[i], onTap: () => onSelect(exercises[i])),
          if (i != exercises.length - 1) const PerforatedRule(indent: Space.lg),
        ],
      ],
    );
  }
}

class _RackRow extends StatelessWidget {
  const _RackRow({required this.exercise, required this.onTap});

  final Exercise exercise;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;
    final last = exercise.lastWeightG == null
        ? 'No sets yet'
        : '${Load.format(exercise.lastWeightG!)}  ×  ${exercise.lastReps ?? 0}';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Space.lg,
            vertical: Space.md + 4,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  exercise.name,
                  style: Type.itemLarge.copyWith(color: palette.print),
                ),
              ),
              const SizedBox(width: Space.md),
              Text(
                last,
                style: Type.mono.copyWith(color: palette.faded),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SetEditor extends ConsumerWidget {
  const _SetEditor({
    required this.exercise,
    required this.day,
    required this.load,
    required this.reps,
    required this.field,
    required this.onField,
    required this.onNudge,
    required this.onSwitch,
  });

  final Exercise exercise;
  final DateTime day;
  final LoadEntry load;
  final RepsEntry reps;
  final KeypadField field;
  final ValueChanged<KeypadField> onField;
  final ValueChanged<int> onNudge;
  final VoidCallback onSwitch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.thermal;
    final todayCount = ref.watch(setsTodayProvider((exercise.id!, day)));

    return ListView(
      padding:
          const EdgeInsets.fromLTRB(Space.lg, Space.lg, Space.lg, Space.md),
      children: [
        InkWell(
          onTap: onSwitch,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  exercise.name.toUpperCase(),
                  style: Type.eyebrow.copyWith(color: palette.carbon),
                ),
              ),
              Text(
                'Change',
                style: Type.caption.copyWith(color: palette.faded),
              ),
            ],
          ),
        ),
        const SizedBox(height: Space.sm),
        todayCount.maybeWhen(
          data: (n) => Text(
            n == 0
                ? 'First set'
                : 'Set ${n + 1}'
                    '${exercise.lastWeightG == null ? '' : ' · last ${Load.format(exercise.lastWeightG!)} × ${exercise.lastReps}'}',
            style: Type.caption.copyWith(color: palette.faded),
          ),
          orElse: () => const SizedBox.shrink(),
        ),
        const SizedBox(height: Space.xl),
        Row(
          children: [
            Expanded(
              child: _ValueField(
                label: 'Reps',
                value: reps.display,
                selected: field == KeypadField.reps,
                onTap: () => onField(KeypadField.reps),
              ),
            ),
            const SizedBox(width: Space.md),
            Expanded(
              child: _ValueField(
                label: 'Weight',
                value: load.display,
                unit: Load.unit,
                selected: field == KeypadField.weight,
                onTap: () => onField(KeypadField.weight),
              ),
            ),
          ],
        ),
        const SizedBox(height: Space.md),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => onNudge(-1),
                child: Text(field == KeypadField.weight ? '− 2.5 kg' : '− 1'),
              ),
            ),
            const SizedBox(width: Space.md),
            Expanded(
              child: OutlinedButton(
                onPressed: () => onNudge(1),
                child: Text(field == KeypadField.weight ? '+ 2.5 kg' : '+ 1'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ValueField extends StatelessWidget {
  const _ValueField({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
    this.unit,
  });

  final String label;
  final String value;
  final String? unit;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;

    return Material(
      color: palette.paperShade,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding:
              const EdgeInsets.fromLTRB(Space.md, Space.md, Space.md, Space.sm),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? palette.carbon : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: Type.eyebrow.copyWith(
                  color: selected ? palette.carbon : palette.faded,
                ),
              ),
              const SizedBox(height: Space.xs),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    value,
                    style: Type.totalDisplay.copyWith(
                      color: palette.print,
                      fontSize: 36,
                    ),
                  ),
                  if (unit != null) ...[
                    const SizedBox(width: Space.xs),
                    Text(
                      unit!,
                      style: Type.caption.copyWith(color: palette.faded),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
