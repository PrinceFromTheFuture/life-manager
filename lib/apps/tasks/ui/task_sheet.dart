import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:shopping_list/apps/tasks/data/models/project.dart';
import 'package:shopping_list/apps/tasks/data/models/task_item.dart';
import 'package:shopping_list/apps/tasks/data/task_alerts.dart';
import 'package:shopping_list/apps/tasks/state/providers.dart';
import 'package:shopping_list/core/design/theme.dart';
import 'package:shopping_list/core/design/tokens.dart';

/// Title, due, urgency and repeat for a task.
class TaskSheet extends ConsumerStatefulWidget {
  const TaskSheet({super.key, required this.project, this.existing});

  final Project project;
  final TaskItem? existing;

  static Future<void> open(
    BuildContext context, {
    required Project project,
    TaskItem? existing,
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => TaskSheet(project: project, existing: existing),
      ),
    );
  }

  @override
  ConsumerState<TaskSheet> createState() => _TaskSheetState();
}

class _TaskSheetState extends ConsumerState<TaskSheet> {
  late final TextEditingController _title;
  late final TextEditingController _notes;
  DateTime? _dueAt;
  late int _projectId;
  late TaskUrgency _urgency;
  late TaskRepeat _repeat;
  bool _saving = false;

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _title = TextEditingController(text: existing?.title ?? '');
    _notes = TextEditingController(text: existing?.notes ?? '');
    _dueAt = existing?.dueAt;
    _projectId = existing?.projectId ?? widget.project.id!;
    _urgency = existing?.urgency ?? TaskUrgency.later;
    _repeat = existing?.repeat ?? TaskRepeat.none;
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDue() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _dueAt ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: _dueAt != null
          ? TimeOfDay.fromDateTime(_dueAt!)
          : const TimeOfDay(hour: 9, minute: 0),
    );
    if (!mounted) return;
    setState(() {
      _dueAt = DateTime(
        date.year,
        date.month,
        date.day,
        time?.hour ?? 9,
        time?.minute ?? 0,
      );
    });
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty || _saving) return;
    setState(() => _saving = true);
    if (_dueAt != null) {
      await TaskAlerts.instance.requestPermission();
    }
    final controller = ref.read(tasksControllerProvider);
    if (_editing) {
      await controller.updateTask(
        widget.existing!.copyWith(
          projectId: _projectId,
          title: title,
          notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
          clearNotes: _notes.text.trim().isEmpty,
          dueAt: _dueAt,
          clearDue: _dueAt == null,
          urgency: _urgency,
          repeat: _repeat,
        ),
      );
    } else {
      await controller.addTask(
        projectId: _projectId,
        title: title,
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        dueAt: _dueAt,
        urgency: _urgency,
        repeat: _repeat,
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;
    return Scaffold(
      backgroundColor: palette.paper,
      appBar: AppBar(
        title: Text(_editing ? 'Task' : 'New task'),
        actions: [
          TextButton(onPressed: _save, child: Text(_editing ? 'Save' : 'Add')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(Space.lg),
        children: [
          Text('PROJECT', style: Type.eyebrow.copyWith(color: palette.faded)),
          const SizedBox(height: Space.sm),
          ref.watch(livingProjectsProvider).when(
                loading: () => Text(
                  widget.project.name,
                  style: Type.body.copyWith(color: palette.print),
                ),
                error: (e, _) => Text('$e'),
                data: (projects) {
                  final options = [
                    for (final project in projects) project,
                    if (projects.every((p) => p.id != widget.project.id))
                      widget.project,
                  ];
                  return Wrap(
                    spacing: Space.sm,
                    runSpacing: Space.sm,
                    children: [
                      for (final project in options)
                        ChoiceChip(
                          label: Text(project.name),
                          selected: project.id == _projectId,
                          onSelected: (_) =>
                              setState(() => _projectId = project.id!),
                        ),
                    ],
                  );
                },
              ),
          const SizedBox(height: Space.lg),
          TextField(
            controller: _title,
            autofocus: !_editing,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Title',
              hintText: 'What needs doing',
            ),
          ),
          const SizedBox(height: Space.lg),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Due'),
            subtitle: Text(
              _dueAt == null
                  ? 'No date'
                  : DateFormat('EEE d MMM, HH:mm').format(_dueAt!.toLocal()),
            ),
            trailing: _dueAt == null
                ? TextButton(onPressed: _pickDue, child: const Text('Set'))
                : TextButton(
                    onPressed: () => setState(() => _dueAt = null),
                    child: const Text('Clear'),
                  ),
            onTap: _pickDue,
          ),
          const SizedBox(height: Space.md),
          Text('URGENCY', style: Type.eyebrow.copyWith(color: palette.faded)),
          const SizedBox(height: Space.sm),
          Wrap(
            spacing: Space.sm,
            children: [
              for (final urgency in TaskUrgency.values)
                ChoiceChip(
                  label: Text(urgency.id.toUpperCase()),
                  selected: _urgency == urgency,
                  onSelected: (_) => setState(() => _urgency = urgency),
                ),
            ],
          ),
          const SizedBox(height: Space.lg),
          Text('REPEAT', style: Type.eyebrow.copyWith(color: palette.faded)),
          const SizedBox(height: Space.sm),
          Wrap(
            spacing: Space.sm,
            children: [
              for (final repeat in TaskRepeat.values)
                ChoiceChip(
                  label: Text(repeat.id),
                  selected: _repeat == repeat,
                  onSelected: (_) => setState(() => _repeat = repeat),
                ),
            ],
          ),
          const SizedBox(height: Space.lg),
          TextField(
            controller: _notes,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Note'),
          ),
        ],
      ),
    );
  }
}
