import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import 'package:shopping_list/apps/receipts/data/finance/installment_plan.dart';
import 'package:shopping_list/apps/receipts/data/models/category_ink.dart';
import 'package:shopping_list/apps/receipts/data/models/expense.dart';
import 'package:shopping_list/apps/receipts/data/models/expense_category.dart';
import 'package:shopping_list/apps/receipts/data/models/recurring_rule.dart';
import 'package:shopping_list/apps/receipts/data/ocr/receipt_scanner.dart';
import 'package:shopping_list/apps/receipts/state/providers.dart';
import 'package:shopping_list/apps/receipts/ui/ledger_plate.dart';
import 'package:shopping_list/apps/receipts/ui/print_slip.dart';
import 'package:shopping_list/apps/receipts/ui/register_keypad.dart';
import 'package:shopping_list/apps/receipts/ui/widgets/category_stamp.dart';
import 'package:shopping_list/core/design/paper_snack.dart';
import 'package:shopping_list/core/design/theme.dart';
import 'package:shopping_list/core/design/tokens.dart';
import 'package:shopping_list/core/design/widgets/perforation.dart';
import 'package:shopping_list/core/settings/api_keys.dart';
import 'package:shopping_list/core/util/money.dart';
import 'package:shopping_list/core/design/widgets/app_icon.dart';

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
  const ExpenseSheet({super.key, this.existing, this.fromRule});

  /// When set, the sheet edits rather than creates. Same layout, same words —
  /// correcting an expense should not feel like a different feature.
  final Expense? existing;

  /// When set, a new slip starts from this recurring template: category,
  /// amount, paid-with, name. The date stays now.
  final RecurringRule? fromRule;

  static Future<void> open(
    BuildContext context, {
    Expense? existing,
    RecurringRule? fromRule,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => ExpenseSheet(existing: existing, fromRule: fromRule),
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
  int? _paymentMethodId;
  DateTime _occurredAt = DateTime.now();
  double? _latitude;
  double? _longitude;
  bool _isBusiness = false;

  /// Almost always 1. The interface below is built entirely around keeping it
  /// that way costing nothing.
  int _installments = 1;
  int _interestBp = 0;
  bool _installmentsOpen = false;
  bool _rateOpen = false;
  final _rateController = TextEditingController();

  bool _keypadOpen = false;
  bool _showNote = false;
  bool _busy = false;
  bool _saving = false;
  bool _categoryChosenByHand = false;
  bool _methodChosenByHand = false;
  Timer? _predictDebounce;

  ExpenseSource _source = ExpenseSource.manual;
  String? _ocrRaw;
  String? _ocrModel;
  bool _scanChoiceMade = false;
  bool _scanning = false;
  bool _locationSettled = false;
  bool _leaving = false;

  /// Calendar day the sheet opened, so picking a different day counts as
  /// entered data without treating "now" ticking as a change.
  late final DateTime _openedDay;

  bool get _isEditing => widget.existing != null;

  /// Anything that would be lost if this new expense is thrown away.
  ///
  /// Autofill does not count: last payment method and a guessed category are
  /// the app helping, not the person typing. A receipt photo does — that is
  /// the whole point of this screen.
  bool get _hasEnteredData {
    if (_receiptSourcePath != null) return true;
    if (!_amount.isEmpty) return true;
    if (_merchantController.text.trim().isNotEmpty) return true;
    if (_noteController.text.trim().isNotEmpty) return true;
    if (_locationController.text.trim().isNotEmpty) return true;
    if (_categoryChosenByHand) return true;
    if (_methodChosenByHand) return true;
    if (_installments != 1 || _interestBp != 0) return true;
    if (_isBusiness) return true;
    final day = DateTime(_occurredAt.year, _occurredAt.month, _occurredAt.day);
    if (day != _openedDay) return true;
    return false;
  }

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
      _paymentMethodId = existing.paymentMethodId;
      _methodChosenByHand = true;
      _installments = existing.installments;
      _interestBp = existing.interestBp;
      _installmentsOpen = existing.installments > 1;
      _rateOpen = existing.interestBp > 0;
      if (existing.interestBp > 0) {
        _rateController.text = (existing.interestBp / 100).toString();
      }
      _occurredAt = existing.occurredAt;
      _latitude = existing.latitude;
      _longitude = existing.longitude;
      _showNote = (existing.description ?? '').isNotEmpty;
      _categoryChosenByHand = true;
      _source = existing.source;
      _ocrRaw = existing.ocrRaw;
      _ocrModel = existing.ocrModel;
      _isBusiness = existing.isBusiness;
      _locationSettled = true;
    } else {
      final fromRule = widget.fromRule;
      if (fromRule != null) {
        _amount = AmountEntry.fromAgorot(fromRule.amountMinor);
        _merchantController.text = fromRule.name;
        _noteController.text = fromRule.note ?? '';
        _showNote = (fromRule.note ?? '').isNotEmpty;
        _categoryId = fromRule.categoryId;
        _paymentMethodId = fromRule.paymentMethodId;
        _isBusiness = fromRule.isBusiness;
        _categoryChosenByHand = fromRule.categoryId != null;
        _methodChosenByHand = fromRule.paymentMethodId != null;
      }
      // Straight to the camera. The receipt is required, so there is nothing
      // useful to do on this screen until one exists. Location waits until
      // after the picker closes — otherwise the two permission dialogs stack
      // and the first-run path looks broken.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _capture(ImageSource.camera);
      });
      unawaited(_preselectMethod());
    }

    _openedDay = DateTime(_occurredAt.year, _occurredAt.month, _occurredAt.day);
    _merchantController.addListener(_onMerchantChanged);
    if (existing == null) {
      _merchantController.addListener(_markDraft);
      _noteController.addListener(_markDraft);
      _locationController.addListener(_markDraft);
    }
  }

  void _markDraft() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _predictDebounce?.cancel();
    _merchantController.dispose();
    _noteController.dispose();
    _locationController.dispose();
    _rateController.dispose();
    _merchantFocus.dispose();
    super.dispose();
  }

  /// Answers "paid with" before it is asked.
  ///
  /// People pay for almost everything the same way, so the last method used is
  /// right nearly every time. In the common case this block now costs zero
  /// taps, which makes the whole sheet faster than it was before payment
  /// methods existed.
  Future<void> _preselectMethod() async {
    final lastUsed = await ref.read(lastUsedPaymentMethodProvider.future);
    if (!mounted || lastUsed == null || _methodChosenByHand) return;
    setState(() => _paymentMethodId = lastUsed);
  }

  // ------------------------------------------------------------------ input

  Future<void> _capture(ImageSource source) async {
    setState(() => _busy = true);

    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 2000,
        imageQuality: 85,
      );
      if (picked != null) {
        setState(() => _receiptSourcePath = picked.path);
        if (!_locationSettled) unawaited(_fillLocation());
      }
    } on Exception catch (e) {
      if (!mounted) return;
      showPaperSnack(
        context,
        message: source == ImageSource.camera
            ? "Couldn't open the camera. Check camera access in Settings, "
                'or choose a photo instead.'
            : "Couldn't load that photo. Try another one. ($e)",
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Fills the location in the background. Never blocks anything.
  Future<void> _fillLocation() async {
    final guess = await ref.read(locationServiceProvider).currentPlace();
    if (!mounted) return;
    setState(() {
      _locationSettled = true;
      // Don't stomp on something already typed.
      if (_locationController.text.isNotEmpty || !guess.hasAny) return;
      _locationController.text = guess.label ?? '';
      _latitude = guess.latitude;
      _longitude = guess.longitude;
    });
  }

  Future<void> _runScan() async {
    final path = _receiptSourcePath;
    if (path == null) return;

    setState(() => _scanning = true);

    try {
      final scanner = await ref.read(receiptScannerProvider.future);
      if (scanner == null) {
        throw Exception('Scanning is not set up. Add both keys in Settings.');
      }
      final categories = await ref.read(categoriesProvider.future);
      final result = await scanner.scan(
        File(path),
        categories: [for (final c in categories) c.name],
      );
      if (!mounted) return;
      _applyScanResult(result, categories);
    } on Exception catch (e) {
      if (!mounted) return;
      showPaperSnack(context, message: '$e');
    } finally {
      if (mounted) {
        setState(() {
          _scanning = false;
          _scanChoiceMade = true;
        });
      }
    }
  }

  void _applyScanResult(ScanResult result, List<ExpenseCategory> categories) {
    final parsed = result.parsed;
    setState(() {
      if ((parsed.merchant ?? '').trim().isNotEmpty) {
        _merchantController.text = parsed.merchant!.trim();
      }
      if (parsed.totalAmountMinor != null) {
        _amount = AmountEntry.fromAgorot(parsed.totalAmountMinor!);
      }
      if ((parsed.description ?? '').trim().isNotEmpty) {
        _noteController.text = parsed.description!.trim();
        _showNote = true;
      }
      if (parsed.categoryGuess != null && widget.fromRule == null) {
        final normalized = parsed.categoryGuess!.trim().toLowerCase();
        for (final c in categories) {
          if (c.name.toLowerCase() == normalized) {
            _categoryId = c.id;
            _categoryChosenByHand = true;
            break;
          }
        }
      }
      _source = ExpenseSource.scanned;
      _ocrRaw = result.rawText;
      _ocrModel = result.model;
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
      // Same reason as the dialogs: the root navigator is above the InkScope.
      useRootNavigator: false,
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
            paymentMethodId: _paymentMethodId,
            installments: _installments,
            interestBp: _interestBp,
            locationLabel: location.isEmpty ? null : location,
            latitude: _latitude,
            longitude: _longitude,
            occurredAt: _occurredAt,
            source: _source,
            ocrRaw: _ocrRaw,
            ocrModel: _ocrModel,
            isBusiness: _isBusiness,
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
            paymentMethodId: _paymentMethodId,
            installments: _installments,
            interestBp: _interestBp,
            recurringRuleId: widget.fromRule?.id,
            locationLabel: location.isEmpty ? null : location,
            latitude: _latitude,
            longitude: _longitude,
            receiptPath: '', // set by the repository once the file is stored
            source: _source,
            ocrRaw: _ocrRaw,
            ocrModel: _ocrModel,
            isBusiness: _isBusiness,
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
      showPaperSnack(
        context,
        message:
            _isEditing ? 'Expense updated' : 'Saved · ${Money.format(amount)}',
      );
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showPaperSnack(
        context,
        message: "That didn't save. Try again. ($e)",
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

  /// Escape, the system back, and the close button all come through here.
  ///
  /// A register keypad still eats the first back, the way the system keyboard
  /// does. The close button is an explicit discard, so it asks immediately.
  Future<void> _requestLeave({bool fromCloseButton = false}) async {
    if (_leaving) return;
    if (!fromCloseButton && _keypadOpen) return;

    if (!_isEditing && _hasEnteredData) {
      _leaving = true;
      final leave = await _confirmLeave();
      _leaving = false;
      if (!leave || !mounted) return;
    }
    if (!mounted) return;
    _popSheet();
  }

  Future<bool> _confirmLeave() async {
    final palette = context.thermal;
    return await showDialog<bool>(
          context: context,
          useRootNavigator: false,
          builder: (context) => AlertDialog(
            backgroundColor: palette.paper,
            surfaceTintColor: Colors.transparent,
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
            titleTextStyle:
                Type.display.copyWith(fontSize: 20, color: palette.print),
            contentTextStyle: Type.body.copyWith(color: palette.print),
            title: const Text('Leave this expense?'),
            content: const Text(
              'Are you sure you want to leave? It is not recorded yet.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Stay'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Leave'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _popSheet() {
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop();
      return;
    }
    // Hub quick action opens this sheet as the mini-app's only route.
    Navigator.of(context, rootNavigator: true).pop();
  }

  // ------------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;
    final hasReceipt = _receiptSourcePath != null || _isEditing;
    final presence = ref.watch(apiKeyPresenceProvider);
    final keysReady = presence.valueOrNull;
    final canScan = keysReady != null &&
        keysReady[ApiKeyKind.googleVision] == true &&
        keysReady[ApiKeyKind.openRouter] == true;
    final keysLoading = presence.isLoading;
    final offerScan = !_isEditing &&
        !_scanChoiceMade &&
        _receiptSourcePath != null &&
        (canScan || keysLoading);

    Widget body;
    if (!hasReceipt) {
      body = _CaptureStage(
        busy: _busy,
        onCamera: () => _capture(ImageSource.camera),
        onGallery: () => _capture(ImageSource.gallery),
      );
    } else if (offerScan && keysLoading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (offerScan && canScan) {
      body = _ScanChoiceStage(
        sourcePath: _receiptSourcePath!,
        scanning: _scanning,
        onScan: _runScan,
        onFillMyself: () => setState(() => _scanChoiceMade = true),
      );
    } else {
      body = _buildForm();
    }

    return PopScope(
      canPop: _isEditing || !_hasEnteredData,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        unawaited(_requestLeave());
      },
      child: Scaffold(
        backgroundColor: palette.paper,
        appBar: AppBar(
          leading: IconButton(
            icon: const AppIcon(SolarIcons.CloseCircle),
            tooltip: 'Discard',
            onPressed: () => unawaited(_requestLeave(fromCloseButton: true)),
          ),
          title: Text(_isEditing ? 'Edit expense' : 'New expense'),
        ),
        body: body,
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
                        AppIcon(SolarIcons.MapPoint,
                            size: 15, color: palette.faded),
                        const SizedBox(width: Space.xs),
                        Expanded(
                          child: TextField(
                            controller: _locationController,
                            style: Type.caption.copyWith(color: palette.faded),
                            cursorColor: palette.carbon,
                            decoration: InputDecoration(
                              hintText: _locationSettled
                                  ? 'Where was this?'
                                  : 'Finding you…',
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
                label: 'FOR',
                child: _BusinessToggle(
                  value: _isBusiness,
                  onChanged: (v) => setState(() {
                    _isBusiness = v;
                    _keypadOpen = false;
                  }),
                ),
              ),
              _Block(
                label: 'PAID WITH',
                child: _PaidWith(
                  selected: _paymentMethodId,
                  installments: _installments,
                  interestBp: _interestBp,
                  amountMinor: _amount.agorot ?? 0,
                  expanded: _installmentsOpen,
                  rateOpen: _rateOpen,
                  rateController: _rateController,
                  onSelected: (id) => setState(() {
                    _paymentMethodId = id;
                    _methodChosenByHand = true;
                    _keypadOpen = false;
                  }),
                  onExpand: () => setState(() {
                    _installmentsOpen = true;
                    _keypadOpen = false;
                  }),
                  onCount: (count) => setState(() {
                    _installments = count;
                    if (count == 1) {
                      _interestBp = 0;
                      _rateOpen = false;
                    }
                  }),
                  onOpenRate: () => setState(() => _rateOpen = true),
                  onRate: (bp) => setState(() => _interestBp = bp),
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
                    icon: const AppIcon(SolarIcons.AddCircle, size: 18),
                    label: const Text('Add a note'),
                  ),
                ),
              const SizedBox(height: Space.lg),
              _ReceiptStrip(
                sourcePath: _receiptSourcePath,
                existing: widget.existing,
                onRetake: () => _capture(ImageSource.camera),
                onChoosePhoto: () => _capture(ImageSource.gallery),
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
              icon: const AppIcon(SolarIcons.CameraMinimalistic, size: 20),
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

/// Shown right after a receipt is captured, before any field is filled —
/// the only moment where an image exists and nothing has been typed yet.
///
/// Scanning starts on its own. The common path is: photograph, wait a few
/// seconds, land on a filled form. "Fill it in myself" is the escape, not
/// the default.
class _ScanChoiceStage extends StatefulWidget {
  const _ScanChoiceStage({
    required this.sourcePath,
    required this.scanning,
    required this.onScan,
    required this.onFillMyself,
  });

  final String sourcePath;
  final bool scanning;
  final VoidCallback onScan;
  final VoidCallback onFillMyself;

  @override
  State<_ScanChoiceStage> createState() => _ScanChoiceStageState();
}

class _ScanChoiceStageState extends State<_ScanChoiceStage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !widget.scanning) widget.onScan();
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;

    return Padding(
      padding: const EdgeInsets.all(Space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: Radii.media,
              child: Image.file(
                File(widget.sourcePath),
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: Space.lg),
          const PerforatedRule(),
          const SizedBox(height: Space.lg),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: widget.scanning ? null : widget.onScan,
              child: widget.scanning
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: palette.paper,
                          ),
                        ),
                        const SizedBox(width: Space.sm),
                        const Text('Reading the receipt…'),
                      ],
                    )
                  : const Text('Scan receipt'),
            ),
          ),
          const SizedBox(height: Space.md),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: widget.scanning ? null : widget.onFillMyself,
              child: const Text('Fill it in myself'),
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
            AppIcon(
              active ? SolarIcons.Minimize : SolarIcons.Calculator,
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

class _BusinessToggle extends StatelessWidget {
  const _BusinessToggle({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;

    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.xs),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Business expense',
                style: Type.item.copyWith(color: palette.print),
              ),
            ),
            Switch(value: value, onChanged: onChanged),
          ],
        ),
      ),
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
              ink: c.stamp,
              onTap: () => onSelected(c.id!),
            ),
        ],
      ),
      orElse: () => const SizedBox(height: 40),
    );
  }
}

