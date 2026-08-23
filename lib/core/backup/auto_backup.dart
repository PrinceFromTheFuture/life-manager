import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shopping_list/core/backup/app_backup.dart';
import 'package:shopping_list/core/backup/local_backup_store.dart';
import 'package:shopping_list/core/providers.dart';
import 'package:shopping_list/core/settings/api_keys.dart';

/// Writes a full copy to [LocalBackupStore] when the last one is older than
/// five minutes. Does nothing while a copy is already being written.
class AutoBackup {
  AutoBackup({
    required this.buildZip,
    required this.store,
  });

  final Future<BackupZip> Function() buildZip;
  final LocalBackupStore store;

  bool _busy = false;

  bool get busy => _busy;

  /// Returns true when a copy was written.
  Future<bool> tick() async {
    if (_busy) return false;
    final last = await store.lastAt();
    if (!LocalBackupStore.isDue(last, DateTime.now())) return false;

    _busy = true;
    try {
      final zip = await buildZip();
      await store.write(zip);
      return true;
    } finally {
      _busy = false;
    }
  }
}

final localBackupStoreProvider = Provider<LocalBackupStore>(
  (ref) => LocalBackupStore(),
);

final autoBackupProvider = Provider<AutoBackup>((ref) {
  return AutoBackup(
    store: ref.watch(localBackupStoreProvider),
    buildZip: () async {
      final keys = await ref.read(apiKeyStoreProvider).exportAll();
      return AppBackup(
        ref.read(databaseProvider),
        ref.read(imageStoreProvider),
        keys: keys,
      ).build();
    },
  );
});

final localBackupCopiesProvider =
    FutureProvider.autoDispose<List<File>>((ref) {
  return ref.watch(localBackupStoreProvider).copies();
});

/// Runs [AutoBackup.tick] while the app is in the foreground.
///
/// Opened, or brought back, it writes a copy if the last one is more than
/// five minutes old. A timer keeps doing that every five minutes until the
/// app leaves the screen.
class AutoBackupHost extends ConsumerStatefulWidget {
  const AutoBackupHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AutoBackupHost> createState() => _AutoBackupHostState();
}

class _AutoBackupHostState extends ConsumerState<AutoBackupHost>
    with WidgetsBindingObserver {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _arm());
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _arm();
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _timer?.cancel();
        _timer = null;
    }
  }

  void _arm() {
    _timer?.cancel();
    unawaited(_tick());
    _timer = Timer.periodic(LocalBackupStore.interval, (_) => unawaited(_tick()));
  }

  Future<void> _tick() async {
    try {
      final wrote = await ref.read(autoBackupProvider).tick();
      if (wrote) ref.invalidate(localBackupCopiesProvider);
    } on Object {
      // A failed copy must not take the app down. The next tick retries.
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
