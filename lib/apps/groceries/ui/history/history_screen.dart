import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:shopping_list/apps/groceries/data/models/trip.dart';
import 'package:shopping_list/core/design/theme.dart';
import 'package:shopping_list/core/design/tokens.dart';
import 'package:shopping_list/core/design/widgets/perforation.dart';
import 'package:shopping_list/apps/groceries/state/providers.dart';
import 'package:shopping_list/core/util/money.dart';
import 'package:shopping_list/apps/groceries/ui/history/trip_detail_screen.dart';

/// Past trips, as a stack of receipts torn off the roll.
///
/// The tear edge earns its second appearance here: each entry really is a
/// separate slip, so ending every one with a tear is the same idea applied
/// consistently rather than a new device.
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.thermal;
    final historyAsync = ref.watch(historyProvider);

    return Scaffold(
      backgroundColor: palette.paper,
      appBar: AppBar(title: const Text('Past trips')),
      body: historyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('$e', style: Type.caption.copyWith(color: palette.faded)),
        ),
        data: (trips) {
          if (trips.isEmpty) return const _NoTrips();
          return ListView.builder(
            padding: const EdgeInsets.only(bottom: Space.xxl),
            itemCount: trips.length,
            itemBuilder: (context, i) => _TripSlip(summary: trips[i]),
          );
        },
      ),
    );
  }
}

class _TripSlip extends ConsumerWidget {
  const _TripSlip({required this.summary});

  final TripSummary summary;

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    // A confirmation is earned here and nowhere else in the app: this deletes
    // the receipt photo too, and there is no undo for that.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.thermal.paper,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        titleTextStyle:
            Type.display.copyWith(fontSize: 20, color: context.thermal.print),
        contentTextStyle: Type.body.copyWith(color: context.thermal.print),
        title: const Text('Delete this trip?'),
        content: const Text(
          'The items, the total and the receipt photo are deleted for good.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed ?? false) {
      await ref.read(historyProvider.notifier).deleteTrip(summary.trip.id!);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.thermal;
    final trip = summary.trip;
    final date = trip.completedAt ?? trip.startedAt;

    return Column(
      children: [
        InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => TripDetailScreen(tripId: trip.id!),
            ),
          ),
          onLongPress: () => _confirmDelete(context, ref),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.lg,
              Space.lg,
              Space.lg,
              Space.md,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat('d MMM yyyy').format(date).toUpperCase(),
                        style: Type.eyebrow.copyWith(color: palette.faded),
                      ),
                      const SizedBox(height: Space.sm),
                      Text(
                        Money.format(trip.totalMinor ?? 0),
                        style: Type.totalDisplay.copyWith(
                          color: palette.print,
                          fontSize: 32,
                        ),
                      ),
                      const SizedBox(height: Space.xs),
                      Text(
                        '${summary.itemCount} '
                        '${summary.itemCount == 1 ? 'item' : 'items'}'
                        '${trip.note != null && trip.note!.isNotEmpty ? ' · ${trip.note}' : ''}',
                        style: Type.caption.copyWith(color: palette.faded),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: Space.md),
                _ReceiptThumb(relativePath: trip.receiptPath),
              ],
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(bottom: Space.sm),
          child: TearEdge(),
        ),
      ],
    );
  }
}

class _ReceiptThumb extends ConsumerWidget {
  const _ReceiptThumb({required this.relativePath});

  final String? relativePath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.thermal;

    if (relativePath == null) {
      return Container(
        width: 56,
        height: 72,
        decoration: BoxDecoration(
          border: Border.all(color: palette.perforation),
        ),
        alignment: Alignment.center,
        child: Icon(Icons.receipt_outlined, size: 18, color: palette.faded),
      );
    }

    return FutureBuilder<File>(
      future: ref.read(repositoryProvider).images.resolve(relativePath!),
      builder: (context, snapshot) {
        final file = snapshot.data;
        if (file == null) {
          return Container(width: 56, height: 72, color: palette.paperShade);
        }
        return ClipRRect(
          borderRadius: Radii.media,
          child: Image.file(
            file,
            width: 56,
            height: 72,
            fit: BoxFit.cover,
            errorBuilder: (context, _, __) => Container(
              width: 56,
              height: 72,
              color: palette.paperShade,
            ),
          ),
        );
      },
    );
  }
}

class _NoTrips extends StatelessWidget {
  const _NoTrips();

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const PerforatedRule(),
            const SizedBox(height: Space.lg),
            Text(
              'No trips yet.',
              style: Type.display.copyWith(color: palette.print, fontSize: 28),
            ),
            const SizedBox(height: Space.md),
            Text(
              'Finish a shop and it lands here — what you bought, what it cost, '
              'and the receipt.',
              style: Type.body.copyWith(color: palette.faded),
            ),
          ],
        ),
      ),
    );
  }
}
