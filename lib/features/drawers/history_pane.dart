import '../../core/drafts.dart';
import 'package:material_ui/material_ui.dart';

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
  final VoidCallback? onUpdated;

  const HistoryPane({
    super.key,
    required this.sessions,
    required this.job,
    required this.onLoad,
    required this.onClose,
    this.onUpdated,
  });

  @override
  State<HistoryPane> createState() => _HistoryPaneState();
}

class _HistoryPaneState extends State<HistoryPane> {
  final TextEditingController _search = Drafts.text('history.pane.search');
  String _q = '';
  ConversationHistorySession? _open;
  bool _previewInitDone = false;

  @override
  void dispose() {
    super.dispose();
  }

  void _syncPreviewParam(List<ConversationHistorySession> sessions) {
    if (_previewInitDone || sessions.isEmpty) return;
    final p = Uri.base.queryParameters['preview'];
    if (p != null) {
      _previewInitDone = true;
      final idx = int.tryParse(p) ?? 0;
      _open = sessions[idx.clamp(0, sessions.length - 1)];
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final wide = size.width >= 768;
    final listW = wide ? 300.0 : VOverlay.toolWidth(context);
    final previewW = wide ? (size.width - 300 - 120).clamp(320.0, 460.0) : listW;
    final h = (size.height * (wide ? 0.66 : 0.62)).clamp(320.0, 720.0);
    final q = _q.toLowerCase();
    final sessions = widget.sessions.where((s) => q.isEmpty || s.title.toLowerCase().contains(q) || s.summary.toLowerCase().contains(q)).toList();
    _syncPreviewParam(sessions);
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
                  SizedBox(
                    width: previewW,
                    height: h,
                    child: _Preview(
                      key: ValueKey(open.id),
                      session: open,
                      job: widget.job(open.id),
                      onLoad: () => widget.onLoad(open),
                      onUpdated: widget.onUpdated,
                    ),
                  ),
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
                child: _Preview(
                  session: open,
                  job: widget.job(open.id),
                  onLoad: () => widget.onLoad(open),
                  onBack: () => setState(() => _open = null),
                  onUpdated: widget.onUpdated,
                ),
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
  final VoidCallback? onUpdated;
  const _Preview({super.key, required this.session, required this.job, required this.onLoad, this.onBack, this.onUpdated});

  @override
  State<_Preview> createState() => _PreviewState();
}

class _Turn {
  final String question;
  final Map<String, String?> answers = {}; // model id -> answer (null while it is being written)
  _Turn(this.question);
}

class _PreviewState extends State<_Preview> {
  final TextEditingController _ctrl = Drafts.text('history.pane.reply');
  final List<_Turn> _turns = [];

  @override
  void dispose() {
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
      final baseHistory = e.value.messages.isNotEmpty
          ? [for (final m in e.value.messages) {'role': m['role'] ?? 'user', 'content': m['content'] ?? ''}]
          : <Map<String, String>>[
              {'role': 'user', 'content': job.prompt},
              {'role': 'assistant', 'content': e.value.text},
            ];
      final messages = <Map<String, String>>[
        ...baseHistory,
        for (final t in _turns.where((t) => t != turn)) ...[
          {'role': 'user', 'content': t.question},
          if (t.answers[mid] != null) {'role': 'assistant', 'content': t.answers[mid]!},
        ],
        {'role': 'user', 'content': text},
      ];
      // Each answer drafts in place as the model writes it and persists to the session (Claude, 2026-10-19).
      ColliderApi.instance.replyStream(model: mid, messages: messages, mode: mode, jobId: job.id).listen((d) {
        if (mounted && d.text.isNotEmpty) setState(() => turn.answers[mid] = d.text);
        if (d.done) {
          ColliderApi.instance.cachedHistory = null;
          widget.onUpdated?.call();
        }
      }, onError: (Object _) {
        if (mounted) setState(() => turn.answers.remove(mid));
      }, cancelOnError: true);
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

  /// Extracts any persisted follow-up turns beyond the initial question so the preview shows the full thread.
  List<_Turn> _persistedFollowUps(JobState? job) {
    if (job == null) return const [];
    final out = <_Turn>[];
    for (final e in job.results.entries) {
      final msgs = e.value.messages;
      if (msgs.length <= 2) continue;
      var turnIdx = 0;
      for (var i = 2; i < msgs.length; i++) {
        final role = msgs[i]['role'] ?? 'user';
        final content = msgs[i]['content'] ?? '';
        if (role == 'user') {
          if (turnIdx >= out.length) out.add(_Turn(content));
          turnIdx++;
        } else if (role == 'assistant' && turnIdx > 0 && turnIdx <= out.length) {
          out[turnIdx - 1].answers[e.key] = content;
        }
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final job = widget.job;
    final s = widget.session;
    final consensus = job?.consensus.summary ?? '';
    final persistedTurns = _persistedFollowUps(job);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(VSpace.xs, VSpace.sm, VSpace.sm, VSpace.xs),
          child: Row(children: [
            if (widget.onBack != null) ...[VCircleButton(icon: Icons.chevron_left_rounded, size: 30, onTap: widget.onBack), const SizedBox(width: 6)] else const SizedBox(width: 8),
            Expanded(child: Text(s.title, maxLines: 1, softWrap: false, overflow: TextOverflow.fade, style: VType.callout(weight: FontWeight.w600))),
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
                  if (e.value.status == 'done' && e.value.text.isNotEmpty)
                    _answer(
                      e.key,
                      e.value.messages.length >= 2 && (e.value.messages[1]['role'] == 'assistant')
                          ? e.value.messages[1]['content']
                          : e.value.text,
                    ),
              for (final t in persistedTurns) ...[
                _question(t.question),
                for (final e in t.answers.entries) _answer(e.key, e.value),
              ],
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
