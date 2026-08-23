import 'package:flutter/material.dart';

/// Stamp-pad inks a category can be printed in.
///
/// A closed set, drawn from the same dusty carbons the rest of the product
/// already uses — receipts ledger, carbon-copy violet, oxidized iron, thermal
/// scorch — plus a handful of siblings in that register. Identity for a
/// category is one of these, never a free colour picker and never a second
/// palette invented beside the paper.
@immutable
class CategoryInk {
  const CategoryInk({
    required this.id,
    required this.label,
    required this.light,
    required this.dark,
  });

  /// Persisted on `expense_categories.ink`. Stable; retuning a colour does
  /// not need a migration.
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
  static const ledger = CategoryInk(
    id: ledgerId,
    label: 'Ledger',
    light: Color(0xFF27506E),
    dark: Color(0xFF7FA8D0),
  );

  /// Carbon-copy violet.
  static const violet = CategoryInk(
    id: 'violet',
    label: 'Violet',
    light: Color(0xFF5B4B8A),
    dark: Color(0xFF9B8AD1),
  );

  /// Oxidized iron.
  static const iron = CategoryInk(
    id: 'iron',
    label: 'Iron',
    light: Color(0xFF6E3B2F),
    dark: Color(0xFFD9A090),
  );

  /// The hot edge of a thermal burn.
  static const scorch = CategoryInk(
    id: 'scorch',
    label: 'Scorch',
    light: Color(0xFF9A8B6F),
    dark: Color(0xFFC4B08A),
  );

  /// Ledger-ruling green.
  static const pine = CategoryInk(
    id: 'pine',
    label: 'Pine',
    light: Color(0xFF3D5A45),
    dark: Color(0xFF8FBA9A),
  );

  /// Stamp-pad red. Kin of the destructive confirmation, quieter.
  static const carmine = CategoryInk(
    id: 'carmine',
    label: 'Carmine',
    light: Color(0xFF8F3A38),
    dark: Color(0xFFD98984),
  );

  static const slate = CategoryInk(
    id: 'slate',
    label: 'Slate',
    light: Color(0xFF4A5560),
    dark: Color(0xFFA8B4BE),
  );

  /// Iron-gall teal.
  static const teal = CategoryInk(
    id: 'teal',
    label: 'Teal',
    light: Color(0xFF2F5A5A),
    dark: Color(0xFF7EB0B0),
  );

  static const mustard = CategoryInk(
    id: 'mustard',
    label: 'Mustard',
    light: Color(0xFF8A6E32),
    dark: Color(0xFFCDB87A),
  );

  static const wine = CategoryInk(
    id: 'wine',
    label: 'Wine',
    light: Color(0xFF6B3A4A),
    dark: Color(0xFFC992A4),
  );

  static const List<CategoryInk> all = [
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
  ];

  /// Unknown or missing ids fall back to ledger rather than crashing a feed.
  static CategoryInk byId(String? id) {
    if (id == null || id.isEmpty) return ledger;
    for (final ink in all) {
      if (ink.id == id) return ink;
    }
    return ledger;
  }

  /// Next pad in palette order that is used the least, so a new category
  /// does not land on the same ink as the one above it.
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
  bool operator ==(Object other) => other is CategoryInk && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
