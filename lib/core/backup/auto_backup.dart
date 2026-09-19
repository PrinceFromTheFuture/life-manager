import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shopping_list/core/backup/app_backup.dart';
import 'package:shopping_list/core/backup/backup_copy_store.dart';
import 'package:shopping_list/core/backup/local_backup_store.dart';
import 'package:shopping_list/core/backup/shared_backup_store.dart';
import 'package:shopping_list/core/providers.dart';
import 'package:shopping_list/core/settings/api_keys.dart';

/// Writes a full copy to [store] when the last one is older than five
/// minutes. Does nothing while a copy is already being written.
class AutoBackup {
  AutoBackup({
    required this.buildZip,
    required this.store,
  });

  final Future<BackupZip> Function() buildZip;
  final BackupCopyStore store;

  static const Duration interval = Duration(minutes: 5);

  bool _busy = false;

  bool get busy => _busy;

  /// Whether a copy should be written at [now].
  static bool isDue(DateTime? last, DateTime now) {
    if (last == null) return true;
    return now.difference(last) >= interval;
  }

  /// Returns true when a copy was written.
  Future<bool> tick() async {
    if (_busy) return false;
    final last = await store.lastAt();
    if (!isDue(last, DateTime.now())) return false;

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

/// Shared storage first, the app's own folder only where that is impossible.
final backupCopyStoreProvider = Provider<BackupCopyStore>(
  (ref) => SharedBackupStore(fallback: LocalBackupStore()),
);

final autoBackupProvider = Provider<AutoBackup>((ref) {
  return AutoBackup(
    store: ref.watch(backupCopyStoreProvider),
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

final backupCopiesProvider =
    FutureProvider.autoDispose<List<BackupCopy>>((ref) {
  return ref.watch(backupCopyStoreProvider).copies();
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
    _timer = Timer.periodic(AutoBackup.interval, (_) => unawaited(_tick()));
  }

  Future<void> _tick() async {
    try {
      final wrote = await ref.read(autoBackupProvider).tick();
      if (wrote) ref.invalidate(backupCopiesProvider);
    } on Object {
      // A failed copy must not take the app down. The next tick retries.
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
