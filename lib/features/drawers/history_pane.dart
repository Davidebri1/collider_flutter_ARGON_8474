import 'package:flutter/material.dart';

import '../../core/api/collider_api.dart';
import '../../core/vision/vision_kit.dart';
import '../../models/model_def.dart';
import '../../models/ticker_item.dart';
import 'history_drawer.dart' show VHistoryRowsGrouped;

/// History. Made by Claude (2026-10-17) on David's word: "history is not a submenu. It's a pane. an overlay pane.
/// and it will be a scrollable list of selections", with "a preview ... like Windows 11's preview pane".
/// A pane over the room with the conversations listed; choosing one opens the preview beside the list (on a phone,
/// in place of it, with the way back at the top). The preview shows the question, the consensus and every model's
/// answer, takes a follow-up that every model in it answers right there, and carries Load Conversation, which opens
/// the whole conversation in the app.
class HistoryPane extends StatefulWidget {
  final List<ConversationHistorySession> sessions;
  final JobState? Function(String id) job;
  final ValueChanged<ConversationHistorySession> onLoad;
  final VoidCallback onClose;

  const HistoryPane({super.key, required this.sessions, required this.job, required this.onLoad, required this.onClose});

  @override
  State<HistoryPane> createState() => _HistoryPaneState();
}

class _HistoryPaneState extends State<HistoryPane> {
  final _search = TextEditingController();
  String _q = '';
  ConversationHistorySession? _open;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final wide = size.width >= 768;
    final listW = wide ? 300.0 : (size.width - 32).clamp(260.0, 380.0);
    final previewW = wide ? (size.width - 300 - 120).clamp(320.0, 460.0) : listW;
    final h = (size.height * (wide ? 0.66 : 0.62)).clamp(320.0, 720.0);
    final q = _q.toLowerCase();
    final sessions = widget.sessions.where((s) => q.isEmpty || s.title.toLowerCase().contains(q) || s.summary.toLowerCase().contains(q)).toList();
    final open = _open;

    final list = SizedBox(
      width: listW,
      height: h,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(VSpace.md, VSpace.sm, VSpace.xs, VSpace.xs),
            child: Row(children: [
              Expanded(child: Text('History', style: VType.headline())),
              VCircleButton(icon: Icons.close_rounded, size: 30, tooltip: 'Close', onTap: widget.onClose),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(VSpace.sm, 0, VSpace.sm, VSpace.xs),
            child: VSearchField(controller: _search, hint: 'Search', onChanged: (v) => setState(() => _q = v.trim())),
          ),
          Expanded(
            child: VHistoryRowsGrouped(
              sessions: sessions,
              selectedId: open?.id,
              onSelect: (s) => setState(() => _open = identical(_open, s) && wide ? null : s),
            ),
          ),
        ],
      ),
    );

    Widget pane;
    if (wide) {
      pane = Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        list,
        AnimatedSize(
          duration: VMotion.base,
          curve: Curves.easeOutCubic,
          alignment: Alignment.centerLeft,
          child: open == null
              ? const SizedBox(height: 0)
              : Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 0.5, height: h, color: VColors.borderLight),
                  SizedBox(width: previewW, height: h, child: _Preview(key: ValueKey(open.id), session: open, job: widget.job(open.id), onLoad: () => widget.onLoad(open))),
                ]),
        ),
      ]);
    } else {
      pane = AnimatedSwitcher(
        duration: VMotion.base,
        child: open == null
            ? KeyedSubtree(key: const ValueKey('list'), child: list)
            : SizedBox(
                key: ValueKey(open.id),
                width: listW,
                height: h,
                child: _Preview(session: open, job: widget.job(open.id), onLoad: () => widget.onLoad(open), onBack: () => setState(() => _open = null)),
              ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        VScrim(onTap: widget.onClose),
        Align(
          alignment: wide ? Alignment.center : Alignment.topCenter,
          child: Padding(
            padding: EdgeInsets.only(top: wide ? 0 : 56, bottom: wide ? 40 : 0),
            child: GestureDetector(
              onTap: () {},
              child: VGlass(material: VMaterial.modal, radius: VRadius.lg + 4, child: pane),
            ),
          ),
        ),
      ],
    );
  }
}

/// The preview: the question, the consensus, each model's answer; a follow-up field; Load Conversation.
class _Preview extends StatefulWidget {
  final ConversationHistorySession session;
  final JobState? job;
  final VoidCallback onLoad;
  final VoidCallback? onBack;
  const _Preview({super.key, required this.session, required this.job, required this.onLoad, this.onBack});

  @override
  State<_Preview> createState() => _PreviewState();
}

class _Turn {
  final String question;
  final Map<String, String?> answers = {}; // model id -> answer (null while it is being written)
  _Turn(this.question);
}

