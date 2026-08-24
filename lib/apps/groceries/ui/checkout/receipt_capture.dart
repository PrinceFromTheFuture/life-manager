import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:shopping_list/core/design/paper_snack.dart';
import 'package:shopping_list/core/design/theme.dart';
import 'package:shopping_list/core/design/tokens.dart';
import 'package:shopping_list/apps/groceries/state/providers.dart';
import 'package:shopping_list/core/design/widgets/app_icon.dart';

/// Photographs or picks the receipt for a trip.
///
/// The image is downscaled at capture time rather than stored at full sensor
/// resolution: a receipt only has to be legible, and a year of 12-megapixel
/// photos is a lot of storage to spend on that.
class ReceiptCapture extends ConsumerStatefulWidget {
  const ReceiptCapture({super.key, required this.receiptPath});

  /// Path relative to the documents directory, or null if none attached yet.
  final String? receiptPath;

  @override
  ConsumerState<ReceiptCapture> createState() => _ReceiptCaptureState();
}

class _ReceiptCaptureState extends ConsumerState<ReceiptCapture> {
  bool _busy = false;

  Future<void> _pick(ImageSource source) async {
    setState(() => _busy = true);

    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 2000,
        imageQuality: 85,
      );
      if (picked == null) return;
      await ref.read(activeListProvider.notifier).attachReceipt(picked.path);
    } on Exception catch (e) {
      // State what happened and what to do about it. No apology, no vagueness.
      if (!mounted) return;
      showPaperSnack(
        context,
        message: source == ImageSource.camera
            ? "Couldn't open the camera. Check camera access in Settings, "
                'or choose a photo instead. ($e)'
            : "Couldn't load that photo. Try another one. ($e)",
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final path = widget.receiptPath;

    if (path != null) {
      return _AttachedReceipt(
        relativePath: path,
        onReplace: _busy ? null : () => _pick(ImageSource.camera),
        onRemove: _busy
            ? null
            : () => ref.read(activeListProvider.notifier).removeReceipt(),
      );
    }

    return Row(
      children: [
        Expanded(
          flex: 2,
          child: FilledButton.icon(
            onPressed: _busy ? null : () => _pick(ImageSource.camera),
            icon: const AppIcon(SolarIcons.CameraMinimalistic, size: 20),
            label: const Text('Photograph receipt'),
          ),
        ),
        const SizedBox(width: Space.md),
        Expanded(
          child: OutlinedButton(
            onPressed: _busy ? null : () => _pick(ImageSource.gallery),
            child: const Text('Choose'),
          ),
        ),
      ],
    );
  }
}

class _AttachedReceipt extends ConsumerWidget {
  const _AttachedReceipt({
    required this.relativePath,
    required this.onReplace,
    required this.onRemove,
  });

  final String relativePath;
  final VoidCallback? onReplace;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.thermal;
    final store = ref.read(repositoryProvider).images;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: Radii.media,
          child: FutureBuilder<File>(
            future: store.resolve(relativePath),
            builder: (context, snapshot) {
              final file = snapshot.data;
              if (file == null) {
                return Container(height: 180, color: palette.paperShade);
              }
              return Image.file(
                file,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
                // The file can genuinely be gone — cleared cache, restored
                // backup — so say so plainly instead of rendering a broken box.
                errorBuilder: (context, _, __) => Container(
                  height: 180,
                  color: palette.paperShade,
                  alignment: Alignment.center,
                  child: Text(
                    'Receipt image is missing',
                    style: Type.caption.copyWith(color: palette.faded),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: Space.sm),
        Row(
          children: [
            TextButton(onPressed: onReplace, child: const Text('Retake')),
            const SizedBox(width: Space.sm),
            TextButton(onPressed: onRemove, child: const Text('Remove')),
          ],
        ),
      ],
    );
  }
}
