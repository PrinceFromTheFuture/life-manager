/// Normalises a product name into the key used for deduplication and search.
///
/// Two entries typed as `Milk`, `  milk `, and `MILK` are the same product, and
/// the database enforces that through a uniqueness constraint on this value.
/// Hebrew niqqud is stripped so `חָלָב` and `חלב` also collapse to one product.
String normalizeName(String raw) {
  var s = raw.trim().toLowerCase();
  // Hebrew points and cantillation marks (U+0591–U+05C7).
  s = s.replaceAll(RegExp(r'[֑-ׇ]'), '');
  // Collapse any run of whitespace to a single space.
  s = s.replaceAll(RegExp(r'\s+'), ' ');
  return s;
}

/// Tidies a name for storage and display: collapses whitespace but preserves
/// the capitalisation the user actually typed.
String cleanName(String raw) => raw.trim().replaceAll(RegExp(r'\s+'), ' ');

/// Escapes the LIKE wildcards so a product containing `%` or `_` searches
/// literally. Pair with `ESCAPE '\'` in the query.
String escapeLike(String raw) => raw
    // A raw string cannot end in a backslash, so these two are written plain.
    .replaceAll('\\', '\\\\')
    .replaceAll('%', '\\%')
    .replaceAll('_', '\\_');
