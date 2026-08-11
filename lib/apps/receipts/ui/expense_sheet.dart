import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import 'package:shopping_list/apps/receipts/data/models/account.dart';
import 'package:shopping_list/apps/receipts/data/models/expense.dart';
import 'package:shopping_list/apps/receipts/data/models/expense_category.dart';
import 'package:shopping_list/apps/receipts/state/providers.dart';
import 'package:shopping_list/apps/receipts/ui/print_slip.dart';
import 'package:shopping_list/apps/receipts/ui/register_keypad.dart';
import 'package:shopping_list/core/design/theme.dart';
import 'package:shopping_list/core/design/tokens.dart';
import 'package:shopping_list/core/design/widgets/perforation.dart';
import 'package:shopping_list/core/util/money.dart';

/// Recording an expense.
///
/// Designed for one situation above all others: you have just paid, you are
/// outside the shop, and you are holding a paper receipt. Everything here
/// serves getting that into the app in seconds.
///
/// Because a receipt is mandatory, the camera **opens immediately** rather than
/// sitting behind a photo field halfway down a form. Cancelling the camera
/// lands on the capture screen with both options still offered, so nothing is
/// lost by not wanting the camera — but the common path is: open, snap, confirm
/// the amount, save.
class ExpenseSheet extends ConsumerStatefulWidget {
  const ExpenseSheet({super.key, this.existing});

  /// When set, the sheet edits rather than creates. Same layout, same words —
  /// correcting an expense should not feel like a different feature.
  final Expense? existing;

  static Future<void> open(BuildContext context, {Expense? existing}) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => ExpenseSheet(existing: existing),
      ),
    );
  }

  @override
  ConsumerState<ExpenseSheet> createState() => _ExpenseSheetState();
}

class _ExpenseSheetState extends ConsumerState<ExpenseSheet> {
  final _merchantController = TextEditingController();
  final _noteController = TextEditingController();
  final _locationController = TextEditingController();
  final _merchantFocus = FocusNode();

  AmountEntry _amount = AmountEntry();
  String? _receiptSourcePath;
  int? _categoryId;
  int? _accountId;
  DateTime _occurredAt = DateTime.now();
  double? _latitude;
  double? _longitude;

  bool _keypadOpen = false;
  bool _showNote = false;
  bool _busy = false;
  bool _saving = false;
  bool _categoryChosenByHand = false;
  Timer? _predictDebounce;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();

