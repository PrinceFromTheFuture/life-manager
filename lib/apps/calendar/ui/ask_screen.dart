import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shopping_list/apps/calendar/data/ai/calendar_plan.dart';
import 'package:shopping_list/apps/calendar/data/ai/calendar_scribe.dart';
import 'package:shopping_list/apps/calendar/data/clock.dart';
import 'package:shopping_list/apps/calendar/state/providers.dart';
import 'package:shopping_list/core/design/paper_snack.dart';
import 'package:shopping_list/core/design/theme.dart';
import 'package:shopping_list/core/design/tokens.dart';
import 'package:shopping_list/core/design/widgets/app_icon.dart';
import 'package:shopping_list/core/design/widgets/perforation.dart';

/// Chat with the blotter scribe. One field, a short reply, a card of edits.
class AskScreen extends ConsumerStatefulWidget {
  const AskScreen({super.key, required this.day});

  final DateTime day;

  static Future<void> open(BuildContext context, {required DateTime day}) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => AskScreen(day: day),
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
  final _request = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();
  final _turns = <_Turn>[];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
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
    final palette = context.thermal;

    return Scaffold(
      backgroundColor: palette.paper,
      appBar: AppBar(title: const Text('Ask')),
      body: Column(
        children: [
          Expanded(
            child: _turns.isEmpty
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Space.lg,
                      Space.xl,
                      Space.lg,
                      0,
                    ),
                    child: Text(
                      'Move gym to 19:00. Add coffee at 8.',
                      style: Type.body.copyWith(color: palette.faded),
                    ),
                  )
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(
                      Space.lg,
                      Space.md,
                      Space.lg,
                      Space.lg,
                    ),
                    itemCount: _turns.length,
                    itemBuilder: (context, i) => _TurnView(turn: _turns[i]),
                  ),
          ),
          const PerforatedRule(),
          Padding(
            padding: EdgeInsets.fromLTRB(
              Space.lg,
              Space.sm,
              Space.lg,
              Space.sm + MediaQuery.paddingOf(context).bottom,
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
                    decoration: const InputDecoration(
                      hintText: 'What should change?',
                      border: InputBorder.none,
                    ),
                  ),
                ),
                if (_busy)
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: palette.faded,
                    ),
                  )
                else
                  IconButton(
                    onPressed: _send,
                    tooltip: 'Ask',
                    icon: const AppIcon(SolarIcons.StarsMinimalistic, size: 22),
                  ),
              ],
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
    final palette = context.thermal;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: palette.paperShade,
                  borderRadius: Radii.key,
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  child: Text(
                    turn.user,
                    style: Type.body.copyWith(color: palette.print),
                  ),
                ),
              ),
            ),
          ),
          if (turn.reply.text.isNotEmpty) ...[
            const SizedBox(height: Space.sm),
            Text(
              turn.reply.text,
              style: Type.body.copyWith(color: palette.print),
            ),
          ],
          if (!turn.reply.plan.isEmpty) ...[
            const SizedBox(height: Space.sm),
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
    final palette = context.thermal;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: palette.perforation),
        color: palette.paper,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
            child: Row(
              children: [
                AppIcon(SolarIcons.Calendar, size: 16, color: palette.faded),
                const SizedBox(width: Space.sm),
                Text(
                  result?.message ?? 'Calendar',
                  style: Type.eyebrow.copyWith(color: palette.faded),
                ),
              ],
            ),
          ),
          const PerforatedRule(),
          for (var i = 0; i < plan.edits.length; i++) ...[
            _EditRow(edit: plan.edits[i]),
            if (i != plan.edits.length - 1) const PerforatedRule(indent: 12),
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
    final palette = context.thermal;
    final label = switch (edit.op) {
      CalendarOp.create => 'ADDED',
      CalendarOp.adjust => 'MOVED',
      CalendarOp.cancel => 'CANCELLED',
    };
    final title = edit.title ?? edit.ticketKey ?? 'Event';
    final when = edit.startsAt == null
        ? null
        : Clock.span(
            edit.startsAt!,
            edit.durationMinutes() ?? 60,
          );

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: Type.eyebrow.copyWith(color: palette.faded),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Type.item.copyWith(color: palette.print)),
                if (when != null)
                  Text(
                    when,
                    style: Type.mono.copyWith(color: palette.faded, fontSize: 11),
                  ),
                if ((edit.location ?? '').isNotEmpty)
                  Text(
                    edit.location!,
                    style: Type.caption.copyWith(color: palette.faded),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
