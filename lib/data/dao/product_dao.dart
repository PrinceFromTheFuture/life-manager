import 'package:sqflite/sqflite.dart';

import '../../util/normalize.dart';
import '../models/product.dart';

/// The product catalogue: everything the user has ever added, which is what
/// makes autocomplete useful from the second shop onward.
class ProductDao {
  ProductDao(this._db);

  final DatabaseExecutor _db;

  /// Finds the product for [rawName], creating it the first time it's seen.
  ///
  /// Matching is on the normalised name, so `Milk`, `milk` and `  MILK  ` all
  /// resolve to the same catalogue entry rather than three near-duplicates
  /// cluttering autocomplete.
  Future<Product> findOrCreate(String rawName, {String? unit}) async {
    final clean = cleanName(rawName);
    final key = normalizeName(clean);

    final existing = await _db.query(
      'products',
      where: 'name_normalized = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (existing.isNotEmpty) return Product.fromMap(existing.first);

    final product = Product.create(clean, unit: unit);
    final id = await _db.insert('products', product.toMap());
    return product.copyWith(id: id);
  }

  /// Autocomplete. Ranks prefix matches above mid-word matches, then by how
  /// often and how recently the product is bought.
  ///
  /// In SQLite, `DESC` already sorts NULLs last, so products never used yet
  /// fall to the bottom without needing `NULLS LAST` (unavailable on older
  /// bundled SQLite builds on Android).
  Future<List<Product>> search(String query, {int limit = 8}) async {
    final key = normalizeName(query);
    if (key.isEmpty) return suggestions(limit: limit);

    final escaped = escapeLike(key);
    final rows = await _db.rawQuery(
      '''
      SELECT * FROM products
      WHERE name_normalized LIKE ? ESCAPE '\\'
      ORDER BY
        CASE WHEN name_normalized LIKE ? ESCAPE '\\' THEN 0 ELSE 1 END,
        usage_count DESC,
        last_used_at DESC,
        name ASC
      LIMIT ?
      ''',
      ['%$escaped%', '$escaped%', limit],
    );
    return rows.map(Product.fromMap).toList();
  }

  /// What to offer before the user has typed anything: their usual basket.
  Future<List<Product>> suggestions({int limit = 8}) async {
    final rows = await _db.query(
      'products',
      orderBy: 'usage_count DESC, last_used_at DESC, name ASC',
      limit: limit,
    );
    return rows.map(Product.fromMap).toList();
  }

  /// Records that a product was just added to a list, which is what moves it
  /// up the autocomplete ranking.
  Future<void> touch(int productId) async {
    await _db.rawUpdate(
      '''
      UPDATE products
      SET usage_count = usage_count + 1, last_used_at = ?
      WHERE id = ?
      ''',
      [DateTime.now().millisecondsSinceEpoch, productId],
    );
  }

  Future<int> count() async =>
      Sqflite.firstIntValue(
        await _db.rawQuery('SELECT COUNT(*) FROM products'),
      ) ??
      0;

  Future<void> delete(int id) =>
      _db.delete('products', where: 'id = ?', whereArgs: [id]);
}
