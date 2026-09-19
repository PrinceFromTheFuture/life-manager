import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:shopping_list/apps/tasks/data/models/project.dart';
import 'package:shopping_list/apps/tasks/data/models/task_item.dart';
import 'package:shopping_list/apps/tasks/data/models/tray_entry.dart';
import 'package:shopping_list/apps/tasks/data/task_alerts.dart';
import 'package:shopping_list/apps/tasks/state/providers.dart';
import 'package:shopping_list/apps/tasks/ui/compose_drawer.dart';
import 'package:shopping_list/apps/tasks/ui/project_sheet.dart';
import 'package:shopping_list/apps/tasks/ui/snooze_sheet.dart';
import 'package:shopping_list/apps/tasks/ui/task_sheet.dart';
import 'package:shopping_list/core/design/theme.dart';
import 'package:shopping_list/core/design/tokens.dart';
import 'package:shopping_list/core/design/widgets/app_icon.dart';

/// Hanging-file spine on the left, tray or a project's papers on the right.
class TasksShell extends ConsumerStatefulWidget {
  const TasksShell({super.key, this.focusProjectId, this.focusTaskId});

  final int? focusProjectId;
  final int? focusTaskId;

  @override
  ConsumerState<TasksShell> createState() => _TasksShellState();
}

class _TasksShellState extends ConsumerState<TasksShell> {
  int? _selectedProjectId;
  int? _expandedId;
  int? _leavingId;

