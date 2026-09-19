import 'package:sqflite/sqflite.dart';

import 'package:shopping_list/apps/calendar/data/models/block.dart';

class BlockDao {
  BlockDao(this._db);

  final DatabaseExecutor _db;

  Future<List<Block>> inRange(DateTime from, DateTime to) async {
    final rows = await _db.query(
      'calendar_blocks',
      where: 'starts_at < ? AND starts_at + duration_minutes * 60000 > ?',
      whereArgs: [to.millisecondsSinceEpoch, from.millisecondsSinceEpoch],
      orderBy: 'starts_at ASC',
    );
    return rows.map(Block.fromMap).toList();
  }

  Future<List<Block>> all() async {
    final rows = await _db.query(
      'calendar_blocks',
      orderBy: 'starts_at ASC',
    );
    return rows.map(Block.fromMap).toList();
  }

  Future<Block?> byId(int id) async {
    final rows = await _db.query(
      'calendar_blocks',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : Block.fromMap(rows.first);
  }

  Future<Block> insert(Block block) async {
    final id = await _db.insert('calendar_blocks', block.toMap());
    return block.copyWith(id: id);
  }

  Future<void> update(Block block) => _db.update(
        'calendar_blocks',
        block.toMap(),
        where: 'id = ?',
        whereArgs: [block.id],
      );

  Future<void> delete(int id) => _db.delete(
        'calendar_blocks',
        where: 'id = ?',
        whereArgs: [id],
      );
}
