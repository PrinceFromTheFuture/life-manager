import 'package:flutter/material.dart';

import 'package:shopping_list/core/backup/auto_backup.dart';
import 'package:shopping_list/core/design/ink_scope.dart';
import 'package:shopping_list/core/design/paper_snack.dart';
import 'package:shopping_list/core/design/theme.dart';
import 'package:shopping_list/apps/home/ui/life_shell.dart';

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
      // Home is the dark shell. Each app keeps its own ink once you wipe into it.
      home: AutoBackupHost(
        child: InkScope(ink: shellInk, child: const LifeShell()),
      ),
    );
  }
}
