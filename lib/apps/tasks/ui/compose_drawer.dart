import 'package:flutter/material.dart';

import 'package:shopping_list/apps/tasks/data/models/project.dart';
import 'package:shopping_list/core/design/theme.dart';
import 'package:shopping_list/core/design/tokens.dart';
import 'package:shopping_list/core/design/widgets/app_icon.dart';
import 'package:shopping_list/core/design/widgets/inset_drawer.dart';

/// What the compose drawer resolved to.
class ComposePick {
  const ComposePick.task(this.projectId) : newProject = false;
  const ComposePick.project()
      : projectId = null,
        newProject = true;

  final int? projectId;
  final bool newProject;
}

/// New task or new project — one add control, two outcomes.
Future<ComposePick?> showComposeDrawer(
  BuildContext context, {
  required List<Project> projects,
  int? currentProjectId,
}) {
  return showInsetDrawer<ComposePick>(
    context: context,
    primary: (_) => _ComposeMenu(
      projects: projects,
      currentProjectId: currentProjectId,
    ),
    views: {
      'project': (_) => _PickProject(projects: projects),
    },
  );
}

class _ComposeMenu extends StatelessWidget {
  const _ComposeMenu({
    required this.projects,
    required this.currentProjectId,
  });

  final List<Project> projects;
  final int? currentProjectId;

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;
    final scope = DrawerScope.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.lg, Space.sm, Space.lg, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('NEW', style: Type.eyebrow.copyWith(color: palette.faded)),
          const SizedBox(height: Space.md),
          _row(
            context,
            icon: SolarIcons.Checklist,
            title: 'New task',
            subtitle: currentProjectId == null
                ? 'File it in a project'
                : 'Add to this file',
            onTap: () {
              if (currentProjectId != null) {
                Navigator.pop(context, ComposePick.task(currentProjectId!));
                return;
              }
              if (projects.length == 1) {
                Navigator.pop(context, ComposePick.task(projects.single.id!));
                return;
              }
              if (projects.isEmpty) {
                Navigator.pop(context, const ComposePick.project());
                return;
              }
              scope.open('project');
            },
          ),
          _row(
            context,
            icon: SolarIcons.Folder,
            title: 'New project',
            subtitle: 'A hanging file for a life',
            onTap: () => Navigator.pop(context, const ComposePick.project()),
          ),
        ],
      ),
    );
  }

  Widget _row(
    BuildContext context, {
    required SolarIconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final palette = context.thermal;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: AppIcon(icon, color: palette.print),
      title: Text(title, style: Type.item.copyWith(color: palette.print)),
      subtitle:
          Text(subtitle, style: Type.caption.copyWith(color: palette.faded)),
      onTap: onTap,
    );
  }
}

class _PickProject extends StatelessWidget {
  const _PickProject({required this.projects});

  final List<Project> projects;

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const DrawerViewHeader(title: 'Which file'),
          for (final project in projects)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: AppIcon(
                project.mark.icon,
                color: project.ink.of(Theme.of(context).brightness),
              ),
              title: Text(
                project.name,
                style: Type.item.copyWith(color: palette.print),
              ),
              onTap: () => Navigator.pop(context, ComposePick.task(project.id!)),
            ),
        ],
      ),
    );
  }
}
