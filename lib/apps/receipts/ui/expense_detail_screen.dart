import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import 'package:shopping_list/apps/receipts/data/finance/installment_plan.dart';
import 'package:shopping_list/apps/receipts/data/models/category_ink.dart';
import 'package:shopping_list/apps/receipts/data/models/expense.dart';
import 'package:shopping_list/apps/receipts/state/providers.dart';
import 'package:shopping_list/apps/receipts/ui/expense_sheet.dart';
import 'package:shopping_list/apps/receipts/ui/place_map.dart';
import 'package:shopping_list/apps/receipts/ui/widgets/category_stamp.dart';
import 'package:shopping_list/core/design/paper_snack.dart';
import 'package:shopping_list/core/design/theme.dart';
import 'package:shopping_list/core/design/tokens.dart';
import 'package:shopping_list/core/design/widgets/perforation.dart';
import 'package:shopping_list/core/util/money.dart';
import 'package:shopping_list/core/design/widgets/app_icon.dart';

/// Asks before destroying a receipt photo. Used from the list swipe and from
/// the slip itself, so the wording is learned once.
///
/// [hasReceipt] is false for rows a standing order wrote, where promising to
/// delete a photo that never existed would be a small lie.
Future<bool> confirmDeleteExpense(
  BuildContext context, {
  bool hasReceipt = true,
}) async {
  final palette = context.thermal;
  return await showDialog<bool>(
        context: context,
        // Keeps the dialog inside this app's ink; the root navigator is above
        // the InkScope.
        useRootNavigator: false,
        builder: (context) => AlertDialog(
          backgroundColor: palette.paper,
          surfaceTintColor: Colors.transparent,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          titleTextStyle:
              Type.display.copyWith(fontSize: 20, color: palette.print),
          contentTextStyle: Type.body.copyWith(color: palette.print),
          title: const Text('Delete this expense?'),
          content: Text(
            hasReceipt
                ? 'The amount and the receipt photo are deleted for good.'
                : 'It is deleted for good. The account keeps a line showing '
                    'the money coming back.',
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
      ) ??
      false;
}

/// One expense, laid out as the slip it is.
class ExpenseDetailScreen extends ConsumerWidget {
  const ExpenseDetailScreen({super.key, required this.expenseId});

  final int expenseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.thermal;
    final detail = ref.watch(expenseDetailProvider(expenseId));

    return Scaffold(
      backgroundColor: palette.paper,
      appBar: AppBar(
        title: const Text('Expense'),
        actions: [
          detail.maybeWhen(
            data: (expense) => expense == null
                ? const SizedBox.shrink()
                : TextButton(
                    onPressed: () =>
                        ExpenseSheet.open(context, existing: expense),
                    child: const Text('Edit'),
                  ),
            orElse: () => const SizedBox.shrink(),
          ),
          const SizedBox(width: Space.sm),
        ],
      ),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('$e', style: Type.caption.copyWith(color: palette.faded)),
        ),
        data: (expense) {
          if (expense == null) {
            return Center(
              child: Text(
                'This expense is no longer here.',
                style: Type.body.copyWith(color: palette.faded),
              ),
            );
          }
          return _Detail(expense: expense);
        },
      ),
    );
  }
}

class _Detail extends ConsumerWidget {
  const _Detail({required this.expense});

  final Expense expense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.thermal;

