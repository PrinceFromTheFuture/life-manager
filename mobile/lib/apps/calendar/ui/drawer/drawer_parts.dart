import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:shopping_list/apps/calendar/ui/night.dart';
import 'package:shopping_list/core/design/theme.dart';
import 'package:shopping_list/core/design/tokens.dart';
import 'package:shopping_list/core/design/widgets/app_icon.dart';

/// Small eyebrow over a group of rows.
class DrawerLabel extends StatelessWidget {
  const DrawerLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.xs, Space.lg, 0, Space.sm),
      child: Text(
        text.toUpperCase(),
        style: Type.eyebrow.copyWith(color: Night.mist, letterSpacing: 1.1),
      ),
    );
  }
}

/// Rows pressed into one well, split by hairlines.
class DrawerGroup extends StatelessWidget {
  const DrawerGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.all(Radius.circular(18)),
      child: ColoredBox(
        color: Night.well,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0)
                const Padding(
                  padding: EdgeInsets.only(left: 52),
                  child: Divider(height: 1, thickness: 1, color: Night.hairline),
                ),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}

/// One tappable line: icon, label, value, and a chevron when it leads on.
class DrawerRow extends StatelessWidget {
  const DrawerRow({
    super.key,
    required this.icon,
    required this.label,
    this.value,
    this.onTap,
    this.iconColor,
    this.valueColor,
    this.labelColor,
    this.trailing,
    this.chevron = true,
  });

  final SolarIconData icon;
  final String label;
  final String? value;
  final VoidCallback? onTap;
  final Color? iconColor;
  final Color? valueColor;
  final Color? labelColor;
  final Widget? trailing;
  final bool chevron;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                onTap!();
              },
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 54),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.md + 2),
            child: Row(
              children: [
                AppIcon(icon, size: 22, color: iconColor ?? Night.mist),
                const SizedBox(width: Space.md + 2),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Type.item.copyWith(color: labelColor ?? Night.bone),
                  ),
                ),
                if (value != null)
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.only(left: Space.sm),
                      child: Text(
                        value!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                        style: Type.item.copyWith(color: valueColor ?? Night.mist),
                      ),
                    ),
                  ),
                if (trailing != null) ...[
                  const SizedBox(width: Space.sm),
                  trailing!,
                ],
                if (chevron && onTap != null) ...[
                  const SizedBox(width: Space.xs),
                  const AppIcon(SolarIcons.AltArrowRight, size: 16, color: Night.mist),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The one bone plate a view commits with.
class DrawerPrimaryButton extends StatelessWidget {
  const DrawerPrimaryButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onTap;
  final SolarIconData? icon;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null && !busy;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: enabled || busy ? 1 : 0.35,
        child: Material(
          color: Night.bone,
          borderRadius: const BorderRadius.all(Radius.circular(16)),
          child: InkWell(
            borderRadius: const BorderRadius.all(Radius.circular(16)),
            onTap: enabled
                ? () {
                    HapticFeedback.lightImpact();
                    onTap!();
                  }
                : null,
            child: SizedBox(
              height: 54,
              child: Center(
                child: busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Night.ink),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (icon != null) ...[
                            AppIcon(icon!, size: 20, color: Night.ink),
                            const SizedBox(width: Space.sm),
                          ],
                          Flexible(
                            child: Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Type.button.copyWith(color: Night.ink),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A quieter companion to [DrawerPrimaryButton].
class DrawerSecondaryButton extends StatelessWidget {
  const DrawerSecondaryButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.color,
  });

  final String label;
  final VoidCallback? onTap;
  final SolarIconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final ink = color ?? Night.bone;
    return Material(
      color: Night.well,
      borderRadius: const BorderRadius.all(Radius.circular(16)),
      child: InkWell(
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        onTap: onTap == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                onTap!();
              },
        child: SizedBox(
          height: 54,
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  AppIcon(icon!, size: 20, color: ink),
                  const SizedBox(width: Space.sm),
                ],
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Type.button.copyWith(color: ink),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bottom of a view: buttons pinned above the safe area.
class DrawerFooter extends StatelessWidget {
  const DrawerFooter({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.lg, Space.md, Space.lg, Space.lg),
      child: Row(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: Space.sm),
            Expanded(child: children[i]),
          ],
        ],
      ),
    );
  }
}

/// Minus, value, plus.
class DrawerStepper extends StatelessWidget {
  const DrawerStepper({
    super.key,
    required this.value,
    this.onMinus,
    this.onPlus,
  });

  final String value;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;

  @override
  Widget build(BuildContext context) {
    Widget key(SolarIconData icon, VoidCallback? onTap) => NightRoundButton(
          icon: icon,
          label: icon == SolarIcons.MinusCircle ? 'Less' : 'More',
          size: 32,
          onTap: onTap == null
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  onTap();
                },
        );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        key(SolarIcons.MinusCircle, onMinus),
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 44),
          child: Text(
            value,
            textAlign: TextAlign.center,
            style: Type.monoBold.copyWith(color: Night.bone),
          ),
        ),
        key(SolarIcons.AddCircle, onPlus),
      ],
    );
  }
}

/// A pill that toggles, for weekdays and the like.
class DrawerChoice extends StatelessWidget {
  const DrawerChoice({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.size,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final double? size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: size,
          height: size ?? 38,
          padding: size == null ? const EdgeInsets.symmetric(horizontal: Space.md + 2) : null,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? Night.bone : Night.well,
            borderRadius: BorderRadius.all(Radius.circular(size == null ? 19 : size! / 2)),
          ),
          child: Text(
            label,
            style: Type.item.copyWith(
              fontSize: 14,
              color: selected ? Night.ink : Night.bone,
            ),
          ),
        ),
      ),
    );
  }
}

/// A round control on the drawer surface.
class NightRoundButton extends StatelessWidget {
  const NightRoundButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.size = 36,
  });

  final SolarIconData icon;
  final String label;
  final VoidCallback? onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: Night.well,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: size,
            height: size,
            child: Center(
              child: AppIcon(
                icon,
                size: size * 0.5,
                color: onTap == null ? Night.mist.withValues(alpha: 0.5) : Night.bone,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
