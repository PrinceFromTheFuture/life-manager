import 'package:flutter/material.dart';

import 'package:shopping_list/apps/tasks/ui/task_alert_host.dart';
import 'package:shopping_list/core/backup/auto_backup.dart';
import 'package:shopping_list/core/design/ink_scope.dart';
import 'package:shopping_list/core/design/paper_snack.dart';
import 'package:shopping_list/core/design/theme.dart';
import 'package:shopping_list/hub/hub_screen.dart';

class SpindleApp extends StatelessWidget {
  const SpindleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Spindle',
      debugShowCheckedModeBanner: false,
      navigatorKey: paperSnackNavigatorKey,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: ThemeMode.system,
      // The shell is inked in plain print, so the only colour anywhere on the
      // hub belongs to a mini-app.
      home: AutoBackupHost(
        child: TaskAlertHost(
          child: InkScope(ink: shellInk, child: const HubScreen()),
        ),
      ),
    );
  }
}
