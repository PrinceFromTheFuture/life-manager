import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/product.dart';
import '../../design/theme.dart';
import '../../design/tokens.dart';
import '../../state/providers.dart';

/// The add field, pinned above the keyboard, with its suggestion strip.
///
/// The strip sits directly on top of the field rather than in a dropdown
/// overlay: with the keyboard up, that band is the only part of the screen a
/// thumb reaches comfortably, and a dropdown would put the suggestions at the
/// far end of the phone from the hand that has to tap them.
class AddItemBar extends ConsumerStatefulWidget {
  const AddItemBar({super.key});

  @override
  ConsumerState<AddItemBar> createState() => _AddItemBarState();
}

class _AddItemBarState extends ConsumerState<AddItemBar> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// Debounced so a fast typist doesn't queue a query per keystroke. Short
  /// enough that the strip still feels like it's keeping up.
  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 120), () {
      if (mounted) ref.read(addQueryProvider.notifier).state = value;
    });
  }

  Future<void> _submit(String rawName) async {
    final name = rawName.trim();
    if (name.isEmpty) return;

    _controller.clear();
    ref.read(addQueryProvider.notifier).state = '';
    await ref.read(activeListProvider.notifier).addItem(name);

    // Keep the keyboard up. Lists get built in bursts, and dismissing it after
    // every item would mean reopening it for the next one.
    if (mounted) _focus.requestFocus();
    unawaited(HapticFeedback.selectionClick());
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;
    final showSuggestions = _focus.hasFocus;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showSuggestions) const _SuggestionStrip(),
        Container(
          color: palette.paper,
          padding: EdgeInsets.only(
            left: Space.lg,
            right: Space.lg,
            top: Space.md,
            bottom: Space.md + MediaQuery.paddingOf(context).bottom,
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focus,
                  onChanged: _onChanged,
                  onSubmitted: _submit,
                  textInputAction: TextInputAction.done,
                  textCapitalization: TextCapitalization.sentences,
                  style: Type.item.copyWith(color: palette.print),
                  cursorColor: palette.carbon,
                  decoration: const InputDecoration(hintText: 'Add an item'),
                ),
              ),
              const SizedBox(width: Space.sm),
              _AddButton(onPressed: () => _submit(_controller.text)),
            ],
          ),
        ),
      ],
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;
    return Semantics(
      button: true,
      label: 'Add item',
      child: Material(
        color: palette.carbon,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 52,
            height: 52,
            child: Icon(
              Icons.add,
              color: Theme.of(context).brightness == Brightness.light
                  ? palette.paper
                  : palette.print,
            ),
          ),
        ),
      ),
    );
  }
}

/// Past products, ranked by how often they're bought. Tapping one adds it
/// outright — for a weekly shop the fastest path is usually not typing at all.
class _SuggestionStrip extends ConsumerWidget {
  const _SuggestionStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.thermal;
    final suggestions = ref.watch(suggestionsProvider);

    return suggestions.maybeWhen(
      data: (products) {
        if (products.isEmpty) return const SizedBox.shrink();
        return Container(
          height: 52,
          width: double.infinity,
          color: palette.paper,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: Space.lg),
            itemCount: products.length,
            separatorBuilder: (_, __) => const SizedBox(width: Space.sm),
            itemBuilder: (context, i) => _SuggestionChip(product: products[i]),
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _SuggestionChip extends ConsumerWidget {
  const _SuggestionChip({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.thermal;

    return Center(
      child: Material(
        color: palette.paperShade,
        borderRadius: Radii.control,
        child: InkWell(
          borderRadius: Radii.control,
          onTap: () async {
            await ref
                .read(activeListProvider.notifier)
                .addItem(product.name);
            unawaited(HapticFeedback.selectionClick());
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Space.md + 2,
              vertical: Space.sm,
            ),
            child: Text(
              product.name,
              style: Type.body.copyWith(color: palette.print),
            ),
          ),
        ),
      ),
    );
  }
}