  @override
  void initState() {
    super.initState();
    _selectedProjectId = widget.focusProjectId;
    _expandedId = widget.focusTaskId;
    final taskId = widget.focusTaskId;
    if (taskId != null && widget.focusProjectId == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final task = await ref.read(tasksRepositoryProvider).task(taskId);
        if (!mounted || task == null) return;
        setState(() => _selectedProjectId = task.projectId);
      });
    }
  }

  void _selectProject(int? id) {
    setState(() {
      _selectedProjectId = id;
      _expandedId = null;
    });
  }

  Future<void> _compose() async {
    final projects = ref.read(livingProjectsProvider).valueOrNull ?? const [];
    final pick = await showComposeDrawer(
      context,
      projects: projects,
      currentProjectId: _selectedProjectId,
    );
    if (!mounted || pick == null) return;
    if (pick.newProject) {
      final id = await ProjectSheet.open(context);
      if (id != null && mounted) _selectProject(id);
      return;
    }
    final project = projects.cast<Project?>().firstWhere(
          (p) => p!.id == pick.projectId,
          orElse: () => null,
        );
    if (project == null) return;
    await TaskSheet.open(context, project: project);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;
    final projects = ref.watch(livingProjectsProvider).valueOrNull ?? const [];
    final selected = _selectedProjectId == null
        ? null
        : projects.cast<Project?>().firstWhere(
              (p) => p!.id == _selectedProjectId,
              orElse: () => null,
            );

    return Scaffold(
      backgroundColor: palette.paper,
      appBar: AppBar(
        title: const Text('Tasks'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _compose,
        tooltip: 'New',
        child: const AppIcon(SolarIcons.AddCircle),
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Spine(
            projects: projects,
            selectedId: _selectedProjectId,
            onTray: () => _selectProject(null),
            onProject: _selectProject,
            onEdit: (project) => ProjectSheet.open(context, existing: project),
          ),
          VerticalDivider(
            width: 1,
            thickness: 1,
            color: palette.perforation,
          ),
          Expanded(
            child: _selectedProjectId == null
                ? _TrayBody(
                    expandedId: _expandedId,
                    leavingId: _leavingId,
                    onExpand: (id) => setState(
                      () => _expandedId = _expandedId == id ? null : id,
                    ),
                    onToggle: _toggle,
                    onEdit: _edit,
                    onSnooze: _snooze,
                    onCompose: _compose,
                  )
                : _ProjectBody(
                    project: selected,
                    projectId: _selectedProjectId!,
                    expandedId: _expandedId,
                    leavingId: _leavingId,
                    onExpand: (id) => setState(
                      () => _expandedId = _expandedId == id ? null : id,
                    ),
                    onToggle: _toggle,
                    onEdit: _edit,
                    onSnooze: _snooze,
                    onCompose: _compose,
                    onEditProject: selected == null
                        ? null
                        : () => ProjectSheet.open(context, existing: selected),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _edit(Project project, TaskItem task) {
    return TaskSheet.open(context, project: project, existing: task);
  }

  Future<void> _snooze(TaskItem task) async {
    final until = await showSnoozeSheet(context);
    if (until == null || task.id == null) return;
    await TaskAlerts.instance.requestPermission();
    await ref.read(tasksControllerProvider).snoozeTask(task.id!, until);
  }

  Future<void> _toggle(TaskItem task) async {
    final id = task.id;
    if (id == null || _leavingId != null) return;
    if (task.isDone) {
      await ref.read(tasksControllerProvider).reopenTask(id);
      return;
    }
    // Repeating work stays in the open list — just roll the date forward.
    if (task.repeat != TaskRepeat.none) {
      await ref.read(tasksControllerProvider).completeTask(id);
      return;
    }
    setState(() => _leavingId = id);
    await Future<void>.delayed(Motion.settle);
    if (!mounted) return;
    await ref.read(tasksControllerProvider).completeTask(id);
    // Hold the row collapsed until the refreshed list no longer carries it.
    // Releasing on the write alone lets the card spring back open for the
    // frame between the write and the rebuild.
    await _awaitRefreshedList();
    if (mounted) {
      setState(() {
        _leavingId = null;
        if (_expandedId == id) _expandedId = null;
      });
    }
  }

  Future<void> _awaitRefreshedList() async {
    final projectId = _selectedProjectId;
    try {
      await (projectId == null
          ? ref.read(trayProvider.future)
          : ref.read(openTasksProvider(projectId).future));
    } on Object {
      // The list widget renders the error; this only gates the animation.
    }
  }
}

class _Spine extends StatelessWidget {
  const _Spine({
    required this.projects,
    required this.selectedId,
    required this.onTray,
    required this.onProject,
    required this.onEdit,
  });

  final List<Project> projects;
  final int? selectedId;
  final VoidCallback onTray;
  final ValueChanged<int> onProject;
  final ValueChanged<Project> onEdit;

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;
    return SizedBox(
      width: 64,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          children: [
            const SizedBox(height: Space.sm),
            _FileTab(
              selected: selectedId == null,
              ink: palette.print,
              icon: SolarIcons.Inbox,
              label: 'Tray',
              onTap: onTray,
            ),
            const SizedBox(height: Space.sm),
            Expanded(
              child: ListView(
                children: [
                  for (final project in projects)
                    Padding(
                      padding: const EdgeInsets.only(bottom: Space.sm),
                      child: _FileTab(
                        selected: selectedId == project.id,
                        ink: project.ink.of(Theme.of(context).brightness),
                        icon: project.mark.icon,
                        label: project.name,
                        onTap: () => onProject(project.id!),
                        onLongPress: () => onEdit(project),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FileTab extends StatelessWidget {
  const _FileTab({
    required this.selected,
    required this.ink,
    required this.icon,
    required this.label,
    required this.onTap,
    this.onLongPress,
  });

  final bool selected;
  final Color ink;
  final SolarIconData icon;
  final String label;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: selected ? ink.withValues(alpha: 0.10) : Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: Radii.key),
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: Radii.key,
          child: SizedBox(
            height: 48,
            child: Center(
              child: AppIcon(
                icon,
                size: 22,
                color: selected ? ink : palette.print,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ScreenHeader extends StatelessWidget {
  const _ScreenHeader({
    required this.icon,
    required this.ink,
    required this.title,
    this.onTap,
  });

  final SolarIconData icon;
  final Color ink;
  final String title;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;
    final row = Padding(
      padding:
          const EdgeInsets.fromLTRB(Space.md, Space.md, Space.md, Space.sm),
      child: Row(
        children: [
          AppIcon(icon, size: 28, color: ink),
          const SizedBox(width: Space.sm),
          Expanded(
            child: Text(
              title,
              style: Type.display.copyWith(color: palette.print, fontSize: 28),
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return row;
    return InkWell(onTap: onTap, child: row);
  }
}

class _TrayBody extends ConsumerWidget {
  const _TrayBody({
    required this.expandedId,
    required this.leavingId,
    required this.onExpand,
    required this.onToggle,
    required this.onEdit,
    required this.onSnooze,
    required this.onCompose,
  });

  final int? expandedId;
  final int? leavingId;
  final ValueChanged<int> onExpand;
  final ValueChanged<TaskItem> onToggle;
  final void Function(Project project, TaskItem task) onEdit;
  final ValueChanged<TaskItem> onSnooze;
  final VoidCallback onCompose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.thermal;
    final projects = ref.watch(livingProjectsProvider);
    final tray = ref.watch(trayProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ScreenHeader(
          icon: SolarIcons.Inbox,
          ink: palette.print,
          title: 'Tray',
        ),
        Expanded(
          child: Builder(
            builder: (context) {
              // Every write bumps the tick these providers watch. Reading the
              // last value rather than the loading state keeps a completed
              // card from blanking the whole page for a frame.
              final entries = tray.valueOrNull;
              if (entries == null) {
                return tray.hasError
                    ? Center(child: Text('${tray.error}'))
                    : const Center(child: CircularProgressIndicator());
              }
              final hasProjects = (projects.valueOrNull ?? const []).isNotEmpty;
              if (!hasProjects) {
                return _Empty(
                  title: 'Name a life you are keeping.',
                  body:
                      'A project is a hanging file — this app, the flat, the gym. Tasks live inside it.',
                  action: 'Open a project',
                  onAction: onCompose,
                );
              }
              if (entries.isEmpty) {
                return _Empty(
                  title: 'The tray is empty.',
                  body:
                      'Add a task, or wait — snoozed cards return here on their own.',
                  action: 'New',
                  onAction: onCompose,
                );
              }
              return _BandedList(
                entries: entries,
                expandedId: expandedId,
                leavingId: leavingId,
                showProjectName: true,
                onExpand: onExpand,
                onToggle: onToggle,
                onEdit: onEdit,
                onSnooze: onSnooze,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ProjectBody extends ConsumerStatefulWidget {
  const _ProjectBody({
    required this.projectId,
    required this.expandedId,
    required this.leavingId,
    required this.onExpand,
    required this.onToggle,
    required this.onEdit,
    required this.onSnooze,
    required this.onCompose,
    this.project,
    this.onEditProject,
  });

  final Project? project;
  final int projectId;
  final int? expandedId;
  final int? leavingId;
  final ValueChanged<int> onExpand;
  final ValueChanged<TaskItem> onToggle;
  final void Function(Project project, TaskItem task) onEdit;
  final ValueChanged<TaskItem> onSnooze;
  final VoidCallback onCompose;
  final VoidCallback? onEditProject;

  @override
  ConsumerState<_ProjectBody> createState() => _ProjectBodyState();
}

class _ProjectBodyState extends ConsumerState<_ProjectBody> {
  bool _completedOpen = false;

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;
    final project = ref.watch(projectProvider(widget.projectId));
    final open = ref.watch(openTasksProvider(widget.projectId));
    final done = ref.watch(doneTasksProvider(widget.projectId));

    // Reads fall back to the last value: every write bumps the tick these
    // providers watch, and rendering their reload as a spinner made the title
    // blink and the list jump on each completion.
    final p = project.valueOrNull ?? widget.project;
    if (p == null) {
      if (project.hasError) return Center(child: Text('${project.error}'));
      return project.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: Text(
                'That project is gone.',
                style: Type.body.copyWith(color: palette.faded),
              ),
            );
    }

    final ink = p.ink.of(Theme.of(context).brightness);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ScreenHeader(
          icon: p.mark.icon,
          ink: ink,
          title: p.name,
          onTap: widget.onEditProject,
        ),
        Expanded(
          child: Builder(
            builder: (context) {
              final items = open.valueOrNull;
              if (items == null) {
                return open.hasError
                    ? Center(child: Text('${open.error}'))
                    : const Center(child: CircularProgressIndicator());
              }
              final now = DateTime.now();
              final entries = [
                for (final task in items)
                  TrayEntry(
                    task: task,
                    project: p,
                    band: TrayEntry.bandFor(task, now) ?? TrayBand.later,
                  ),
              ]..sort((a, b) {
                  final byBand = a.band.rank.compareTo(b.band.rank);
                  if (byBand != 0) return byBand;
                  final aDue = a.task.dueAt?.millisecondsSinceEpoch ?? 1 << 62;
                  final bDue = b.task.dueAt?.millisecondsSinceEpoch ?? 1 << 62;
                  return aDue.compareTo(bDue);
                });
              final completed = done.valueOrNull ?? const <TaskItem>[];
              if (entries.isEmpty && completed.isEmpty) {
                return _Empty(
                  title: 'No cards in this file.',
                  body:
                      'Pull a task, or leave it empty — completing a project is rare.',
                  action: 'New task',
                  onAction: widget.onCompose,
                );
              }
              return _BandedList(
                entries: entries,
                completed: [
                  for (final task in completed)
                    TrayEntry(task: task, project: p, band: TrayBand.later),
                ],
                completedOpen: _completedOpen,
                onToggleCompleted: () =>
                    setState(() => _completedOpen = !_completedOpen),
                expandedId: widget.expandedId,
                leavingId: widget.leavingId,
                showProjectName: false,
                onExpand: widget.onExpand,
                onToggle: widget.onToggle,
                onEdit: widget.onEdit,
                onSnooze: widget.onSnooze,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _BandedList extends StatelessWidget {
  const _BandedList({
    required this.entries,
    required this.expandedId,
    required this.leavingId,
    required this.showProjectName,
    required this.onExpand,
    required this.onToggle,
    required this.onEdit,
    required this.onSnooze,
    this.completed = const [],
    this.completedOpen = false,
    this.onToggleCompleted,
  });

  final List<TrayEntry> entries;
  final List<TrayEntry> completed;
  final bool completedOpen;
  final VoidCallback? onToggleCompleted;
  final int? expandedId;
  final int? leavingId;
  final bool showProjectName;
  final ValueChanged<int> onExpand;
  final ValueChanged<TaskItem> onToggle;
  final void Function(Project project, TaskItem task) onEdit;
  final ValueChanged<TaskItem> onSnooze;

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;
    final children = <Widget>[];
    TrayBand? last;
    for (final entry in entries) {
      if (entry.band != last) {
        children.add(
          Padding(
            padding: EdgeInsets.only(
              top: last == null ? 0 : Space.md,
              bottom: Space.sm,
            ),
            child: Text(
              entry.band.label,
              style: Type.eyebrow.copyWith(color: palette.faded),
            ),
          ),
        );
        last = entry.band;
      }
      children.add(
        _TaskCard(
          key: ValueKey(entry.task.id),
          entry: entry,
          expanded: expandedId == entry.task.id,
          leaving: leavingId == entry.task.id,
          showProjectName: showProjectName,
          onExpand: () => onExpand(entry.task.id!),
          onToggle: () => onToggle(entry.task),
          onEdit: () => onEdit(entry.project, entry.task),
          onSnooze: () => onSnooze(entry.task),
        ),
      );
    }
    if (completed.isNotEmpty && onToggleCompleted != null) {
      children.add(
        _CompletedHeader(
          count: completed.length,
          open: completedOpen,
          onTap: onToggleCompleted!,
        ),
      );
      if (completedOpen) {
        for (final entry in completed) {
          children.add(
            _TaskCard(
              key: ValueKey('done-${entry.task.id}'),
              entry: entry,
              expanded: expandedId == entry.task.id,
              leaving: false,
              showProjectName: showProjectName,
              onExpand: () => onExpand(entry.task.id!),
              onToggle: () => onToggle(entry.task),
              onEdit: () => onEdit(entry.project, entry.task),
              onSnooze: () => onSnooze(entry.task),
            ),
          );
        }
      }
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        Space.md,
        Space.sm,
        Space.md,
        Space.xxl + 56,
      ),
      children: children,
    );
  }
}

class _CompletedHeader extends StatelessWidget {
  const _CompletedHeader({
    required this.count,
    required this.open,
    required this.onTap,
  });

  final int count;
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;
    return Padding(
      padding: const EdgeInsets.only(top: Space.xl, bottom: Space.sm),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: Radii.key,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: Space.sm),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'COMPLETED · $count',
                    style: Type.eyebrow.copyWith(color: palette.faded),
                  ),
                ),
                AppIcon(
                  open ? SolarIcons.AltArrowUp : SolarIcons.AltArrowDown,
                  size: 18,
                  color: palette.faded,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    super.key,
    required this.entry,
    required this.expanded,
    required this.leaving,
    required this.showProjectName,
    required this.onExpand,
    required this.onToggle,
    required this.onEdit,
    required this.onSnooze,
  });

  final TrayEntry entry;
  final bool expanded;
  final bool leaving;
  final bool showProjectName;
  final VoidCallback onExpand;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onSnooze;

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;
    final ink = entry.project.ink.of(Theme.of(context).brightness);
    final task = entry.task;
    final due = _dueLabel(task.dueAt);
    final printInk = task.isDone ? palette.faded : palette.print;

    return ClipRRect(
      borderRadius: Radii.key,
      child: AnimatedAlign(
        duration: Motion.settle,
        curve: Motion.heat,
        heightFactor: leaving ? 0 : 1,
        alignment: Alignment.topCenter,
        child: IgnorePointer(
          ignoring: leaving,
          child: Padding(
            padding: const EdgeInsets.only(bottom: Space.sm),
            child: ClipRRect(
              borderRadius: Radii.key,
              child: Material(
                color: Color.alphaBlend(
                  ink.withValues(alpha: 0.10),
                  palette.paper,
                ),
                child: InkWell(
                  onTap: onExpand,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Space.md,
                      Space.sm,
                      Space.sm,
                      Space.sm,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _ConfirmMark(
                              done: task.isDone,
                              ink: ink,
                              paper: palette.paper,
                              onTap: onToggle,
                            ),
                            const SizedBox(width: Space.sm),
                            Expanded(
                              child: Padding(
                                padding:
                                    const EdgeInsets.only(top: 6, bottom: 6),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      task.title,
                                      style:
                                          Type.item.copyWith(color: printInk),
                                    ),
                                    if (!expanded && due != null)
                                      Text(
                                        due,
                                        style: Type.caption
                                            .copyWith(color: palette.faded),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            if (expanded)
                              IconButton(
                                tooltip: 'Edit',
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 36,
                                  minHeight: 36,
                                ),
                                icon: const AppIcon(SolarIcons.Pen, size: 18),
                                color: palette.faded,
                                onPressed: onEdit,
                              ),
                          ],
                        ),
                        AnimatedSize(
                          duration: Motion.settle,
                          curve: Motion.heat,
                          alignment: Alignment.topCenter,
                          child: expanded
                              ? Padding(
                                  padding: const EdgeInsets.only(
                                    left: 44,
                                    top: Space.xs,
                                    right: Space.sm,
                                  ),
                                  child: _TaskDetails(
                                    task: task,
                                    projectName: showProjectName
                                        ? entry.project.name
                                        : null,
                                    onSnooze: task.isDone ? null : onSnooze,
                                  ),
                                )
                              : const SizedBox(width: double.infinity),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ConfirmMark extends StatelessWidget {
  const _ConfirmMark({
    required this.done,
    required this.ink,
    required this.paper,
    required this.onTap,
  });

  final bool done;
  final Color ink;
  final Color paper;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      checked: done,
      label: done ? 'Reopen' : 'Complete',
      child: InkWell(
        onTap: onTap,
        customBorder: const RoundedRectangleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: AnimatedContainer(
            duration: Motion.quick,
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: done ? ink : Colors.transparent,
              border: Border.all(color: ink, width: 1.5),
            ),
            child: done
                ? AppIcon(SolarIcons.CheckCircle, size: 14, color: paper)
                : null,
          ),
        ),
      ),
    );
  }
}

class _TaskDetails extends StatelessWidget {
  const _TaskDetails({
    required this.task,
    required this.projectName,
    required this.onSnooze,
  });

  final TaskItem task;
  final String? projectName;
  final VoidCallback? onSnooze;

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;
    final lines = <String>[
      if (projectName != null) projectName!,
      if (task.dueAt != null)
        DateFormat('EEE d MMM, HH:mm').format(task.dueAt!.toLocal()),
      task.urgency.id.toUpperCase(),
      if (task.repeat != TaskRepeat.none) 'Repeats ${task.repeat.id}',
      if (task.notes != null && task.notes!.isNotEmpty) task.notes!,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final line in lines)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(
              line,
              style: Type.caption.copyWith(color: palette.faded),
            ),
          ),
        if (onSnooze != null)
          TextButton(
            onPressed: onSnooze,
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Snooze'),
          ),
      ],
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({
    required this.title,
    required this.body,
    required this.action,
    required this.onAction,
  });

  final String title;
  final String body;
  final String action;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;
    return Padding(
      padding: const EdgeInsets.all(Space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Type.display.copyWith(color: palette.print, fontSize: 26),
          ),
          const SizedBox(height: Space.md),
          Text(body, style: Type.body.copyWith(color: palette.faded)),
          const SizedBox(height: Space.lg),
          FilledButton(onPressed: onAction, child: Text(action)),
        ],
      ),
    );
  }
}

String? _dueLabel(DateTime? due) {
  if (due == null) return null;
  return DateFormat('EEE d MMM').format(due.toLocal());
}
