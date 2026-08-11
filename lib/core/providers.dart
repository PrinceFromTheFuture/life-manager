import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shopping_list/core/db/database.dart';
import 'package:shopping_list/core/storage/image_store.dart';

/// The one open database, shared by every mini-app.
///
/// Overridden in `main()` after the migrator has run. Modules build their own
/// repositories from this rather than each being overridden individually —
/// which is what keeps adding an app from requiring a change to `main`.
final databaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError('databaseProvider must be overridden'),
);

/// Shared image storage. Receipts from a shopping trip and receipts from an
/// expense are the same kind of file with the same relative-path rules, so
/// they use the same store.
final imageStoreProvider = Provider<ImageStore>((ref) => ImageStore());
