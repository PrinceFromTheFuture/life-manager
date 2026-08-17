import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shopping_list/app.dart';
import 'package:shopping_list/apps/groceries/groceries_app.dart';
import 'package:shopping_list/apps/gym/gym_app.dart';
import 'package:shopping_list/apps/receipts/receipts_app.dart';
import 'package:shopping_list/core/app/mini_app.dart';
import 'package:shopping_list/core/app/registry.dart';
import 'package:shopping_list/core/db/database.dart';
import 'package:shopping_list/core/providers.dart';

/// Every mini-app in this build.
///
/// This list is the *only* place apps are enumerated. Adding one means adding
/// a line here — its schema, screens, feed rows and deep links all travel with
/// it through the `MiniApp` contract.
const List<MiniApp> installedApps = [
  GroceriesApp(),
  ReceiptsApp(),
  GymApp(),
];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Each module's migrations are collected from the registry, so the database
  // never needs to know which apps exist.
  final database = await AppDatabase.open(
    modules: [for (final app in installedApps) app.migrations],
  );

  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
        registryProvider.overrideWithValue(
          const MiniAppRegistry(installedApps),
        ),
      ],
      child: const SpindleApp(),
    ),
  );
}
