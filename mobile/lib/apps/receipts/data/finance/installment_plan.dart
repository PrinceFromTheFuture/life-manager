import 'dart:math' as math;

import 'package:shopping_list/core/util/money.dart';

/// Splitting a charge across several monthly payments.
///
/// Everything is integer agorot from end to end. The interest maths runs
/// through a double exactly once, to evaluate the annuity formula, and its
/// result is rounded to agorot immediately — nothing downstream ever sees a
/// fractional shekel.
class InstallmentPlan {
  const InstallmentPlan._({
    required this.payments,
    required this.principalMinor,
    required this.interestBp,
  });

  /// What each payment costs, in order. Always [count] long.
  final List<int> payments;

  final int principalMinor;

  /// Annual nominal rate in basis points. 600 is 6% a year.
  final int interestBp;

  int get count => payments.length;

  int get totalMinor => payments.fold(0, (sum, value) => sum + value);

  int get interestMinor => totalMinor - principalMinor;

  bool get isSingle => count == 1;

  /// True when every payment is the same size, which is what happens as soon
  /// as interest is involved.
  bool get isEven => payments.every((p) => p == payments.first);

  /// Splits [principalMinor] across [count] payments.
  ///
  /// With no interest the payments must add up to the principal exactly, so the
  /// odd agora goes on the **first** payment and the rest of the run is even —
  /// which is how an Israeli card slip prints it, and it means the number you
  /// see repeated is the number you will actually pay most months.
  ///
  /// With interest the rate is annual nominal, compounded monthly, and the
  /// standard annuity payment is used. Every payment is then identical and the
  /// total is what the split really costs.
  factory InstallmentPlan.split({
    required int principalMinor,
    required int count,
    int interestBp = 0,
  }) {
    final n = count < 1 ? 1 : count;

    if (n == 1) {
      return InstallmentPlan._(
        payments: [principalMinor],
        principalMinor: principalMinor,
        interestBp: 0,
      );
    }

    if (interestBp <= 0) {
      final base = principalMinor ~/ n;
      final remainder = principalMinor - base * n;
      return InstallmentPlan._(
        payments: [
          base + remainder,
          for (var i = 1; i < n; i++) base,
        ],
        principalMinor: principalMinor,
        interestBp: 0,
      );
    }

    final monthlyRate = interestBp / 10000 / 12;
    final growth = math.pow(1 + monthlyRate, -n).toDouble();
    final each = (principalMinor * monthlyRate / (1 - growth)).round();

    return InstallmentPlan._(
      payments: List<int>.filled(n, each),
      principalMinor: principalMinor,
      interestBp: interestBp,
    );
  }

  /// The one line the expense sheet prints under the payment method chips.
  ///
  /// Reads like the slip: `3 payments · ₪104.34, then ₪104.33 x2`. Naming the
  /// odd payment out loud is the honest thing to do — hiding it behind an
  /// average is how people end up querying a bill for one agora.
  String get caption {
    if (isSingle) return '1 payment';

    final parts = <String>['$count payments'];

    if (isEven) {
      parts.add('${Money.format(payments.first)} each');
    } else {
      parts.add(
        '${Money.format(payments.first)}, then '
        '${Money.format(payments[1])} x${count - 1}',
      );
    }

    if (interestBp > 0) parts.add('${formatRate(interestBp)} a year');

    return parts.join(' · ');
  }

  /// `600` reads as `6%`, `650` as `6.5%`. Trailing zeros are noise on a line
  /// this small.
  static String formatRate(int basisPoints) {
    final percent = basisPoints / 100;
    final text = percent
        .toStringAsFixed(2)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
    return '$text%';
  }
}
