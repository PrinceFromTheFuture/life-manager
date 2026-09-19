import 'package:flutter/foundation.dart';

import 'package:shopping_list/core/design/widgets/app_icon.dart';

/// A closed catalogue of glyphs a place can wear.
@immutable
class PlaceMark {
  const PlaceMark({
    required this.id,
    required this.label,
    required this.icon,
  });

  final String id;
  final String label;
  final SolarIconData icon;

  static const String fallbackId = homeId;
  static const String homeId = 'home';

  static const home = PlaceMark(
    id: homeId,
    label: 'Home',
    icon: SolarIcons.HomeSmile,
  );

  static const work = PlaceMark(
    id: 'work',
    label: 'Work',
    icon: SolarIcons.Case,
  );

  static const gym = PlaceMark(
    id: 'gym',
    label: 'Gym',
    icon: SolarIcons.DumbbellLargeMinimalistic,
  );

  static const people = PlaceMark(
    id: 'people',
    label: 'People',
    icon: SolarIcons.UsersGroupRounded,
  );

  static const heart = PlaceMark(
    id: 'heart',
    label: 'Heart',
    icon: SolarIcons.Heart,
  );

  static const cart = PlaceMark(
    id: 'cart',
    label: 'Shop',
    icon: SolarIcons.CartLarge,
  );

  static const cup = PlaceMark(
    id: 'cup',
    label: 'Cafe',
    icon: SolarIcons.CupHot,
  );

  static const pin = PlaceMark(
    id: 'pin',
    label: 'Pin',
    icon: SolarIcons.MapPoint,
  );

  static const plane = PlaceMark(
    id: 'plane',
    label: 'Travel',
    icon: SolarIcons.Plain,
  );

  static const leaf = PlaceMark(
    id: 'leaf',
    label: 'Park',
    icon: SolarIcons.Leaf,
  );

  static const book = PlaceMark(
    id: 'book',
    label: 'Study',
    icon: SolarIcons.Book,
  );

  static const wallet = PlaceMark(
    id: 'wallet',
    label: 'Bank',
    icon: SolarIcons.Wallet,
  );

  static const flag = PlaceMark(
    id: 'flag',
    label: 'Flag',
    icon: SolarIcons.Flag,
  );

  static const music = PlaceMark(
    id: 'music',
    label: 'Music',
    icon: SolarIcons.MusicNote,
  );

  static const camera = PlaceMark(
    id: 'camera',
    label: 'Photo',
    icon: SolarIcons.Camera,
  );

  static const List<PlaceMark> all = [
    home,
    work,
    gym,
    people,
    heart,
    cart,
    cup,
    pin,
    plane,
    leaf,
    book,
    wallet,
    flag,
    music,
    camera,
  ];

  static PlaceMark byId(String? id) {
    if (id == null || id.isEmpty) return home;
    for (final mark in all) {
      if (mark.id == id) return mark;
    }
    return home;
  }

  static String next(Iterable<String> usedIds) {
    final used = usedIds.toSet();
    for (final mark in all) {
      if (!used.contains(mark.id)) return mark.id;
    }
    return all[used.length % all.length].id;
  }
}
