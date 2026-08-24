import 'package:flutter/material.dart';

/// Stamp-pad inks a mark can be printed in.
///
/// A closed set, drawn from the same dusty carbons the rest of the product
/// already uses — receipts ledger, carbon-copy violet, oxidized iron, thermal
/// scorch — plus siblings in that register. Identity is one of these, never
/// a free colour picker and never a second palette invented beside the paper.
@immutable
class StampInk {
  const StampInk({
    required this.id,
    required this.label,
    required this.light,
    required this.dark,
  });

  /// Persisted id. Stable; retuning a colour does not need a migration.
  final String id;

  /// Spoken name in the picker, so a pad is "Pine" rather than a swatch
  /// you have to remember.
  final String label;

  final Color light;
  final Color dark;

  Color of(Brightness brightness) =>
      brightness == Brightness.light ? light : dark;

  static const String fallbackId = ledgerId;
  static const String ledgerId = 'ledger';

  /// Receipts' own iron-gall. Home, by default.
  static const ledger = StampInk(
    id: ledgerId,
    label: 'Ledger',
    light: Color(0xFF27506E),
    dark: Color(0xFF7FA8D0),
  );

  /// Carbon-copy violet.
  static const violet = StampInk(
    id: 'violet',
    label: 'Violet',
    light: Color(0xFF5B4B8A),
    dark: Color(0xFF9B8AD1),
  );

  /// Oxidized iron.
  static const iron = StampInk(
    id: 'iron',
    label: 'Iron',
    light: Color(0xFF6E3B2F),
    dark: Color(0xFFD9A090),
  );

  /// The hot edge of a thermal burn.
  static const scorch = StampInk(
    id: 'scorch',
    label: 'Scorch',
    light: Color(0xFF9A8B6F),
    dark: Color(0xFFC4B08A),
  );

  /// Ledger-ruling green.
  static const pine = StampInk(
    id: 'pine',
    label: 'Pine',
    light: Color(0xFF3D5A45),
    dark: Color(0xFF8FBA9A),
  );

  /// Stamp-pad red. Kin of the destructive confirmation, quieter.
  static const carmine = StampInk(
    id: 'carmine',
    label: 'Carmine',
    light: Color(0xFF8F3A38),
    dark: Color(0xFFD98984),
  );

  static const slate = StampInk(
    id: 'slate',
    label: 'Slate',
    light: Color(0xFF4A5560),
    dark: Color(0xFFA8B4BE),
  );

  /// Iron-gall teal.
  static const teal = StampInk(
    id: 'teal',
    label: 'Teal',
    light: Color(0xFF2F5A5A),
    dark: Color(0xFF7EB0B0),
  );

  static const mustard = StampInk(
    id: 'mustard',
    label: 'Mustard',
    light: Color(0xFF8A6E32),
    dark: Color(0xFFCDB87A),
  );

  static const wine = StampInk(
    id: 'wine',
    label: 'Wine',
    light: Color(0xFF6B3A4A),
    dark: Color(0xFFC992A4),
  );

  static const cobalt = StampInk(
    id: 'cobalt',
    label: 'Cobalt',
    light: Color(0xFF2F4A7A),
    dark: Color(0xFF8AA3C9),
  );

  static const indigo = StampInk(
    id: 'indigo',
    label: 'Indigo',
    light: Color(0xFF3E3A6E),
    dark: Color(0xFF9A94C4),
  );

  static const rust = StampInk(
    id: 'rust',
    label: 'Rust',
    light: Color(0xFF8A4A32),
    dark: Color(0xFFD4A090),
  );

  static const moss = StampInk(
    id: 'moss',
    label: 'Moss',
    light: Color(0xFF4A5A32),
    dark: Color(0xFFA4B48A),
  );

  static const clay = StampInk(
    id: 'clay',
    label: 'Clay',
    light: Color(0xFF7A5A48),
    dark: Color(0xFFC4A898),
  );

  static const dusk = StampInk(
    id: 'dusk',
    label: 'Dusk',
    light: Color(0xFF4A4A62),
    dark: Color(0xFFA8A8C0),
  );

  static const coral = StampInk(
    id: 'coral',
    label: 'Coral',
    light: Color(0xFF8A5A58),
    dark: Color(0xFFD4A8A4),
  );

  static const brass = StampInk(
    id: 'brass',
    label: 'Brass',
    light: Color(0xFF7A6A38),
    dark: Color(0xFFC4B888),
  );

  static const List<StampInk> all = [
    ledger,
    violet,
    iron,
    scorch,
    pine,
    carmine,
    slate,
    teal,
    mustard,
    wine,
    cobalt,
    indigo,
    rust,
    moss,
    clay,
    dusk,
    coral,
    brass,
  ];

  /// Unknown or missing ids fall back to ledger rather than crashing a feed.
  static StampInk byId(String? id) {
    if (id == null || id.isEmpty) return ledger;
    for (final ink in all) {
      if (ink.id == id) return ink;
    }
    return ledger;
  }

  /// Next pad in palette order that is used the least, so a new mark does
  /// not land on the same ink as the one above it.
  static String next(Iterable<String> usedIds) {
    final counts = {for (final ink in all) ink.id: 0};
    for (final id in usedIds) {
      final resolved = byId(id).id;
      counts[resolved] = (counts[resolved] ?? 0) + 1;
    }
    var best = all.first;
    var min = counts[best.id]!;
    for (final ink in all.skip(1)) {
      final n = counts[ink.id]!;
      if (n < min) {
        min = n;
        best = ink;
      }
    }
    return best.id;
  }

  @override
  bool operator ==(Object other) => other is StampInk && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
