import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shopping_list/apps/groceries/data/models/product.dart';
import 'package:shopping_list/apps/groceries/state/providers.dart';
import 'package:shopping_list/core/design/theme.dart';
import 'package:shopping_list/core/design/tokens.dart';
import 'package:shopping_list/core/design/widgets/ink_plate.dart';

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
    // Keep the usual-basket query warm so opening the field does not start
    // from a loading blank — that was a pop of its own.
    ref.watch(suggestionsProvider);

    final reduce = MediaQuery.disableAnimationsOf(context);
    final motion = reduce ? Duration.zero : Motion.settle;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRect(
          child: AnimatedSize(
            duration: motion,
            curve: Motion.heat,
            alignment: Alignment.bottomCenter,
            child: _focus.hasFocus
                ? _SuggestionStrip(onPicked: _submit)
                : const SizedBox(width: double.infinity),
          ),
        ),
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
    final onInk = Theme.of(context).brightness == Brightness.light
        ? palette.paper
        : palette.print;

    return InkPlate(
      onPressed: onPressed,
      size: const Size(Plate.height, Plate.height),
      semanticLabel: 'Add item',
      child: Icon(Icons.add, color: onInk),
    );
  }
}

/// Past products, ranked by how often they're bought. Tapping one adds it
/// outright — for a weekly shop the fastest path is usually not typing at all.
///
/// Height is fixed. Collapsing to nothing while a query reloads is what made
/// the list jump on every keystroke.
class _SuggestionStrip extends ConsumerWidget {
  const _SuggestionStrip({required this.onPicked});

  final ValueChanged<String> onPicked;

  static const double _height = 52;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.thermal;
    final suggestions = ref.watch(suggestionsProvider);
    final query = ref.watch(addQueryProvider);
    final reduce = MediaQuery.disableAnimationsOf(context);
    final motion = reduce ? Duration.zero : Motion.settle;

    final products = suggestions.when(
      skipLoadingOnReload: true,
      data: (list) => list,
      loading: () => const <Product>[],
      error: (_, __) => const <Product>[],
    );

    final content = products.isEmpty
        ? _EmptyMatches(query: query)
        : ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: Space.lg),
            itemCount: products.length,
            separatorBuilder: (_, __) => const SizedBox(width: Space.sm),
            itemBuilder: (context, i) => _SuggestionChip(
              product: products[i],
              onPicked: onPicked,
            ),
          );

    return ColoredBox(
      color: palette.paper,
      child: SizedBox(
        height: _height,
        width: double.infinity,
        child: AnimatedSwitcher(
          duration: motion,
          switchInCurve: Motion.heat,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.12),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            );
          },
          child: KeyedSubtree(
            key: ValueKey(
              products.isEmpty
                  ? 'empty'
                  : products.map((p) => p.id).join(','),
            ),
            child: content,
          ),
        ),
      ),
    );
  }
}

class _EmptyMatches extends StatelessWidget {
  const _EmptyMatches({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.lg),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          query.trim().isEmpty
              ? 'Add something and it will be remembered here.'
              : 'No matches.',
          style: Type.caption.copyWith(color: palette.faded),
        ),
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({required this.product, required this.onPicked});

  final Product product;
  final ValueChanged<String> onPicked;

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;

    return Center(
      child: Material(
        color: palette.paperShade,
        borderRadius: Radii.control,
        child: InkWell(
          // Must not steal focus from the add field — otherwise the strip
          // collapses before the tap is counted, and the keyboard bounces.
          canRequestFocus: false,
          borderRadius: Radii.control,
          onTap: () => onPicked(product.name),
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
