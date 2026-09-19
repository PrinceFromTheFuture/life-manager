import 'package:flutter/material.dart';

import 'package:shopping_list/apps/calendar/ui/navigate_drawer.dart';
import 'package:shopping_list/core/design/tokens.dart';

/// Hosts the navigate drawer inside Calendar's ink, then leaves.
///
/// The hub cannot show an inset drawer in Calendar ink without a mini-app
/// host — the same reason Add expense opens ExpenseSheet through openMiniApp.
class NavigateLaunch extends StatefulWidget {
  const NavigateLaunch({super.key});

  @override
  State<NavigateLaunch> createState() => _NavigateLaunchState();
}

class _NavigateLaunchState extends State<NavigateLaunch> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _open());
  }

  Future<void> _open() async {
    if (!mounted) return;
    await showNavigateDrawer(context);
    if (mounted) Navigator.of(context, rootNavigator: true).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(backgroundColor: context.thermal.paper);
  }
}
