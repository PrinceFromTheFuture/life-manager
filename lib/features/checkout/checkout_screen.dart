import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/shopping_repository.dart';
import '../../design/theme.dart';
import '../../design/tokens.dart';
import '../../design/widgets/perforation.dart';
import '../../state/providers.dart';
import '../../util/money.dart';
import 'receipt_capture.dart';

/// Closing out the trip: what it cost, and proof of what it cost.
class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final _totalController = TextEditingController();
  final _noteController = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _totalController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  int? get _parsedTotal => Money.tryParse(_totalController.text);

  Future<void> _complete() async {
    final total = _parsedTotal;
    if (total == null) {
      setState(() => _error = 'Enter the total as it appears on the receipt.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      await ref
          .read(activeListProvider.notifier)
          .completeTrip(totalMinor: total, note: _noteController.text.trim());

      // Back to the list, which is now empty and ready for the next trip.
      navigator.popUntil((route) => route.isFirst);
      messenger.showSnackBar(
        SnackBar(content: Text('Trip saved · ${Money.format(total)}')),
      );
    } on Exception catch (e) {
      // Leave the screen up with everything still filled in — the total and
      // the receipt are not worth making someone enter twice.
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = "The trip didn't save. Try again. ($e)";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;
    final listAsync = ref.watch(activeListProvider);

    return Scaffold(
      backgroundColor: palette.paper,
      appBar: AppBar(title: const Text('Check out')),
      body: listAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('$e', style: Type.caption.copyWith(color: palette.faded)),
        ),
        data: (list) => _CheckoutForm(
          list: list,
          totalController: _totalController,
          noteController: _noteController,
          error: _error,
          onTotalChanged: () => setState(() => _error = null),
        ),
      ),
      bottomNavigationBar: Container(
        color: palette.paper,
        padding: EdgeInsets.fromLTRB(
          Space.lg,
          Space.md,
          Space.lg,
          Space.md + MediaQuery.paddingOf(context).bottom,
        ),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _saving ? null : _complete,
            child: Text(_saving ? 'Saving…' : 'Complete trip'),
          ),
        ),
      ),
    );
  }
}

class _CheckoutForm extends StatelessWidget {
  const _CheckoutForm({
    required this.list,
    required this.totalController,
    required this.noteController,
    required this.error,
    required this.onTotalChanged,
  });

  final ActiveList list;
  final TextEditingController totalController;
  final TextEditingController noteController;
  final String? error;
  final VoidCallback onTotalChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;

    return ListView(
      padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.xl),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${list.total} ITEMS',
              style: Type.eyebrow.copyWith(color: palette.faded),
            ),
            if (!list.allPicked)
              Text(
                '${list.total - list.pickedCount} NOT FOUND',
                style: Type.eyebrow.copyWith(color: palette.faded),
              ),
          ],
        ),
        const SizedBox(height: Space.md),
        const PerforatedRule(),
        const SizedBox(height: Space.xl),

        Text('TOTAL PAID', style: Type.eyebrow.copyWith(color: palette.faded)),
        const SizedBox(height: Space.sm),

        // The total gets the largest type in the app. It is the one number the
        // whole trip resolves to, and it earns that weight through scale rather
        // than through a colour used nowhere else.
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              Money.symbol,
              style: Type.totalDisplay.copyWith(color: palette.faded),
            ),
            const SizedBox(width: Space.sm),
            Expanded(
              child: TextField(
                controller: totalController,
                onChanged: (_) => onTotalChanged(),
                autofocus: true,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  // Digits and at most one decimal point. Everything else is
                  // stripped as it's typed, so the field can never hold
                  // something the parser will reject.
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  TextInputFormatter.withFunction((old, incoming) {
                    if ('.'.allMatches(incoming.text).length > 1) return old;
                    final parts = incoming.text.split('.');
                    if (parts.length == 2 && parts[1].length > 2) return old;
                    return incoming;
                  }),
                ],
                style: Type.totalDisplay.copyWith(color: palette.print),
                cursorColor: palette.carbon,
                decoration: InputDecoration(
                  filled: false,
                  hintText: '0.00',
                  hintStyle: Type.totalDisplay.copyWith(color: palette.faded),
                  contentPadding: EdgeInsets.zero,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: Space.sm),
        const PerforatedRule(),

        if (error != null) ...[
          const SizedBox(height: Space.sm),
          Text(
            error!,
            style: Type.caption.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ],

        const SizedBox(height: Space.xl),
        Text('RECEIPT', style: Type.eyebrow.copyWith(color: palette.faded)),
        const SizedBox(height: Space.md),
        ReceiptCapture(receiptPath: list.trip?.receiptPath),

        const SizedBox(height: Space.xl),
        Text('NOTE', style: Type.eyebrow.copyWith(color: palette.faded)),
        const SizedBox(height: Space.md),
        TextField(
          controller: noteController,
          maxLines: 2,
          textCapitalization: TextCapitalization.sentences,
          style: Type.body.copyWith(color: palette.print),
          cursorColor: palette.carbon,
          decoration: const InputDecoration(
            hintText: 'Which shop? Anything worth remembering?',
          ),
        ),
      ],
    );
  }
}