/// The one block that had to get richer without getting slower.
///
/// Chips come pre-answered and ordered by how often you use them, so the
/// common capture touches nothing here. The installment line only exists at all
/// on a credit method, and even then it is one line of faded caption until you
/// tap it — because 98 slips in 100 are a single payment, and the interface
/// should cost what the common case costs, not what the rare one needs.
class _PaidWith extends ConsumerWidget {
  const _PaidWith({
    required this.selected,
    required this.installments,
    required this.interestBp,
    required this.amountMinor,
    required this.expanded,
    required this.rateOpen,
    required this.rateController,
    required this.onSelected,
    required this.onExpand,
    required this.onCount,
    required this.onOpenRate,
    required this.onRate,
  });

  final int? selected;
  final int installments;
  final int interestBp;
  final int amountMinor;
  final bool expanded;
  final bool rateOpen;
  final TextEditingController rateController;
  final ValueChanged<int> onSelected;
  final VoidCallback onExpand;
  final ValueChanged<int> onCount;
  final VoidCallback onOpenRate;
  final ValueChanged<int> onRate;

  /// The counts a card terminal actually offers. Anything else is typed into
  /// the bank's app, not remembered here.
  static const _counts = [1, 2, 3, 4, 6, 10, 12];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.thermal;
    final methods = ref.watch(paymentMethodsByUseProvider);

