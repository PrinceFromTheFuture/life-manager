import 'package:flutter/material.dart';

import 'package:shopping_list/core/design/theme.dart';
import 'package:shopping_list/core/design/tokens.dart';
import 'package:shopping_list/core/util/money.dart';

/// The standard shape of a row in the hub feed.
///
/// Mini-apps aren't required to use this — [MiniApp.buildActivityRow] can
/// return anything — but using it is what makes a feed of mixed apps read as
/// one list rather than several pasted together. An app that needs something
/// genuinely different can still opt out.
///
/// The ink bar on the left is the only colour in the row, and it is how you
/// tell at a glance which app an entry came from.
class ActivityRowShell extends StatelessWidget {
  const ActivityRowShell({
    super.key,
    required this.ink,
    required this.title,
    this.subtitle,
    this.amountMinor,
    this.onTap,
  });

  final Color ink;
  final String title;
  final String? subtitle;
  final int? amountMinor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Space.lg,
          vertical: Space.md + 2,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // The stamp. A printed mark, not a dot or a pill — those read as
            // status indicators, which is the wrong promise.
            Container(width: 3, height: 26, color: ink),
            const SizedBox(width: Space.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: Type.item.copyWith(color: palette.print),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: Type.caption.copyWith(color: palette.faded),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            if (amountMinor != null) ...[
              const SizedBox(width: Space.md),
              Text(
                Money.format(amountMinor!),
                style: Type.monoBold.copyWith(color: palette.print),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
