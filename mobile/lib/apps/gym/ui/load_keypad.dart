import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:shopping_list/core/design/theme.dart';
import 'package:shopping_list/core/design/tokens.dart';
import 'package:shopping_list/core/util/load.dart';
import 'package:shopping_list/core/design/widgets/app_icon.dart';

/// The load being typed, held as digits rather than parsed text.
///
/// Same contract as the register amount: invalid input is unreachable.
/// Empty means bodyweight (zero grams), which is a real value on pull-ups
/// and planks, not a missing one.
class LoadEntry {
  LoadEntry({String raw = '', this.replaceOnType = false}) : _raw = raw;

  String _raw;

  /// Set while the field is focused and the shown value is a suggestion
  /// (last load, a nudge). The next digit or dot starts a new number rather
  /// than appending to 80 and making 807.
  final bool replaceOnType;

  static const int _maxWholeDigits = 4;

  String get raw => _raw;
  bool get isEmpty => _raw.isEmpty;

  String get display => _raw.isEmpty ? '0' : _raw;

  /// The shown value is selected. First keystroke replaces it.
  LoadEntry get pendingReplace =>
      LoadEntry(raw: _raw, replaceOnType: true);

  /// Grams. Empty entry is 0 — bodyweight — not null.
  int get grams => Load.tryParse(_raw.isEmpty ? '0' : _raw) ?? 0;

  LoadEntry press(String digit) {
    if (replaceOnType) return LoadEntry().press(digit);

    final parts = _raw.split('.');

    if (parts.length == 2) {
      if (parts[1].length >= 2) return this;
      return LoadEntry(raw: '$_raw$digit');
    }

    if (parts[0].length >= _maxWholeDigits) return this;
    if (_raw == '0') return LoadEntry(raw: digit);
    return LoadEntry(raw: '$_raw$digit');
  }

  LoadEntry dot() {
    if (replaceOnType) return LoadEntry().dot();
    if (_raw.contains('.')) return this;
    return LoadEntry(raw: _raw.isEmpty ? '0.' : '$_raw.');
  }

  LoadEntry backspace() {
    if (replaceOnType) return LoadEntry();
    if (_raw.isEmpty) return this;
    return LoadEntry(raw: _raw.substring(0, _raw.length - 1));
  }

  LoadEntry clear() => LoadEntry();

  LoadEntry addGrams(int delta) {
    final next = (grams + delta).clamp(0, 9999 * Load.gramsPerKg);
    return LoadEntry.fromGrams(next, replaceOnType: replaceOnType);
  }

  factory LoadEntry.fromGrams(int grams, {bool replaceOnType = false}) =>
      LoadEntry(
        raw: Load.formatBare(grams).replaceAll(',', ''),
        replaceOnType: replaceOnType,
      );
}

/// Integer reps. Same keypad, no decimal.
class RepsEntry {
  RepsEntry({String raw = '', this.replaceOnType = false}) : _raw = raw;

  String _raw;

  /// Same as [LoadEntry.replaceOnType] — last-set reps are a suggestion.
  final bool replaceOnType;

  static const int _maxDigits = 3;

  String get raw => _raw;
  bool get isEmpty => _raw.isEmpty;
  String get display => _raw.isEmpty ? '0' : _raw;

  RepsEntry get pendingReplace =>
      RepsEntry(raw: _raw, replaceOnType: true);

  int get value {
    if (_raw.isEmpty) return 0;
    return int.tryParse(_raw) ?? 0;
  }

  RepsEntry press(String digit) {
    if (replaceOnType) return RepsEntry().press(digit);
    if (_raw.length >= _maxDigits) return this;
    if (_raw == '0') return RepsEntry(raw: digit);
    return RepsEntry(raw: '$_raw$digit');
  }

  RepsEntry backspace() {
    if (replaceOnType) return RepsEntry();
    if (_raw.isEmpty) return this;
    return RepsEntry(raw: _raw.substring(0, _raw.length - 1));
  }

  RepsEntry clear() => RepsEntry();

  RepsEntry add(int delta) {
    final next = (value + delta).clamp(0, 999);
    return RepsEntry(
      raw: next == 0 ? '' : next.toString(),
      replaceOnType: replaceOnType,
    );
  }

  factory RepsEntry.fromValue(int reps, {bool replaceOnType = false}) =>
      RepsEntry(
        raw: reps == 0 ? '' : reps.toString(),
        replaceOnType: replaceOnType,
      );
}

enum KeypadField { reps, weight }

/// Register-style keypad for the set recorder.
///
/// The decimal key is only live when weight is focused. Reps are a count.
class SetKeypad extends StatelessWidget {
  const SetKeypad({
    super.key,
    required this.field,
    required this.load,
    required this.reps,
    required this.onLoad,
    required this.onReps,
    required this.onLog,
    this.canLog = true,
  });

  final KeypadField field;
  final LoadEntry load;
  final RepsEntry reps;
  final ValueChanged<LoadEntry> onLoad;
  final ValueChanged<RepsEntry> onReps;
  final VoidCallback onLog;
  final bool canLog;

  void _digit(String digit) {
    unawaited(HapticFeedback.selectionClick());
    if (field == KeypadField.weight) {
      onLoad(load.press(digit));
    } else {
      onReps(reps.press(digit));
    }
  }

  void _dot() {
    if (field != KeypadField.weight) return;
    unawaited(HapticFeedback.selectionClick());
    onLoad(load.dot());
  }

  void _backspace() {
    unawaited(HapticFeedback.selectionClick());
    if (field == KeypadField.weight) {
      onLoad(load.backspace());
    } else {
      onReps(reps.backspace());
    }
  }

  void _clear() {
    unawaited(HapticFeedback.selectionClick());
    if (field == KeypadField.weight) {
      onLoad(load.clear());
    } else {
      onReps(reps.clear());
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;

    return Container(
      color: palette.paper,
      padding: EdgeInsets.only(
        left: Space.lg,
        right: Space.lg,
        top: Space.md,
        bottom: Space.md + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final row in const [
            ['1', '2', '3'],
            ['4', '5', '6'],
            ['7', '8', '9'],
          ])
            Row(
              children: [
                for (final key in row)
                  Expanded(
                    child: _Key(label: key, onTap: () => _digit(key)),
                  ),
              ],
            ),
          Row(
            children: [
              Expanded(
                child: _Key(
                  label: '.',
                  faded: field != KeypadField.weight,
                  onTap: _dot,
                ),
              ),
              Expanded(
                child: _Key(label: '0', onTap: () => _digit('0')),
              ),
              Expanded(
                child: _Key(
                  semanticLabel: 'Backspace',
                  icon: SolarIcons.Backspace,
                  onTap: _backspace,
                  onLongPress: _clear,
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.md),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: canLog ? onLog : null,
              child: const Text('Log set'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({
    this.label,
    this.icon,
    this.semanticLabel,
    required this.onTap,
    this.onLongPress,
    this.faded = false,
  });

  final String? label;
  final SolarIconData? icon;
  final String? semanticLabel;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool faded;

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;

    return Semantics(
      button: true,
      label: semanticLabel ?? label,
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Material(
          color: palette.paperShade,
          borderRadius: BorderRadius.zero,
          child: InkWell(
            onTap: faded ? null : onTap,
            onLongPress: faded ? null : onLongPress,
            child: SizedBox(
              height: 56,
              child: Center(
                child: icon != null
                    ? AppIcon(icon!, size: 22, color: palette.print)
                    : Text(
                        label!,
                        style: Type.totalDisplay.copyWith(
                          fontSize: 24,
                          color: faded ? palette.faded : palette.print,
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
