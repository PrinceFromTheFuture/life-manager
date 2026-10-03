import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shopping_list/apps/calendar/data/ai/calendar_plan.dart';
import 'package:shopping_list/apps/calendar/data/ai/calendar_scribe.dart';
import 'package:shopping_list/apps/calendar/data/clock.dart';
import 'package:shopping_list/apps/calendar/state/providers.dart';
import 'package:shopping_list/apps/calendar/ui/night.dart';
import 'package:shopping_list/core/design/paper_snack.dart';
import 'package:shopping_list/core/design/theme.dart';
import 'package:shopping_list/core/design/tokens.dart';
import 'package:shopping_list/core/design/widgets/app_icon.dart';

/// Chat with the blotter scribe. One field, a short reply, a card of edits.
class AskScreen extends ConsumerStatefulWidget {
  const AskScreen({super.key, required this.day});

  final DateTime day;

  static Future<void> open(BuildContext context, {required DateTime day}) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => NightTheme(child: AskScreen(day: day)),
      ),
    );
  }

  @override
  ConsumerState<AskScreen> createState() => _AskScreenState();
}

class _Turn {
  const _Turn({required this.user, required this.reply, this.result});

  final String user;
  final CalendarReply reply;
  final ApplyResult? result;
}

class _AskScreenState extends ConsumerState<AskScreen> {
  static const _prompts = [
    'Move the gym to 19:00',
    'Coffee with Dana tomorrow at 8',
    'Clear Friday afternoon',
  ];

  final _request = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();
  final _turns = <_Turn>[];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _request.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _request.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  List<Map<String, String>> get _history {
    final out = <Map<String, String>>[];
    for (final turn in _turns) {
      out.add({'role': 'user', 'content': turn.user});
      final body = [
        if (turn.reply.text.isNotEmpty) turn.reply.text,
        if (!turn.reply.plan.isEmpty) turn.reply.plan.toFence(),
      ].join('\n\n');
      if (body.isNotEmpty) {
        out.add({'role': 'assistant', 'content': body});
      }
    }
    return out;
  }

