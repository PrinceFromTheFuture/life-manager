import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shopping_list/apps/tasks/data/models/project.dart';
import 'package:shopping_list/apps/tasks/data/models/project_mark.dart';
import 'package:shopping_list/apps/tasks/state/providers.dart';
import 'package:shopping_list/core/design/stamp_ink.dart';
import 'package:shopping_list/core/design/theme.dart';
import 'package:shopping_list/core/design/tokens.dart';
import 'package:shopping_list/core/design/widgets/app_icon.dart';
import 'package:shopping_list/core/design/widgets/ink_pad.dart';

/// Name, ink and icon for a project.
class ProjectSheet extends ConsumerStatefulWidget {
  const ProjectSheet({super.key, this.existing});

  final Project? existing;

  static Future<int?> open(BuildContext context, {Project? existing}) {
    return Navigator.of(context).push<int>(
      MaterialPageRoute<int>(
        fullscreenDialog: true,
        builder: (_) => ProjectSheet(existing: existing),
      ),
    );
  }

  @override
  ConsumerState<ProjectSheet> createState() => _ProjectSheetState();
}

class _ProjectSheetState extends ConsumerState<ProjectSheet> {
  late final TextEditingController _name;
  late StampInk _ink;
  late ProjectMark _mark;
  bool _saving = false;

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _name = TextEditingController(text: existing?.name ?? '');
    _ink = existing?.ink ?? StampInk.ledger;
    _mark = existing?.mark ?? ProjectMark.code;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty || _saving) return;
    setState(() => _saving = true);
    final controller = ref.read(tasksControllerProvider);
    if (_editing) {
      await controller.updateProject(
        widget.existing!.copyWith(
          name: name,
          inkId: _ink.id,
          iconId: _mark.id,
        ),
      );
      if (mounted) Navigator.of(context).pop(widget.existing!.id);
    } else {
      final created = await controller.addProject(
        name: name,
        inkId: _ink.id,
        iconId: _mark.id,
      );
      if (mounted) Navigator.of(context).pop(created.id);
    }
  }

  Future<void> _archive() async {
    final id = widget.existing?.id;
    if (id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        final palette = context.thermal;
        return AlertDialog(
          backgroundColor: palette.paper,
          title: const Text('File this project away?'),
          content: const Text(
            'It leaves the spine. Completing a project is rare — only do this when the work is actually over.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep it'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('File away'),
            ),
          ],
        );
      },
    );
    if (ok != true || !mounted) return;
    await ref.read(tasksControllerProvider).archiveProject(id);
    if (mounted) Navigator.of(context).pop(id);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;
    return Scaffold(
      backgroundColor: palette.paper,
      appBar: AppBar(
        title: Text(_editing ? 'Project' : 'New project'),
        actions: [
          TextButton(
            onPressed: _save,
            child: Text(_editing ? 'Save' : 'Create'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(Space.lg),
        children: [
          TextField(
            controller: _name,
            autofocus: !_editing,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Name',
              hintText: 'This app, the flat, the gym…',
            ),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: Space.xl),
          Text('INK', style: Type.eyebrow.copyWith(color: palette.faded)),
          const SizedBox(height: Space.sm),
          Wrap(
            spacing: Space.md,
            runSpacing: Space.md,
            children: [
              for (final ink in StampInk.all)
                StampInkPad(
                  ink: ink,
                  selected: ink.id == _ink.id,
                  showLabel: false,
                  onTap: () => setState(() => _ink = ink),
                ),
            ],
          ),
          const SizedBox(height: Space.xl),
          Text('MARK', style: Type.eyebrow.copyWith(color: palette.faded)),
          const SizedBox(height: Space.sm),
          Wrap(
            spacing: Space.sm,
            runSpacing: Space.sm,
            children: [
              for (final mark in ProjectMark.all)
                _IconWell(
                  mark: mark,
                  selected: mark.id == _mark.id,
                  ink: _ink,
                  onTap: () => setState(() => _mark = mark),
                ),
            ],
          ),
          if (_editing) ...[
            const SizedBox(height: Space.xxl),
            TextButton(
              onPressed: _archive,
              child: Text(
                'File this project away',
                style: Type.body.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _IconWell extends StatelessWidget {
  const _IconWell({
    required this.mark,
    required this.selected,
    required this.ink,
    required this.onTap,
  });

  final ProjectMark mark;
  final bool selected;
  final StampInk ink;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;
    final fill = ink.of(Theme.of(context).brightness);
    return Semantics(
      button: true,
      selected: selected,
      label: mark.label,
      child: Material(
        color: selected ? fill : palette.paperShade,
        shape: RoundedRectangleBorder(
          borderRadius: Radii.key,
          side: BorderSide(
            color: selected ? palette.print : Colors.transparent,
            width: 2,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: Radii.key,
          child: SizedBox(
            width: 48,
            height: 48,
            child: Center(
              child: AppIcon(
                mark.icon,
                size: 22,
                color: selected ? palette.paper : palette.print,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
