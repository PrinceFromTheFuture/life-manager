import 'package:shopping_list/apps/calendar/data/expand/slices.dart';

/// A slice with its lane inside the group of slices it overlaps.
class PlacedSlice {
  const PlacedSlice({
    required this.slice,
    required this.column,
    required this.columns,
  });

  final DaySlice slice;

  /// Zero-based lane, left to right.
  final int column;

  /// Lanes in this slice's overlap group. A lone event has one.
  final int columns;
}

/// Side-by-side layout for one day's slices.
///
/// Greedy lanes: earliest first, longer first on a tie, each slice taking the
/// leftmost lane that is free by its start. Every slice in a connected overlap
/// group shares that group's lane count, so a group splits the column evenly
/// and an unrelated event later in the day keeps the full width.
abstract final class Overlaps {
  /// [minMinutes] is the shortest an event is drawn. A five-minute call still
  /// paints as a readable card, so it has to claim that much room here too or
  /// the next event would be laid over it.
  static List<PlacedSlice> place(List<DaySlice> slices, {int minMinutes = 0}) {
    if (slices.isEmpty) return const [];

    int endOf(DaySlice s) =>
        s.topMinutes +
        (s.durationMinutes < minMinutes ? minMinutes : s.durationMinutes);

    final sorted = [...slices]..sort((a, b) {
        final byTop = a.topMinutes.compareTo(b.topMinutes);
        if (byTop != 0) return byTop;
        final byLength = endOf(b).compareTo(endOf(a));
        if (byLength != 0) return byLength;
        return a.ticket.key.compareTo(b.ticket.key);
      });

    final out = <PlacedSlice>[];
    var group = <({DaySlice slice, int column})>[];
    var laneEnds = <int>[];
    var groupEnd = -1;

    void flush() {
      final columns = laneEnds.length;
      for (final item in group) {
        out.add(
          PlacedSlice(slice: item.slice, column: item.column, columns: columns),
        );
      }
      group = [];
      laneEnds = [];
    }

    for (final slice in sorted) {
      final start = slice.topMinutes;
      final end = endOf(slice);
      if (group.isNotEmpty && start >= groupEnd) flush();
      groupEnd = group.isEmpty || end > groupEnd ? end : groupEnd;

      var lane = laneEnds.indexWhere((laneEnd) => laneEnd <= start);
      if (lane == -1) {
        lane = laneEnds.length;
        laneEnds.add(end);
      } else {
        laneEnds[lane] = end;
      }
      group.add((slice: slice, column: lane));
    }
    flush();
    return out;
  }
}