class _PreviewState extends State<_Preview> {
  final _ctrl = TextEditingController();
  final List<_Turn> _turns = [];

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  /// Every model in the conversation answers the follow-up with the conversation so far, here in the preview.
  void _send() {
    final text = _ctrl.text.trim();
    final job = widget.job;
    if (text.isEmpty || job == null) return;
    _ctrl.clear();
    final turn = _Turn(text);
    setState(() => _turns.add(turn));
    final mode = AskMode.values.firstWhere((m) => m.wire == job.mode, orElse: () => AskMode.chat);
    for (final e in job.results.entries) {
      if (e.value.status != 'done') continue;
      final mid = e.key;
      turn.answers[mid] = null;
      final messages = <Map<String, String>>[
        {'role': 'user', 'content': job.prompt},
        {'role': 'assistant', 'content': e.value.text},
        for (final t in _turns.where((t) => t != turn)) ...[
          {'role': 'user', 'content': t.question},
          if (t.answers[mid] != null) {'role': 'assistant', 'content': t.answers[mid]!},
        ],
        {'role': 'user', 'content': text},
      ];
      ColliderApi.instance.reply(model: mid, messages: messages, mode: mode).then((r) {
        if (mounted) setState(() => turn.answers[mid] = r.text);
      }).catchError((Object _) {
        if (mounted) setState(() => turn.answers.remove(mid));
      });
    }
  }

  Widget _answer(String mid, String? text) {
    final def = ModelRoster.byId(mid);
    final c = def?.providerColor ?? VColors.textSecondary;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Color.alphaBlend(c.withValues(alpha: 0.18), VColors.fillRow), Color.alphaBlend(c.withValues(alpha: 0.06), VColors.fillRow)]),
        borderRadius: BorderRadius.circular(VRadius.row),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(def?.label ?? mid, style: VType.caption(color: VColors.textSecondary, weight: FontWeight.w500)),
        const SizedBox(height: 4),
        text == null
            ? const SizedBox(height: 14, width: 14, child: CircularProgressIndicator(strokeWidth: 1.5, color: VColors.textSecondary))
            : MdText(text, style: VType.callout(weight: FontWeight.w400).copyWith(fontSize: 13, height: 1.4)),
      ]),
    );
  }

  Widget _question(String q) => Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8, left: 32),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: VColors.fillActive, borderRadius: BorderRadius.circular(VRadius.row)),
          child: Text(q, style: VType.callout(weight: FontWeight.w500).copyWith(fontSize: 13)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final job = widget.job;
    final s = widget.session;
    final consensus = job?.consensus.summary ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(VSpace.xs, VSpace.sm, VSpace.sm, VSpace.xs),
          child: Row(children: [
            if (widget.onBack != null) ...[VCircleButton(icon: Icons.chevron_left_rounded, size: 30, onTap: widget.onBack), const SizedBox(width: 6)] else const SizedBox(width: 8),
            Expanded(child: Text(s.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: VType.callout(weight: FontWeight.w600))),
            const SizedBox(width: 8),
            VPress(
              onTap: widget.onLoad,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(color: VColors.accentBlue, borderRadius: BorderRadius.circular(VRadius.full)),
                child: Text('Load Conversation', style: VType.caption(color: Colors.white, weight: FontWeight.w600).copyWith(fontSize: 12)),
              ),
            ),
          ]),
        ),
        Expanded(
          child: VFadeScroll(
            padding: const EdgeInsets.fromLTRB(VSpace.sm, VSpace.xxs, VSpace.sm, VSpace.sm),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _question(job?.prompt ?? s.title),
              if (consensus.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                  decoration: BoxDecoration(color: VColors.fillRow, borderRadius: BorderRadius.circular(VRadius.row), border: Border.all(color: VColors.borderLight, width: 0.5)),
                  child: MdText(consensus, style: VType.callout(weight: FontWeight.w500).copyWith(fontSize: 13, height: 1.4)),
                ),
              if (job != null)
                for (final e in job.results.entries)
                  if (e.value.status == 'done' && e.value.text.isNotEmpty) _answer(e.key, e.value.text),
              for (final t in _turns) ...[
                _question(t.question),
                for (final e in t.answers.entries) _answer(e.key, e.value),
              ],
            ]),
          ),
        ),
        if (job != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(VSpace.sm, 0, VSpace.sm, VSpace.sm),
            child: VRecessed(
              radius: 17,
              padding: const EdgeInsets.fromLTRB(14, 0, 4, 0),
              child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.5),
                    child: TextField(
                      controller: _ctrl,
                      minLines: 1,
                      maxLines: 4,
                      cursorColor: VColors.textPrimary,
                      textInputAction: TextInputAction.send,
                      style: VType.callout(weight: FontWeight.w500).copyWith(fontSize: 13, height: 17 / 13),
                      decoration: InputDecoration(
                        hintText: 'Enter message',
                        hintStyle: VType.callout(color: const Color(0x99FFFFFF), weight: FontWeight.w400).copyWith(fontSize: 13, height: 17 / 13),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: VPress(
                    onTap: _send,
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: VColors.fillActive),
                      child: const Icon(Icons.arrow_upward_rounded, size: 15, color: Colors.white),
                    ),
                  ),
                ),
              ]),
            ),
          ),
      ],
    );
  }
}