    final existing = widget.existing;
    if (existing != null) {
      _amount = AmountEntry.fromAgorot(existing.amountMinor);
      _merchantController.text = existing.merchant ?? '';
      _noteController.text = existing.description ?? '';
      _locationController.text = existing.locationLabel ?? '';
      _categoryId = existing.categoryId;
      _accountId = existing.accountId;
      _occurredAt = existing.occurredAt;
      _latitude = existing.latitude;
      _longitude = existing.longitude;
      _showNote = (existing.description ?? '').isNotEmpty;
      _categoryChosenByHand = true;
    } else {
      // Straight to the camera. The receipt is required, so there is nothing
      // useful to do on this screen until one exists.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _capture(ImageSource.camera);
        _fillLocation();
      });
    }

    _merchantController.addListener(_onMerchantChanged);
  }

  @override
  void dispose() {
    _predictDebounce?.cancel();
    _merchantController.dispose();
    _noteController.dispose();
    _locationController.dispose();
    _merchantFocus.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------------ input

  Future<void> _capture(ImageSource source) async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 2000,
        imageQuality: 85,
      );
      if (picked != null) {
        setState(() => _receiptSourcePath = picked.path);
      }
    } on Exception catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            source == ImageSource.camera
                ? "Couldn't open the camera. Check camera access in Settings, "
                    'or choose a photo instead.'
                : "Couldn't load that photo. Try another one. ($e)",
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Fills the location in the background. Never blocks anything.
  Future<void> _fillLocation() async {
    final guess = await ref.read(locationServiceProvider).currentPlace();
    if (!mounted || !guess.hasAny) return;
    // Don't stomp on something already typed.
    if (_locationController.text.isNotEmpty) return;
    setState(() {
      _locationController.text = guess.label ?? '';
      _latitude = guess.latitude;
      _longitude = guess.longitude;
    });
  }

  void _onMerchantChanged() {
    if (_categoryChosenByHand) return;
    _predictDebounce?.cancel();
    _predictDebounce = Timer(const Duration(milliseconds: 300), () async {
      final merchant = _merchantController.text.trim();
      if (merchant.isEmpty || !mounted) return;
      final predicted =
          await ref.read(expenseRepositoryProvider).predictCategory(merchant);
      if (!mounted || predicted == null || _categoryChosenByHand) return;
      setState(() => _categoryId = predicted);
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _occurredAt,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) {
      setState(() {
        _occurredAt = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _occurredAt.hour,
          _occurredAt.minute,
        );
      });
    }
  }

  // ------------------------------------------------------------------- save

  bool get _canSave =>
      _amount.agorot != null &&
      (_receiptSourcePath != null || _isEditing) &&
      !_saving;

  Future<void> _save() async {
    final amount = _amount.agorot;
    if (amount == null) return;

    setState(() => _saving = true);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final controller = ref.read(expensesProvider.notifier);

    final merchant = _merchantController.text.trim();
    final location = _locationController.text.trim();
    final note = _noteController.text.trim();

    try {
      if (_isEditing) {
        await controller.edit(
          widget.existing!.copyWith(
            amountMinor: amount,
            merchant: merchant.isEmpty ? null : merchant,
            description: note.isEmpty ? null : note,
            categoryId: _categoryId,
            accountId: _accountId,
            locationLabel: location.isEmpty ? null : location,
            latitude: _latitude,
            longitude: _longitude,
            occurredAt: _occurredAt,
          ),
          receiptSourcePath: _receiptSourcePath,
        );
      } else {
        final now = DateTime.now();
        await controller.add(
          receiptSourcePath: _receiptSourcePath!,
          draft: Expense(
            occurredAt: _occurredAt,
            amountMinor: amount,
            merchant: merchant.isEmpty ? null : merchant,
            description: note.isEmpty ? null : note,
            categoryId: _categoryId,
            accountId: _accountId,
            locationLabel: location.isEmpty ? null : location,
            latitude: _latitude,
            longitude: _longitude,
            receiptPath: '', // set by the repository once the file is stored
            createdAt: now,
            updatedAt: now,
          ),
        );
      }

      // Resolved before touching the context again, so there is no await
      // between the mounted check and using it.
      final categoryName = _isEditing ? null : await _categoryName();
      if (!mounted) return;

      // The register prints it. Skipped when editing — a correction isn't a
      // transaction, and replaying the ceremony every time you fix a typo
      // would wear thin fast.
      if (!_isEditing) {
        await showPrintSlip(
          context,
          merchant: merchant.isEmpty ? 'Expense' : merchant,
          amountMinor: amount,
          categoryName: categoryName,
          occurredAt: _occurredAt,
        );
      }

      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            _isEditing
                ? 'Expense updated'
                : 'Saved · ${Money.format(amount)}',
          ),
        ),
      );
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(
        SnackBar(content: Text("That didn't save. Try again. ($e)")),
      );
    }
  }

  Future<String?> _categoryName() async {
    if (_categoryId == null) return null;
    final categories = await ref.read(categoriesProvider.future);
    for (final c in categories) {
      if (c.id == _categoryId) return c.name;
    }
    return null;
  }

  // ------------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;
    final hasReceipt = _receiptSourcePath != null || _isEditing;

    return Scaffold(
      backgroundColor: palette.paper,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Discard',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(_isEditing ? 'Edit expense' : 'New expense'),
      ),
      body: hasReceipt ? _buildForm() : _CaptureStage(
        busy: _busy,
        onCamera: () => _capture(ImageSource.camera),
        onGallery: () => _capture(ImageSource.gallery),
      ),
    );
  }

  Widget _buildForm() {
    final palette = context.thermal;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.lg),
            children: [
              _AmountRow(
                entry: _amount,
                active: _keypadOpen,
                onTap: () => setState(() => _keypadOpen = true),
              ),
              const PerforatedRule(),
              const SizedBox(height: Space.lg),

              _Block(
                label: 'WHERE',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _merchantController,
                      focusNode: _merchantFocus,
                      textCapitalization: TextCapitalization.words,
                      style: Type.item.copyWith(color: palette.print),
                      cursorColor: palette.carbon,
                      decoration: const InputDecoration(
                        hintText: 'Which shop?',
                        filled: false,
                        contentPadding: EdgeInsets.zero,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                      ),
                      onTap: () => setState(() => _keypadOpen = false),
                    ),
                    Row(
                      children: [
                        Icon(Icons.place_outlined,
                            size: 15, color: palette.faded),
                        const SizedBox(width: Space.xs),
                        Expanded(
                          child: TextField(
                            controller: _locationController,
                            style:
                                Type.caption.copyWith(color: palette.faded),
                            cursorColor: palette.carbon,
                            decoration: InputDecoration(
                              hintText: 'Finding you…',
                              hintStyle:
                                  Type.caption.copyWith(color: palette.faded),
                              filled: false,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                            ),
                            onTap: () => setState(() => _keypadOpen = false),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              _Block(
                label: 'WHAT KIND',
                child: _CategoryChips(
                  selected: _categoryId,
                  onSelected: (id) => setState(() {
                    _categoryId = id;
                    _categoryChosenByHand = true;
                    _keypadOpen = false;
                  }),
                ),
              ),

              _Block(
                label: 'PAID WITH',
                child: _AccountChips(
                  selected: _accountId,
                  onSelected: (id) => setState(() {
                    _accountId = id;
                    _keypadOpen = false;
                  }),
                ),
              ),

              _Block(
                label: 'WHEN',
                child: InkWell(
                  onTap: _pickDate,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: Space.xs),
                    child: Text(
                      _friendlyDate(_occurredAt),
                      style: Type.mono.copyWith(
                        color: palette.print,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ),

              if (_showNote)
                _Block(
                  label: 'NOTE',
                  child: TextField(
                    controller: _noteController,
                    maxLines: 2,
                    textCapitalization: TextCapitalization.sentences,
                    style: Type.body.copyWith(color: palette.print),
                    cursorColor: palette.carbon,
                    decoration: const InputDecoration(
                      hintText: 'Anything worth remembering?',
                      filled: false,
                      contentPadding: EdgeInsets.zero,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                    onTap: () => setState(() => _keypadOpen = false),
                  ),
                )
              else
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => setState(() {
                      _showNote = true;
                      _keypadOpen = false;
                    }),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add a note'),
                  ),
                ),

              const SizedBox(height: Space.lg),
              _ReceiptStrip(
                sourcePath: _receiptSourcePath,
                existing: widget.existing,
                onRetake: () => _capture(ImageSource.camera),
              ),
            ],
          ),
        ),

        if (_keypadOpen)
          RegisterKeypad(
            entry: _amount,
            onChanged: (next) => setState(() => _amount = next),
            onDone: () => setState(() => _keypadOpen = false),
          )
        else
          _SaveBar(
            enabled: _canSave,
            saving: _saving,
            editing: _isEditing,
            hint: _amount.agorot == null ? 'Enter what you paid' : null,
            onSave: _save,
          ),
      ],
    );
  }

  static String _friendlyDate(DateTime when) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(when.year, when.month, when.day);
    final time = DateFormat('HH:mm').format(when);

    if (that == today) return 'Today · $time';
    if (that == today.subtract(const Duration(days: 1))) {
      return 'Yesterday · $time';
    }
    return DateFormat('d MMM yyyy · HH:mm').format(when);
  }
}

