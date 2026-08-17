/// Business vs personal totals for one calendar month.
class MonthKindTotals {
  const MonthKindTotals({
    required this.month,
    required this.businessMinor,
    required this.personalMinor,
  });

  /// First of the month, local midnight.
  final DateTime month;
  final int businessMinor;
  final int personalMinor;

  int get totalMinor => businessMinor + personalMinor;
}
