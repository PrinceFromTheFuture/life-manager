import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:shopping_list/core/design/theme.dart';
import 'package:shopping_list/core/design/tokens.dart';
import 'package:shopping_list/core/util/money.dart';

/// The amount being typed, held as digits rather than parsed text.
///
/// Every rule is enforced **at the keystroke**: you cannot type a third
/// decimal place, a second decimal point, or a number long enough to overflow.
/// That is the real advantage over a system keyboard — there is no invalid
/// state to validate, warn about, or recover from, because it can't be
/// entered.
class AmountEntry {
  AmountEntry([this._raw = '']);

  String _raw;

  static const int _maxWholeDigits = 7;

  String get raw => _raw;
  bool get isEmpty => _raw.isEmpty;

  /// What the field shows. Empty entry reads as `0.00` rather than blank, so
  /// the field never looks broken.
  String get display => _raw.isEmpty ? '0.00' : _raw;

  /// The value in agorot, or null if nothing usable has been typed.
  int? get agorot {
    if (_raw.isEmpty) return null;
    final parsed = Money.tryParse(_raw);
    return (parsed == null || parsed == 0) ? null : parsed;
  }

  AmountEntry press(String digit) {
    final parts = _raw.split('.');

    if (parts.length == 2) {
      if (parts[1].length >= 2) return this; // two decimals is the limit
      return AmountEntry('$_raw$digit');
    }

    if (parts[0].length >= _maxWholeDigits) return this;
    // Avoid "007": a leading zero is only meaningful before a decimal point.
    if (_raw == '0') return AmountEntry(digit);
    return AmountEntry('$_raw$digit');
  }

  AmountEntry dot() {
    if (_raw.contains('.')) return this;
    return AmountEntry(_raw.isEmpty ? '0.' : '$_raw.');
  }

  AmountEntry backspace() {
    if (_raw.isEmpty) return this;
    return AmountEntry(_raw.substring(0, _raw.length - 1));
  }

  AmountEntry clear() => AmountEntry();

  /// Rebuilds an entry from a stored amount, for editing.
  factory AmountEntry.fromAgorot(int agorot) =>
      AmountEntry(Money.formatBare(agorot).replaceAll(',', ''));
}

/// A cash-register keypad, in place of the system keyboard.
///
/// Three reasons this exists rather than a numeric `TextField`:
///
/// - Registers and calculators are the world this app is about, so oversized
///   mono keys are in-language rather than a novelty.
/// - It cannot be occluded. The system keyboard hiding the controls beneath it
///   was a real bug in this app once already; a keypad that is part of the
///   layout cannot repeat it.
/// - It makes invalid input unreachable rather than merely rejected.
class RegisterKeypad extends StatelessWidget {
  const RegisterKeypad({
    super.key,
    required this.entry,
    required this.onChanged,
    required this.onDone,
    this.doneLabel = 'Done',
  });

  final AmountEntry entry;
  final ValueChanged<AmountEntry> onChanged;
  final VoidCallback onDone;
  final String doneLabel;

  void _press(AmountEntry next) {
    // A register clicks. Selection-strength only — medium impact thirty times
    // while typing an amount would be exhausting.
    unawaited(HapticFeedback.selectionClick());
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;

    // Same contract as the system keyboard: OS back dismisses the pad,
    // not the page underneath it.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        onDone();
      },
      child: Container(
        // The gaps between keys are paper showing through, which is what makes
        // this read as a printed grid rather than a floating button cluster.
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
                      child: _Key(
                        label: key,
                        onTap: () => _press(entry.press(key)),
                      ),
                    ),
                ],
              ),
            Row(
              children: [
                Expanded(
                  child: _Key(
                    label: '.',
                    onTap: () => _press(entry.dot()),
                  ),
                ),
                Expanded(
                  child: _Key(
                    label: '0',
                    onTap: () => _press(entry.press('0')),
                  ),
                ),
                Expanded(
                  child: _Key(
                    semanticLabel: 'Backspace',
                    icon: Icons.backspace_outlined,
                    onTap: () => _press(entry.backspace()),
                    onLongPress: () => _press(entry.clear()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Space.md),
            SizedBox(
              width: double.infinity,
              child: FilledButton(onPressed: onDone, child: Text(doneLabel)),
            ),
          ],
        ),
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
  });

  final String? label;
  final IconData? icon;
  final String? semanticLabel;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

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
          // Keys are paper, and paper has square corners in this system.
          borderRadius: BorderRadius.zero,
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            child: SizedBox(
              height: 62,
              child: Center(
                child: icon != null
                    ? Icon(icon, size: 24, color: palette.print)
                    : Text(
                        label!,
                        style: Type.totalDisplay.copyWith(
                          fontSize: 26,
                          color: palette.print,
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