// ------------------------------------------------------------------- pieces

/// Shown only when the camera was cancelled or never opened.
class _CaptureStage extends StatelessWidget {
  const _CaptureStage({
    required this.busy,
    required this.onCamera,
    required this.onGallery,
  });

  final bool busy;
  final VoidCallback onCamera;
  final VoidCallback onGallery;

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;

    return Padding(
      padding: const EdgeInsets.all(Space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PerforatedRule(),
          const SizedBox(height: Space.lg),
          Text(
            'Every expense keeps its receipt.',
            style: Type.display.copyWith(color: palette.print, fontSize: 26),
          ),
          const SizedBox(height: Space.md),
          Text(
            'Photograph it now and the rest takes seconds.',
            style: Type.body.copyWith(color: palette.faded),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: busy ? null : onCamera,
              icon: const Icon(Icons.photo_camera_outlined, size: 20),
              label: const Text('Photograph the receipt'),
            ),
          ),
          const SizedBox(height: Space.md),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: busy ? null : onGallery,
              child: const Text('Choose a photo'),
            ),
          ),
        ],
      ),
    );
  }
}

class _AmountRow extends StatelessWidget {
  const _AmountRow({
    required this.entry,
    required this.active,
    required this.onTap,
  });

  final AmountEntry entry;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              Money.symbol,
              style: Type.totalDisplay.copyWith(color: palette.faded),
            ),
            const SizedBox(width: Space.sm),
            Text(
              entry.display,
              style: Type.totalDisplay.copyWith(
                color: entry.isEmpty ? palette.faded : palette.print,
              ),
            ),
            const Spacer(),
            // A quiet marker that this is editable, and which state it's in.
            Icon(
              active ? Icons.keyboard_hide_outlined : Icons.dialpad,
              size: 20,
              color: active ? palette.carbon : palette.faded,
            ),
          ],
        ),
      ),
    );
  }
}

