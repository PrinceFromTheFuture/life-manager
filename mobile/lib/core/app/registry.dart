import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shopping_list/core/app/mini_app.dart';

/// Every mini-app installed in this build.
///
/// The single place apps are listed. Nothing else in the codebase enumerates
/// them or branches on which one it is holding — the hub walks this list and
/// delegates, and the migrator collects schemas from it.
class MiniAppRegistry {
  const MiniAppRegistry(this.apps);

  final List<MiniApp> apps;

  MiniApp? byId(String id) {
    for (final app in apps) {
      if (app.id == id) return app;
    }
    // An unknown id means history written by an app that has since been
    // removed from the build. The feed skips those rows rather than crashing.
    return null;
  }
}

/// Overridden in `main()` once the concrete apps are constructed.
final registryProvider = Provider<MiniAppRegistry>(
  (ref) => throw UnimplementedError('registryProvider must be overridden'),
);
