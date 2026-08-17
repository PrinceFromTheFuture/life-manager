import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shopping_list/core/backup/app_backup.dart';
import 'package:shopping_list/core/backup/backup_picker.dart';
import 'package:shopping_list/core/design/paper_snack.dart';
import 'package:shopping_list/core/design/theme.dart';
import 'package:shopping_list/core/design/tokens.dart';
import 'package:shopping_list/core/design/widgets/perforation.dart';
import 'package:shopping_list/core/providers.dart';
import 'package:shopping_list/core/settings/api_keys.dart';

/// Account and settings.
class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.thermal;

    return Scaffold(
      backgroundColor: palette.paper,
      appBar: AppBar(title: const Text('Account')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: Space.xxl),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.md),
            child: Text(
              'RECEIPT SCANNING',
              style: Type.eyebrow.copyWith(color: palette.faded),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.md),
            child: Text(
              'Add both keys and the app can read a receipt photo and fill the '
              'expense in for you. Without them, you enter expenses yourself — '
              'everything else works the same.',
              style: Type.body.copyWith(color: palette.faded),
            ),
          ),
          const PerforatedRule(indent: Space.lg),
          for (final kind in ApiKeyKind.values) _KeyRow(kind: kind),
          const SizedBox(height: Space.xl),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.lg),
            child: Text(
              'Keys are stored in the Android keystore on this phone. They are '
              'never uploaded and never leave the device except to call the '
              'service they belong to.',
              style: Type.caption.copyWith(color: palette.faded),
            ),
          ),
          const SizedBox(height: Space.xl),
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.md),
            child: Text(
              'YOUR DATA',
              style: Type.eyebrow.copyWith(color: palette.faded),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.md),
            child: Text(
              'A copy of everything this phone is holding — lists, expenses, '
              'trips and receipt photos. API keys stay in the keystore. Keep '
              'one before installing a new build.',
              style: Type.body.copyWith(color: palette.faded),
            ),
          ),
          const PerforatedRule(indent: Space.lg),
          const _BackupSection(),
        ],
      ),
    );
  }
}

class _KeyRow extends ConsumerWidget {
  const _KeyRow({required this.kind});

  final ApiKeyKind kind;

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final palette = context.thermal;

    final saved = await showDialog<bool>(
      context: context,
      useRootNavigator: false,
      builder: (context) => AlertDialog(
        backgroundColor: palette.paper,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        titleTextStyle:
            Type.display.copyWith(fontSize: 20, color: palette.print),
        title: Text(kind.label),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Get one at ${kind.where}',
              style: Type.caption.copyWith(color: palette.faded),
            ),
            const SizedBox(height: Space.md),
            TextField(
              controller: controller,
              autofocus: true,
              // Not obscured: you are pasting a long opaque string and need to
              // see whether it arrived intact. It is only on screen while this
              // dialog is open, and is never shown again afterwards.
              style: Type.mono.copyWith(color: palette.print),
              decoration: const InputDecoration(hintText: 'Paste the key'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Save key'),
          ),
        ],
      ),
    );

    if (saved ?? false) {
      await ref.read(apiKeyStoreProvider).write(kind, controller.text);
      ref.invalidate(apiKeyPresenceProvider);
    }
    controller.dispose();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.thermal;
    final presence = ref.watch(apiKeyPresenceProvider);
    final isSet = presence.valueOrNull?[kind] ?? false;

    return Column(
      children: [
        InkWell(
          onTap: () => _edit(context, ref),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Space.lg,
              vertical: Space.md + 2,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        kind.label,
                        style: Type.item.copyWith(color: palette.print),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        kind.purpose,
                        style: Type.caption.copyWith(color: palette.faded),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: Space.md),
                // States what is true rather than showing a masked value:
                // there is nothing useful to see in ●●●●●●.
                Text(
                  isSet ? 'SET' : 'NOT SET',
                  style: Type.eyebrow.copyWith(
                    color: isSet ? palette.carbon : palette.faded,
                  ),
                ),
                if (isSet)
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    tooltip: 'Remove key',
                    onPressed: () async {
                      await ref.read(apiKeyStoreProvider).clear(kind);
                      ref.invalidate(apiKeyPresenceProvider);
                    },
                  ),
              ],
            ),
          ),
        ),
        const PerforatedRule(indent: Space.lg),
      ],
    );
  }
}

/// Export and restore of the on-device record.
class _BackupSection extends ConsumerStatefulWidget {
  const _BackupSection();

  @override
  ConsumerState<_BackupSection> createState() => _BackupSectionState();
}

class _BackupSectionState extends ConsumerState<_BackupSection> {
  bool _busy = false;

  Future<void> _export() async {
    setState(() => _busy = true);
    try {
      await AppBackup(
        ref.read(databaseProvider),
        ref.read(imageStoreProvider),
      ).share();
    } on Exception catch (e) {
      if (!mounted) return;
      showPaperSnack(context, message: 'Could not export: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    final palette = context.thermal;
    final confirmed = await showDialog<bool>(
      context: context,
      useRootNavigator: false,
      builder: (context) => AlertDialog(
        backgroundColor: palette.paper,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        titleTextStyle:
            Type.display.copyWith(fontSize: 20, color: palette.print),
        contentTextStyle: Type.body.copyWith(color: palette.print),
        title: const Text('Replace everything on this phone?'),
        content: const Text(
          'Lists, expenses, trips and receipt photos will be overwritten by '
          'the backup. The app will close; open it again and the copy is what '
          'you will see. API keys are not in the backup and will stay as they '
          'are.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep what is here'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Choose a backup'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      final path = await const BackupPicker().pickZip();
      if (path == null) return;
      final bytes = await File(path).readAsBytes();
      AppBackup.inspect(bytes);

      final database = ref.read(databaseProvider);
      final images = ref.read(imageStoreProvider);
      final livePath = database.path;
      final documents = await images.documentsRoot();

      await AppBackup.restore(
        zipBytes: bytes,
        liveDbPath: livePath,
        documentsRoot: documents,
        closeLive: database.close,
      );
      exit(0);
    } on Exception catch (e) {
      if (!mounted) return;
      showPaperSnack(context, message: 'Could not restore: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _DataRow(
          label: 'Export a copy',
          subtitle: 'A zip of the database and every receipt photo.',
          enabled: !_busy,
          onTap: _export,
        ),
        const PerforatedRule(indent: Space.lg),
        _DataRow(
          label: 'Restore a copy',
          subtitle: 'Replaces what is here. The app will close afterwards.',
          enabled: !_busy,
          onTap: _restore,
        ),
        const PerforatedRule(indent: Space.lg),
      ],
    );
  }
}

class _DataRow extends StatelessWidget {
  const _DataRow({
    required this.label,
    required this.subtitle,
    required this.onTap,
    required this.enabled,
  });

  final String label;
  final String subtitle;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;

    return InkWell(
      onTap: enabled ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Space.lg,
          vertical: Space.md + 2,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, style: Type.item.copyWith(color: palette.print)),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: Type.caption.copyWith(color: palette.faded),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 18,
              color: enabled ? palette.faded : palette.perforation,
            ),
          ],
        ),
      ),
    );
  }
}