class _Block extends StatelessWidget {
  const _Block({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Type.eyebrow.copyWith(color: palette.faded)),
        const SizedBox(height: Space.sm),
        child,
        const SizedBox(height: Space.md),
        const PerforatedRule(),
        const SizedBox(height: Space.lg),
      ],
    );
  }
}

class _CategoryChips extends ConsumerWidget {
  const _CategoryChips({required this.selected, required this.onSelected});

  final int? selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider);

    return categories.maybeWhen(
      data: (items) => Wrap(
        spacing: Space.sm,
        runSpacing: Space.sm,
        children: [
          for (final ExpenseCategory c in items)
            _Chip(
              label: c.name,
              selected: c.id == selected,
              onTap: () => onSelected(c.id!),
            ),
        ],
      ),
      orElse: () => const SizedBox(height: 40),
    );
  }
}

class _AccountChips extends ConsumerWidget {
  const _AccountChips({required this.selected, required this.onSelected});

  final int? selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(accountsProvider);

    return accounts.maybeWhen(
      data: (items) => Wrap(
        spacing: Space.sm,
        runSpacing: Space.sm,
        children: [
          for (final Account a in items)
            _Chip(
              label: a.label,
              selected: a.id == selected,
              onTap: () => onSelected(a.id!),
            ),
        ],
      ),
      orElse: () => const SizedBox(height: 40),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;
    final light = Theme.of(context).brightness == Brightness.light;

    return Material(
      color: selected ? palette.carbon : palette.paperShade,
      borderRadius: Radii.control,
      child: InkWell(
        borderRadius: Radii.control,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Space.md + 2,
            vertical: Space.sm + 2,
          ),
          child: Text(
            label,
            style: Type.body.copyWith(
              color: selected
                  ? (light ? palette.paper : palette.print)
                  : palette.print,
            ),
          ),
        ),
      ),
    );
  }
}

class _ReceiptStrip extends ConsumerWidget {
  const _ReceiptStrip({
    required this.sourcePath,
    required this.existing,
    required this.onRetake,
  });

  final String? sourcePath;
  final Expense? existing;
  final VoidCallback onRetake;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.thermal;

    Widget image;
    if (sourcePath != null) {
      image = Image.file(File(sourcePath!), height: 120, fit: BoxFit.cover);
    } else if (existing != null) {
      image = FutureBuilder<File>(
        future: ref
            .read(expenseRepositoryProvider)
            .images
            .resolve(existing!.receiptPath),
        builder: (context, snapshot) {
          final file = snapshot.data;
          if (file == null) {
            return Container(height: 120, color: palette.paperShade);
          }
          return Image.file(
            file,
            height: 120,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                Container(height: 120, color: palette.paperShade),
          );
        },
      );
    } else {
      return const SizedBox.shrink();
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: Radii.media,
          child: SizedBox(width: 90, height: 120, child: image),
        ),
        const SizedBox(width: Space.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'RECEIPT',
                style: Type.eyebrow.copyWith(color: palette.faded),
              ),
              const SizedBox(height: Space.xs),
              TextButton(onPressed: onRetake, child: const Text('Retake')),
            ],
          ),
        ),
      ],
    );
  }
}

class _SaveBar extends StatelessWidget {
  const _SaveBar({
    required this.enabled,
    required this.saving,
    required this.editing,
    required this.hint,
    required this.onSave,
  });

  final bool enabled;
  final bool saving;
  final bool editing;
  final String? hint;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;

    return Container(
      color: palette.paper,
      padding: EdgeInsets.fromLTRB(
        Space.lg,
        Space.md,
        Space.lg,
        Space.md + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Says why it's disabled instead of leaving you to guess.
          if (hint != null) ...[
            Text(hint!, style: Type.caption.copyWith(color: palette.faded)),
            const SizedBox(height: Space.sm),
          ],
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: enabled ? onSave : null,
              child: Text(
                saving
                    ? 'Saving…'
                    : editing
                        ? 'Save changes'
                        : 'Save expense',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