    return ListView(
      padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.xxl),
      children: [
        Text(
          expense.title,
          style: Type.display.copyWith(color: palette.print, fontSize: 28),
        ),
        const SizedBox(height: Space.sm),
        Text(
          DateFormat('EEEE d MMMM yyyy · HH:mm').format(expense.occurredAt),
          style: Type.eyebrow.copyWith(color: palette.faded),
        ),
        const SizedBox(height: Space.lg),
        const PerforatedRule(),
        const SizedBox(height: Space.lg),
        _Field(
            label: 'AMOUNT',
            value: Money.format(expense.amountMinor),
            mono: true),
        _Field(
          label: 'FOR',
          value: expense.isBusiness ? 'Business' : 'Personal',
        ),
        _CategoryField(categoryId: expense.categoryId),
        _PaidWithField(expense: expense),
        if (expense.isSplit)
          _Field(
            label: 'SPLIT',
            value: InstallmentPlan.split(
              principalMinor: expense.amountMinor,
              count: expense.installments,
              interestBp: expense.interestBp,
            ).caption,
          ),
        if (expense.isAutoCreated)
          const _Field(label: 'SOURCE', value: 'Written by a standing order'),
        if ((expense.description ?? '').isNotEmpty)
          _Field(label: 'NOTE', value: expense.description!),
        if (expense.source == ExpenseSource.scanned)
          const _Field(label: 'SOURCE', value: 'Read from the receipt'),
        if (expense.latitude != null && expense.longitude != null) ...[
          const SizedBox(height: Space.lg),
          const PerforatedRule(),
          const SizedBox(height: Space.lg),
          PlaceMap(
            latitude: expense.latitude!,
            longitude: expense.longitude!,
            label: expense.locationLabel,
          ),
        ] else if ((expense.locationLabel ?? '').isNotEmpty) ...[
          const SizedBox(height: Space.lg),
          const PerforatedRule(),
          const SizedBox(height: Space.lg),
          _Field(label: 'PLACE', value: expense.locationLabel!),
        ],
        const SizedBox(height: Space.lg),
        const TearEdge(),
        const SizedBox(height: Space.lg),
        if (expense.hasReceipt)
          _ReceiptImage(relativePath: expense.receiptPath)
        else
          NoReceipt(expense: expense),
        const SizedBox(height: Space.xl),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () async {
              final confirmed = await confirmDeleteExpense(
                context,
                hasReceipt: expense.hasReceipt,
              );
              if (!confirmed) return;
              if (!context.mounted) return;
              await ref.read(expensesProvider.notifier).remove(expense.id!);
              if (!context.mounted) return;
              Navigator.of(context).pop();
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete this slip'),
          ),
        ),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.value,
    this.mono = false,
    this.stamp,
  });

  final String label;
  final String value;
  final bool mono;
  final CategoryInk? stamp;

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;

    return Padding(
      padding: const EdgeInsets.only(bottom: Space.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: Type.eyebrow.copyWith(color: palette.faded),
            ),
          ),
          const SizedBox(width: Space.md),
          if (stamp != null) ...[
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: CategoryStamp(ink: stamp!, size: 10),
            ),
            const SizedBox(width: Space.sm),
          ],
          Expanded(
            child: Text(
              value,
              style: mono
                  ? Type.monoBold.copyWith(color: palette.print, fontSize: 17)
                  : Type.item.copyWith(color: palette.print),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryField extends ConsumerWidget {
  const _CategoryField({required this.categoryId});

  final int? categoryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (categoryId == null) return const SizedBox.shrink();
    final categories = ref.watch(categoriesProvider);

    return categories.maybeWhen(
      data: (items) {
        for (final c in items) {
          if (c.id == categoryId) {
            return _Field(
              label: 'WHAT KIND',
              value: c.name,
              stamp: c.stamp,
            );
          }
        }
        return const SizedBox.shrink();
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

/// The payment method, falling back to the account for slips recorded before
/// methods existed.
class _PaidWithField extends ConsumerWidget {
  const _PaidWithField({required this.expense});

  final Expense expense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final methodId = expense.paymentMethodId;
    if (methodId != null) {
      final methods = ref.watch(paymentMethodsProvider).valueOrNull;
      final method = methods?.where((m) => m.id == methodId).firstOrNull;
      if (method != null) {
        return _Field(label: 'PAID WITH', value: method.label);
      }
    }

    final accountId = expense.accountId;
    if (accountId == null) return const SizedBox.shrink();
    final accounts = ref.watch(accountsProvider).valueOrNull;
    final account = accounts?.where((a) => a.id == accountId).firstOrNull;
    if (account == null) return const SizedBox.shrink();
    return _Field(label: 'PAID WITH', value: account.label);
  }
}

/// What sits where the photo would be on a slip nobody photographed.
///
/// A grey box or a broken image icon would read as a failure. This says what
/// actually happened and offers the one thing you might want — because the
/// paper bill for a standing order does sometimes turn up later.
class NoReceipt extends ConsumerStatefulWidget {
  const NoReceipt({super.key, required this.expense});

  final Expense expense;

  @override
  ConsumerState<NoReceipt> createState() => _NoReceiptState();
}

class _NoReceiptState extends ConsumerState<NoReceipt> {
  bool _busy = false;

  Future<void> _attach(ImageSource source) async {
    setState(() => _busy = true);
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 2000,
        imageQuality: 85,
      );
      if (picked == null) return;
      await ref.read(expensesProvider.notifier).edit(
            widget.expense,
            receiptSourcePath: picked.path,
          );
    } on Exception catch (e) {
      if (!mounted) return;
      showPaperSnack(context, message: "Couldn't attach that photo. ($e)");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;
    final expense = widget.expense;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          expense.isAutoCreated
              ? 'No receipt. A standing order wrote this one on the '
                  '${_ordinal(expense.occurredAt.day)}.'
              : 'No receipt on this one.',
          style: Type.body.copyWith(color: palette.faded),
        ),
        const SizedBox(height: Space.md),
        OutlinedButton.icon(
          onPressed: _busy ? null : () => _attach(ImageSource.camera),
          icon: const AppIcon(SolarIcons.CameraMinimalistic, size: 18),
          label: const Text('Photograph it'),
        ),
      ],
    );
  }

  static String _ordinal(int day) {
    if (day >= 11 && day <= 13) return '${day}th';
    return switch (day % 10) {
      1 => '${day}st',
      2 => '${day}nd',
      3 => '${day}rd',
      _ => '${day}th',
    };
  }
}

class _ReceiptImage extends ConsumerWidget {
  const _ReceiptImage({required this.relativePath});

  final String relativePath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.thermal;

    return FutureBuilder<File>(
      future: ref.read(expenseRepositoryProvider).images.resolve(relativePath),
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

/// Full-screen and zoomable — receipts print small and faintly, and being able
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
