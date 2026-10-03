import 'package:flutter/material.dart';

import 'package:shopping_list/apps/calendar/ui/navigate_drawer.dart';
import 'package:shopping_list/apps/calendar/ui/night.dart';

/// Hosts the navigate drawer inside Calendar's ink, then leaves.
///
/// The hub cannot show the drawer in Calendar ink without a mini-app host —
/// the same reason Add expense opens ExpenseSheet through openMiniApp.
class NavigateLaunch extends StatefulWidget {
  const NavigateLaunch({super.key});

  @override
  State<NavigateLaunch> createState() => _NavigateLaunchState();
}

class _NavigateLaunchState extends State<NavigateLaunch> {
  final _night = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _open());
  }

  Future<void> _open() async {
    final inner = _night.currentContext;
    if (!mounted || inner == null) return;
    await showNavigateDrawer(inner);
    if (mounted) Navigator.of(context, rootNavigator: true).pop();
  }

  @override
  Widget build(BuildContext context) {
    return NightTheme(
      child: ColoredBox(
        key: _night,
        color: Night.ground,
        child: const SizedBox.expand(),
      ),
    );
  }
}
