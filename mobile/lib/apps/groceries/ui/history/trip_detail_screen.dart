import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:shopping_list/apps/groceries/data/models/trip.dart';
import 'package:shopping_list/apps/groceries/data/models/trip_item.dart';
import 'package:shopping_list/core/design/theme.dart';
import 'package:shopping_list/core/design/tokens.dart';
import 'package:shopping_list/core/design/widgets/perforation.dart';
import 'package:shopping_list/apps/groceries/state/providers.dart';
import 'package:shopping_list/core/util/money.dart';

/// One past trip, laid out as the receipt it is: what was bought, then the
/// total, then the photo of the real slip.
class TripDetailScreen extends ConsumerWidget {
  const TripDetailScreen({super.key, required this.tripId});

  final int tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.thermal;
    final detail = ref.watch(tripDetailProvider(tripId));

    return Scaffold(
      backgroundColor: palette.paper,
      appBar: AppBar(title: const Text('Trip')),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('$e', style: Type.caption.copyWith(color: palette.faded)),
        ),
        data: (data) {
          if (data == null) {
            return Center(
              child: Text(
                'This trip is no longer here.',
                style: Type.body.copyWith(color: palette.faded),
              ),
            );
          }
          final (trip, items) = data;
          return _Detail(trip: trip, items: items);
        },
      ),
    );
  }
}

class _Detail extends ConsumerWidget {
  const _Detail({required this.trip, required this.items});

  final Trip trip;
  final List<TripItem> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.thermal;
    final date = trip.completedAt ?? trip.startedAt;
    final notFound = items.where((i) => !i.isPicked).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.xxl),
      children: [
        Text(
          DateFormat('EEEE d MMMM yyyy').format(date).toUpperCase(),
          style: Type.eyebrow.copyWith(color: palette.faded),
        ),
        if (trip.note != null && trip.note!.isNotEmpty) ...[
          const SizedBox(height: Space.sm),
          Text(trip.note!, style: Type.body.copyWith(color: palette.print)),
        ],
        const SizedBox(height: Space.md),
        const PerforatedRule(),
        const SizedBox(height: Space.md),

        for (final item in items) _DetailLine(item: item),

        const SizedBox(height: Space.md),
        const PerforatedRule(),
        const SizedBox(height: Space.lg),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text('TOTAL', style: Type.eyebrow.copyWith(color: palette.faded)),
            Text(
              Money.format(trip.totalMinor ?? 0),
              style: Type.totalDisplay.copyWith(color: palette.print),
            ),
          ],
        ),

        if (notFound > 0) ...[
          const SizedBox(height: Space.sm),
          Text(
            '$notFound ${notFound == 1 ? 'item was' : 'items were'} '
            'never found on this trip',
            style: Type.caption.copyWith(color: palette.faded),
          ),
        ],

        const SizedBox(height: Space.xl),
        const TearEdge(),
        const SizedBox(height: Space.xl),

        if (trip.receiptPath != null)
          _ReceiptImage(relativePath: trip.receiptPath!)
        else
          Text(
            'No receipt photo was attached to this trip.',
            style: Type.caption.copyWith(color: palette.faded),
          ),
      ],
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.item});

  final TripItem item;

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.sm),
      child: Row(
        children: [
          Expanded(
            child: Text(
              // The snapshot, not the current product name — this is a record
              // of what was bought that day and must not drift.
              item.nameSnapshot,
              style: Type.item.copyWith(
                color: item.isPicked ? palette.print : palette.faded,
              ),
            ),
          ),
          const SizedBox(width: Space.md),
          Text(
            item.measureLabel,
            style: Type.mono.copyWith(color: palette.faded),
          ),
        ],
      ),
    );
  }
}

class _ReceiptImage extends ConsumerWidget {
  const _ReceiptImage({required this.relativePath});

  final String relativePath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.thermal;

    return FutureBuilder<File>(
      future: ref.read(repositoryProvider).images.resolve(relativePath),
      builder: (context, snapshot) {
        final file = snapshot.data;
        if (file == null) {
          return Container(height: 240, color: palette.paperShade);
        }

        return GestureDetector(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => _ReceiptViewer(file: file),
            ),
          ),
          child: ClipRRect(
            borderRadius: Radii.media,
            child: Image.file(
              file,
              width: double.infinity,
              fit: BoxFit.fitWidth,
              errorBuilder: (context, _, __) => Container(
                height: 160,
                color: palette.paperShade,
                alignment: Alignment.center,
                child: Text(
                  'The receipt image is missing from storage.',
                  style: Type.caption.copyWith(color: palette.faded),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Full-screen, zoomable. Receipts are printed small and faintly, so being able
/// to zoom into a line is the entire reason for keeping the photo.
class _ReceiptViewer extends StatelessWidget {
  const _ReceiptViewer({required this.file});

  final File file;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Receipt'),
      ),
      body: InteractiveViewer(
        minScale: 1,
        maxScale: 6,
        child: Center(child: Image.file(file)),
      ),
    );
  }
}