  Future<void> _send() async {
    final text = _request.text.trim();
    if (text.isEmpty || _busy) return;
    unawaited(HapticFeedback.lightImpact());
    setState(() => _busy = true);
    _request.clear();
    try {
      final outcome = await ref.read(calendarControllerProvider).converse(
            request: text,
            day: widget.day,
            history: _history,
          );
      if (!mounted) return;
      setState(() {
        _turns.add(
          _Turn(user: text, reply: outcome.reply, result: outcome.result),
        );
        _busy = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scroll.hasClients) return;
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: Motion.quick,
          curve: Curves.easeOut,
        );
      });
    } on CalendarScribeException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showPaperSnack(context, message: e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      showPaperSnack(context, message: 'Could not do that.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSend = _request.text.trim().isNotEmpty && !_busy;

    return Scaffold(
      backgroundColor: Night.ground,
      appBar: AppBar(
        title: const Text('Ask'),
        backgroundColor: Night.ground,
      ),
      body: Column(
        children: [
          Expanded(
            child: _turns.isEmpty
                ? ListView(
                    padding: const EdgeInsets.fromLTRB(Space.lg, Space.lg, Space.lg, 0),
                    children: [
                      Text(
                        'Say what should change.',
                        style: Type.display.copyWith(fontSize: 26, color: Night.bone),
                      ),
                      const SizedBox(height: Space.xs),
                      Text(
                        'Moves, additions and cancellations land on the week at once.',
                        style: Type.body.copyWith(color: Night.mist),
                      ),
                      const SizedBox(height: Space.lg),
                      Wrap(
                        spacing: Space.sm,
                        runSpacing: Space.sm,
                        children: [
                          for (final prompt in _prompts)
                            ActionChip(
                              label: Text(prompt),
                              labelStyle: Type.item.copyWith(fontSize: 14, color: Night.bone),
                              backgroundColor: Night.tile,
                              side: BorderSide.none,
                              shape: const StadiumBorder(),
                              onPressed: () {
                                _request.text = prompt;
                                _request.selection = TextSelection.collapsed(offset: prompt.length);
                                _focus.requestFocus();
                              },
                            ),
                        ],
                      ),
                    ],
                  )
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(Space.lg, Space.md, Space.lg, Space.lg),
                    itemCount: _turns.length,
                    itemBuilder: (context, i) => _TurnView(turn: _turns[i]),
                  ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              Space.md,
              Space.sm,
              Space.md,
              Space.sm + MediaQuery.paddingOf(context).bottom,
            ),
            child: Container(
              padding: const EdgeInsets.fromLTRB(Space.lg, 4, 6, 4),
              decoration: const BoxDecoration(
                color: Night.tile,
                borderRadius: BorderRadius.all(Radius.circular(26)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _request,
                      focusNode: _focus,
                      enabled: !_busy,
                      minLines: 1,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      style: Type.item.copyWith(color: Night.bone),
                      decoration: const InputDecoration(
                        hintText: 'What should change?',
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: canSend || _busy ? Night.bone : Night.well,
                        shape: BoxShape.circle,
                      ),
                      child: _busy
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(strokeWidth: 2, color: Night.ink),
                            )
                          : IconButton(
                              onPressed: canSend ? _send : null,
                              tooltip: 'Ask',
                              icon: AppIcon(
                                SolarIcons.StarsMinimalistic,
                                size: 20,
                                color: canSend ? Night.ink : Night.mist,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TurnView extends StatelessWidget {
  const _TurnView({required this.turn});

  final _Turn turn;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300),
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  color: Night.tile,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(18),
                    topRight: Radius.circular(18),
                    bottomLeft: Radius.circular(18),
                    bottomRight: Radius.circular(6),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                  child: Text(turn.user, style: Type.body.copyWith(color: Night.bone)),
                ),
              ),
            ),
          ),
          if (turn.reply.text.isNotEmpty) ...[
            const SizedBox(height: Space.md),
            Text(turn.reply.text, style: Type.body.copyWith(color: Night.bone)),
          ],
          if (!turn.reply.plan.isEmpty) ...[
            const SizedBox(height: Space.md),
            CalendarEditArtifact(plan: turn.reply.plan, result: turn.result),
          ],
        ],
      ),
    );
  }
}

/// Card for a ```calendar-edit fence. Same job as InfoFloPrint's
/// entity-reference: the model emits JSON, the UI paints a receipt of it.
class CalendarEditArtifact extends StatelessWidget {
  const CalendarEditArtifact({super.key, required this.plan, this.result});

  final CalendarPlan plan;
  final ApplyResult? result;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Night.tile,
        borderRadius: const BorderRadius.all(Radius.circular(18)),
        border: Border.all(color: Night.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
            child: Row(
              children: [
                const AppIcon(SolarIcons.Calendar, size: 16, color: Night.mist),
                const SizedBox(width: Space.sm),
                Expanded(
                  child: Text(
                    (result?.message ?? 'Calendar').toUpperCase(),
                    style: Type.eyebrow.copyWith(color: Night.mist),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Night.line),
          for (var i = 0; i < plan.edits.length; i++) ...[
            _EditRow(edit: plan.edits[i]),
            if (i != plan.edits.length - 1)
              const Divider(height: 1, thickness: 1, indent: 14, color: Night.hairline),
          ],
        ],
      ),
    );
  }
}

class _EditRow extends StatelessWidget {
  const _EditRow({required this.edit});

  final CalendarEdit edit;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (edit.op) {
      CalendarOp.create => ('ADDED', Night.bone),
      CalendarOp.adjust => ('MOVED', Night.caution),
      CalendarOp.cancel => ('CANCELLED', Night.danger),
    };
    final title = edit.title ?? edit.ticketKey ?? 'Event';
    final when = edit.startsAt == null
        ? null
        : Clock.span(edit.startsAt!, edit.durationMinutes() ?? 60);

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 78,
            child: Text(label, style: Type.eyebrow.copyWith(color: color)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Type.item.copyWith(color: Night.bone)),
                if (when != null)
                  Text(when, style: Type.mono.copyWith(color: Night.mist, fontSize: 11)),
                if ((edit.location ?? '').isNotEmpty)
                  Text(edit.location!, style: Type.caption.copyWith(color: Night.mist)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
