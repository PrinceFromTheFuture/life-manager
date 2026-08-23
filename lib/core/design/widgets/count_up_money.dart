import 'package:flutter/material.dart';

import 'package:shopping_list/core/design/tokens.dart';
import 'package:shopping_list/core/util/money.dart';

/// A total that prints itself, the way a register rolls digits up to the
/// amount that is actually there.
class CountUpMoney extends StatefulWidget {
  const CountUpMoney({
    super.key,
    required this.amountMinor,
    required this.style,
    this.signed = false,
  });

  final int amountMinor;
  final TextStyle style;
  final bool signed;

  @override
  State<CountUpMoney> createState() => _CountUpMoneyState();
}

class _CountUpMoneyState extends State<CountUpMoney>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Motion.countUp,
  );
  late final Animation<double> _t = CurvedAnimation(
    parent: _controller,
    curve: Motion.heat,
  );

  int _from = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _play();
    });
  }

  @override
  void didUpdateWidget(CountUpMoney old) {
    super.didUpdateWidget(old);
    if (old.amountMinor == widget.amountMinor) return;
    _from = _currentOf(old.amountMinor);
    _play();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _play() {
    if (!mounted) return;
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (reduce) {
      _controller.value = 1;
      return;
    }
    _controller.forward(from: 0);
  }

  int _currentOf(int to) {
    final t = _controller.value;
    return _from + ((to - _from) * t).round();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _t,
      builder: (context, _) {
        final value = _currentOf(widget.amountMinor);
        return Text(
          widget.signed ? Money.formatSigned(value) : Money.format(value),
          style: widget.style,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      },
    );
  }
}
