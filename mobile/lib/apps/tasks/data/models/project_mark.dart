import 'package:flutter/material.dart';

import 'package:shopping_list/core/design/widgets/app_icon.dart';

/// A closed catalogue of life-area glyphs a project can wear.
///
/// Ink is chosen separately — a project is a hanging file, identified by
/// both the tab colour and the mark printed on it.
@immutable
class ProjectMark {
  const ProjectMark({
    required this.id,
    required this.label,
    required this.icon,
  });

  final String id;
  final String label;
  final SolarIconData icon;

  static const String fallbackId = codeId;
  static const String codeId = 'code';

  static const code = ProjectMark(
    id: codeId,
    label: 'Code',
    icon: SolarIcons.Code,
  );

  static const home = ProjectMark(
    id: 'home',
    label: 'Home',
    icon: SolarIcons.HomeSmile,
  );

  static const heart = ProjectMark(
    id: 'heart',
    label: 'Heart',
    icon: SolarIcons.Heart,
  );

  static const case_ = ProjectMark(
    id: 'case',
    label: 'Work',
    icon: SolarIcons.Case,
  );

  static const leaf = ProjectMark(
    id: 'leaf',
    label: 'Leaf',
    icon: SolarIcons.Leaf,
  );

  static const book = ProjectMark(
    id: 'book',
    label: 'Book',
    icon: SolarIcons.Book,
  );

  static const plane = ProjectMark(
    id: 'plane',
    label: 'Plane',
    icon: SolarIcons.Plain,
  );

  static const gym = ProjectMark(
    id: 'gym',
    label: 'Gym',
    icon: SolarIcons.DumbbellLargeMinimalistic,
  );

  static const wallet = ProjectMark(
    id: 'wallet',
    label: 'Wallet',
    icon: SolarIcons.Wallet,
  );

  static const cart = ProjectMark(
    id: 'cart',
    label: 'Cart',
    icon: SolarIcons.CartLarge,
  );

  static const palette = ProjectMark(
    id: 'palette',
    label: 'Palette',
    icon: SolarIcons.Palette,
  );

  static const bulb = ProjectMark(
    id: 'bulb',
    label: 'Idea',
    icon: SolarIcons.Lightbulb,
  );

  static const people = ProjectMark(
    id: 'people',
    label: 'People',
    icon: SolarIcons.UsersGroupRounded,
  );

  static const folder = ProjectMark(
    id: 'folder',
    label: 'Folder',
    icon: SolarIcons.Folder,
  );

  static const star = ProjectMark(
    id: 'star',
    label: 'Star',
    icon: SolarIcons.StarsMinimalistic,
  );

  static const flag = ProjectMark(
    id: 'flag',
    label: 'Flag',
    icon: SolarIcons.Flag,
  );

  static const camera = ProjectMark(
    id: 'camera',
    label: 'Camera',
    icon: SolarIcons.Camera,
  );

  static const cup = ProjectMark(
    id: 'cup',
    label: 'Cup',
    icon: SolarIcons.CupHot,
  );

  static const music = ProjectMark(
    id: 'music',
    label: 'Music',
    icon: SolarIcons.MusicNote,
  );

  static const settings = ProjectMark(
    id: 'settings',
    label: 'Settings',
    icon: SolarIcons.Settings,
  );

  static const List<ProjectMark> all = [
    code,
    home,
    heart,
    case_,
    leaf,
    book,
    plane,
    gym,
    wallet,
    cart,
    palette,
    bulb,
    people,
    folder,
    star,
    flag,
    camera,
    cup,
    music,
    settings,
  ];

  static ProjectMark byId(String? id) {
    if (id == null || id.isEmpty) return code;
    for (final mark in all) {
      if (mark.id == id) return mark;
    }
    return code;
  }

  static String next(Iterable<String> usedIds) {
    final used = usedIds.toSet();
    for (final mark in all) {
      if (!used.contains(mark.id)) return mark.id;
    }
    return all[used.length % all.length].id;
  }
}