    return methods.maybeWhen(
      data: (items) {
        final chosen = items.where((m) => m.id == selected).firstOrNull;
        final plan = InstallmentPlan.split(
          principalMinor: amountMinor,
          count: installments,
          interestBp: interestBp,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: Space.sm,
              runSpacing: Space.sm,
              children: [
                for (final method in items)
                  _Chip(
                    label: method.label,
                    selected: method.id == selected,
                    onTap: () => onSelected(method.id!),
                  ),
              ],
            ),
            if (chosen != null && chosen.isCredit) ...[
              const SizedBox(height: Space.md),
              InkWell(
                onTap: expanded ? null : onExpand,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: Space.xs),
                  child: Text(
                    plan.caption,
                    style: Type.caption.copyWith(
                      color: installments > 1 ? palette.print : palette.faded,
                    ),
                  ),
                ),
              ),
              if (expanded) ...[
                const SizedBox(height: Space.sm),
                Wrap(
                  spacing: Space.sm,
                  runSpacing: Space.sm,
                  children: [
                    for (final count in _counts)
                      LedgerPlate(
                        label: '$count',
                        selected: count == installments,
                        onTap: () => onCount(count),
                      ),
                  ],
                ),
                if (installments > 1) ...[
                  const SizedBox(height: Space.sm),
                  if (!rateOpen)
                    InkWell(
                      onTap: onOpenRate,
                      child: Padding(
                        padding:
                            const EdgeInsets.symmetric(vertical: Space.xs),
                        child: Text(
                          'No interest',
                          style:
                              Type.caption.copyWith(color: palette.faded),
                        ),
                      ),
                    )
                  else
                    Row(
                      children: [
                        SizedBox(
                          width: 72,
                          child: TextField(
                            controller: rateController,
                            autofocus: true,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            style: Type.mono.copyWith(color: palette.print),
                            cursorColor: palette.carbon,
                            decoration: const InputDecoration(
                              hintText: '0',
                              filled: false,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                            ),
                            onChanged: (text) {
                              final percent = double.tryParse(text) ?? 0;
                              onRate((percent * 100).round().clamp(0, 100000));
                            },
                          ),
                        ),
                        Text(
                          '% a year, spread over the payments',
                          style: Type.caption.copyWith(color: palette.faded),
                        ),
                      ],
                    ),
                ],
              ],
            ],
          ],
        );
      },
      orElse: () => const SizedBox(height: 40),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.ink,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final CategoryInk? ink;

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;
    final fill = ink?.of(Theme.of(context).brightness) ?? palette.carbon;
    final onFill = palette.paper;

    return Material(
      color: selected ? fill : palette.paperShade,
      borderRadius: Radii.control,
      child: InkWell(
        borderRadius: Radii.control,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Space.md + 2,
            vertical: Space.sm + 2,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (ink != null && !selected) ...[
                CategoryStamp(ink: ink!, size: 8),
                const SizedBox(width: Space.sm),
              ],
              Text(
                label,
                style: Type.body.copyWith(
                  color: selected ? onFill : palette.print,
                ),
              ),
            ],
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
    required this.onChoosePhoto,
  });

  final String? sourcePath;
  final Expense? existing;
  final VoidCallback onRetake;
  final VoidCallback onChoosePhoto;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.thermal;

    Widget image;
    if (sourcePath != null) {
      image = Image.file(File(sourcePath!), height: 120, fit: BoxFit.cover);
    } else if (existing != null && !existing!.hasReceipt) {
      // A standing order wrote this one, so there is nothing to show and
      // nothing went wrong. Say so, and offer the camera in case the paper
      // bill has since arrived.
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('RECEIPT', style: Type.eyebrow.copyWith(color: palette.faded)),
          const SizedBox(height: Space.xs),
          Text(
            'No receipt on this one.',
            style: Type.body.copyWith(color: palette.faded),
          ),
          const SizedBox(height: Space.sm),
          OutlinedButton.icon(
            onPressed: onRetake,
            icon: const AppIcon(SolarIcons.CameraMinimalistic, size: 18),
            label: const Text('Photograph it'),
          ),
        ],
      );
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
              TextButton(
                onPressed: onRetake,
                style: TextButton.styleFrom(
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(vertical: Space.xs),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  alignment: Alignment.centerLeft,
                ),
                child: const Text('Retake'),
              ),
              TextButton(
                onPressed: onChoosePhoto,
                style: TextButton.styleFrom(
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(vertical: Space.xs),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  alignment: Alignment.centerLeft,
                ),
                child: const Text('Choose a photo'),
              ),
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
