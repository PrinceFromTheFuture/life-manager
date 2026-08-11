import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'data/db/database.dart';
import 'data/image_store.dart';
import 'data/repositories/shopping_repository.dart';
import 'state/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // The database opens before the first frame. Everything on screen is backed
  // by it, so there is no useful UI to show in the meantime — and this keeps
  // every provider downstream synchronous about its dependencies.
  final database = await AppDatabase.open();
  final repository = ShoppingRepository(database, ImageStore());

  runApp(
    ProviderScope(
      overrides: [repositoryProvider.overrideWithValue(repository)],
      child: const ShoppingListApp(),
    ),
  );
}
