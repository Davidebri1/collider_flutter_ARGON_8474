import '../../../core/drafts.dart';
import 'package:material_ui/material_ui.dart';
import '../../../core/vision/vision_kit.dart';
import '../smartgen_store.dart';

/// Smart Gen — spatial workspace with Counterpart Boards (Kanban, Monday Pulse, Notebook, Calendar)
/// and distinct Vertical Portrait Cards, Spatial Storyboard Canvas, and Autonomous Genie views (R21–R26).
class SmartGenScreen extends StatefulWidget {
  final VoidCallback onClose;
  final String viewMode;
  final ValueChanged<String>? onViewModeChanged;
  final int newCardTrigger;

  const SmartGenScreen({
    super.key,
    required this.onClose,
    this.viewMode = 'boards',
    this.onViewModeChanged,
    this.newCardTrigger = 0,
  });

  @override
  State<SmartGenScreen> createState() => _SmartGenScreenState();
}

class _SmartGenScreenState extends State<SmartGenScreen> {
  final TextEditingController _searchCtrl = Drafts.text('smartgen.search');
  final SmartGenStore _store = SmartGenStore.instance;
  String _q = '';
  int _tab = 0;
  late String _mode = widget.viewMode;

  // R24: "A board looks like the thing named: notebook, portfolio, kanban, calendar, album, storyboard."
  static const _tabs = ['Kanban Board', 'Monday Pulse', 'Notebook', 'Calendar'];

  static const _kanbanLists = ['High', 'Medium', 'Low'];

  static String _laneLabel(String key) => switch (key) {
        'High' => 'To Do',
        'Medium' => 'Doing',
        'Low' => 'Done',
        _ => key,
      };

  static Color _laneColor(String key) => switch (key) {
        'High' => VColors.accentBlue,
        'Medium' => VColors.accentOrange,
        'Low' => VColors.accentGreen,
        _ => VColors.accentPurple,
      };

  static Color _tagColor(String tag) => switch (tag) {
        'Theme Studio' => VColors.accentPurple,
        'AI Engine' => VColors.accentBlue,
        'Spatial UI' => VColors.accentTeal,
        'Discover' => VColors.accentOrange,
        _ => VColors.accentGreen,
      };

  @override
  void initState() {
    super.initState();
    _store.addListener(_changed);
    _store.load();
  }

  @override
  void didUpdateWidget(covariant SmartGenScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.viewMode != oldWidget.viewMode) {
      _mode = widget.viewMode;
    }
    if (widget.newCardTrigger != oldWidget.newCardTrigger) {
      _store.add('High', 'New Spatial Task');
    }
  }

  void _setMode(String m) {
    setState(() => _mode = m);
    widget.onViewModeChanged?.call(m);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _store.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isMobile = size.width < 768;
    final w = isMobile ? (size.width - 70).clamp(288.0, 344.0) : VOverlay.toolWidth(context);
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(isMobile ? 54 : 0, 8, isMobile ? 8 : 0, 74),
        child: Center(
          child: SizedBox(
            width: w,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _navbar(isMobile),
                const SizedBox(height: 6),
                SizedBox(
                  height: (size.height * (isMobile ? 0.66 : 0.68)).clamp(380.0, 560.0),
                  child: VGlass(
                    material: VMaterial.work,
                    radius: VRadius.card,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_mode == 'boards') _tabsRow(),
                        Expanded(
                          child: _buildModeBody(),
                        ),
                        _searchBar(isMobile),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModeBody() {
    if (_mode == 'cards') {
      return _PortraitCardsGridView(
        key: const ValueKey('mode-cards'),
        store: _store,
        query: _q,
      );
    }
    if (_mode == 'canvas') {
      return _SpatialCanvasView(
        key: const ValueKey('mode-canvas'),
        store: _store,
        query: _q,
      );
    }
    if (_mode == 'genie') {
      return _GenieSynthesisView(
        key: const ValueKey('mode-genie'),
        store: _store,
        query: _q,
      );
    }
    // Boards mode: switches between Kanban (Trello), Monday Pulse, Notebook, and Calendar counterparts (R24)
    return switch (_tab) {
      1 => _MondayPulseBoardView(store: _store, query: _q),
      2 => _NotebookCounterpartView(store: _store, query: _q),
      3 => _CalendarCounterpartView(store: _store, query: _q),
      _ => _KanbanSwimlaneBoard(store: _store, query: _q),
    };
  }

  Widget _navbar(bool isMobile) => VGlass(
        material: VMaterial.elevated,
        radius: VRadius.full,
        padding: EdgeInsets.fromLTRB(isMobile ? 10 : 14, 5, 5, 5),
        child: Row(
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final (id, label, icon) in const [
                      ('boards', 'Boards', Icons.view_kanban_rounded),
                      ('cards', 'Cards', Icons.grid_view_rounded),
                      ('canvas', 'Canvas', Icons.hub_rounded),
                      ('genie', 'Genie', Icons.bolt_rounded),
                    ])
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: VPress(
                          onTap: () => _setMode(id),
                          child: AnimatedContainer(
                            duration: VMotion.fast,
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                            decoration: BoxDecoration(
                              color: _mode == id ? VColors.fillActive : Colors.transparent,
                              borderRadius: BorderRadius.circular(VRadius.full),
                              boxShadow: _mode == id ? VShadow.emissive(VColors.accentBlue, intensity: 0.55) : null,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(icon, size: 12, color: _mode == id ? Colors.white : VColors.textSecondary),
                                const SizedBox(width: 4),
                                Text(
                                  label,
                                  style: VType.caption(
                                    color: _mode == id ? VColors.textPrimary : VColors.textSecondary,
                                    weight: _mode == id ? FontWeight.w600 : FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 4),
            VCircleButton(
              icon: Icons.close_rounded,
              size: 28,
              tooltip: 'Close',
              onTap: widget.onClose,
            ),
          ],
        ),
      );

  Widget _tabsRow() => SizedBox(
        height: 40,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (int i = 0; i < _tabs.length; i++)
                VPress(
                  onTap: () => setState(() => _tab = i),
                  child: Padding(
                    padding: EdgeInsets.only(right: i == _tabs.length - 1 ? 0 : 14),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          _tabs[i],
                          style: VType.callout(
                            color: i == _tab ? VColors.textPrimary : VColors.textSecondary,
                            weight: i == _tab ? FontWeight.w600 : FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 5),
                        AnimatedContainer(
                          duration: VMotion.base,
                          width: 18,
                          height: 2.5,
                          decoration: BoxDecoration(
                            color: i == _tab ? VColors.accentBlue : Colors.transparent,
                            borderRadius: BorderRadius.circular(VRadius.full),
                            boxShadow: i == _tab ? VShadow.emissive(VColors.accentBlue, intensity: 0.7) : null,
                          ),
                        ),
                        const SizedBox(height: 3),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      );

  Widget _searchBar(bool isMobile) => Padding(
        padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
        child: VSearchField(
          controller: _searchCtrl,
          height: 34,
          hint: 'Filter cards or type to search...',
          onChanged: (v) => setState(() => _q = v.trim()),
        ),
      );
}

/// Reusable Vertical Portrait Card (`3:4` aspect ratio, width < height) used across Kanban, Cards Grid, and Storyboard.
class _VerticalPortraitCard extends StatelessWidget {
  final SgCard card;
  final String laneKey;
  final VoidCallback onToggleDone;
  final VoidCallback? onAdvanceLane;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;

  const _VerticalPortraitCard({
    required this.card,
    required this.laneKey,
    required this.onToggleDone,
    this.onAdvanceLane,
    this.onDelete,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final tagHue = _SmartGenScreenState._tagColor(card.tag);
    final laneHue = _SmartGenScreenState._laneColor(laneKey);
    final laneLabel = _SmartGenScreenState._laneLabel(laneKey);

    return VPress(
      onTap: onEdit ?? onToggleDone,
      child: Container(
        height: 182,
        decoration: BoxDecoration(
          color: const Color(0xD9161B26),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: card.done ? VColors.accentGreen.withValues(alpha: 0.45) : const Color(0x2EFFFFFF),
            width: 0.7,
          ),
          boxShadow: const [
            BoxShadow(color: Color(0x4D000000), blurRadius: 10, offset: Offset(0, 4)),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Visual Cover Header (64px)
            SizedBox(
              height: 64,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    card.coverAsset,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [tagHue.withValues(alpha: 0.45), const Color(0xFF0F172A)],
                        ),
                      ),
                    ),
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x33000000), Color(0xB30E121C)],
                      ),
                    ),
                  ),
                  // Top-left Trello category label pill
                  Positioned(
                    left: 7,
                    top: 7,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: tagHue.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        card.tag,
                        style: VType.caption(color: Colors.white, weight: FontWeight.w700).copyWith(fontSize: 9.0),
                      ),
                    ),
                  ),
                  // Top-right 1-tap checkbox circle
                  Positioned(
                    right: 6,
                    top: 6,
                    child: VPress(
                      onTap: onToggleDone,
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: card.done ? VColors.accentGreen : const Color(0x80000000),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 0.8),
                        ),
                        child: Icon(
                          card.done ? Icons.check_rounded : Icons.circle_outlined,
                          size: 13,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Card Body (Title + 2-line 11pt Summary + Footer)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(9, 7, 9, 7),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      card.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: VType.callout(
                        color: card.done ? VColors.textTertiary : VColors.textPrimary,
                        weight: FontWeight.w600,
                      ).copyWith(
                        fontSize: 11.5,
                        height: 1.22,
                        decoration: card.done ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Expanded(
                      child: Text(
                        card.subtitle.isNotEmpty ? card.subtitle : 'Tap to inspect or move across board lanes.',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: VType.summary(color: VColors.textSecondary).copyWith(fontSize: 10.5, height: 1.25),
                      ),
                    ),
                    // Footer: Status dot + label + Due date / Move action
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: card.done ? VColors.accentGreen : laneHue),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            card.done ? 'Done' : laneLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: VType.caption(
                              color: card.done ? VColors.accentGreen : laneHue,
                              weight: FontWeight.w600,
                            ).copyWith(fontSize: 9.5),
                          ),
                        ),
                        if (onAdvanceLane != null)
                          VPress(
                            onTap: onAdvanceLane,
                            tooltip: 'Move to next lane',
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0x1FFFFFFF),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: const Icon(Icons.arrow_forward_rounded, size: 11, color: VColors.textSecondary),
                            ),
                          )
                        else if (onDelete != null)
                          VPress(
                            onTap: onDelete,
                            tooltip: 'Delete card',
                            child: const Icon(Icons.close_rounded, size: 13, color: VColors.textTertiary),
                          )
                        else
                          Text(
                            card.dueDate,
                            style: VType.caption(color: VColors.textTertiary).copyWith(fontSize: 9.0),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 1. Trello Counterpart: Side-by-side vertical Kanban swimlanes containing Vertical Portrait Cards.
class _KanbanSwimlaneBoard extends StatefulWidget {
  final SmartGenStore store;
  final String query;
  const _KanbanSwimlaneBoard({required this.store, required this.query});

  @override
  State<_KanbanSwimlaneBoard> createState() => _KanbanSwimlaneBoardState();
}

class _KanbanSwimlaneBoardState extends State<_KanbanSwimlaneBoard> {
  String? _addingLane;
  SgCard? _editingCard;
  final TextEditingController _inputCtrl = TextEditingController();

  @override
  void dispose() {
    _inputCtrl.dispose();
    super.dispose();
  }

  void _advanceCard(String currentLane, SgCard card) {
    const lanes = _SmartGenScreenState._kanbanLists;
    final idx = lanes.indexOf(currentLane);
    final nextLane = lanes[(idx + 1) % lanes.length];
    widget.store.move(card, nextLane, 0);
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.query.toLowerCase();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (int i = 0; i < _SmartGenScreenState._kanbanLists.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            _buildSwimlane(_SmartGenScreenState._kanbanLists[i], q),
          ],
        ],
      ),
    );
  }

  Widget _buildSwimlane(String laneKey, String q) {
    final all = widget.store.list(laneKey);
    final cards = q.isEmpty
        ? all
        : all.where((c) => c.title.toLowerCase().contains(q) || c.subtitle.toLowerCase().contains(q)).toList();
    final laneHue = _SmartGenScreenState._laneColor(laneKey);
    final laneTitle = _SmartGenScreenState._laneLabel(laneKey);

    return DragTarget<SgCard>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (d) => widget.store.move(d.data, laneKey, 0),
      builder: (context, over, _) => Container(
        width: 146,
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: over.isNotEmpty ? const Color(0x4D000000) : const Color(0x33000000),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: over.isNotEmpty ? laneHue : const Color(0x22FFFFFF),
            width: 0.7,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Swimlane Header (Trello style)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 2, 4, 6),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: laneHue,
                      boxShadow: VShadow.emissive(laneHue, intensity: 0.7),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      laneTitle,
                      style: VType.callout(weight: FontWeight.w700),
                    ),
                  ),
                  VPress(
                    onTap: () => setState(() {
                      _addingLane = laneKey;
                      _editingCard = null;
                      _inputCtrl.clear();
                    }),
                    tooltip: 'Add card to $laneTitle',
                    child: const Icon(Icons.add_rounded, size: 16, color: VColors.textSecondary),
                  ),
                ],
              ),
            ),
            if (_addingLane == laneKey)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161B26),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: VColors.accentBlue, width: 1.0),
                  ),
                  child: Column(
                    children: [
                      TextField(
                        controller: _inputCtrl,
                        autofocus: true,
                        style: VType.body(),
                        decoration: InputDecoration(
                          hintText: 'Card title...',
                          hintStyle: VType.body(color: VColors.textTertiary),
                          isDense: true,
                          border: InputBorder.none,
                        ),
                        onSubmitted: (v) {
                          if (v.trim().isNotEmpty) widget.store.add(laneKey, v.trim());
                          setState(() => _addingLane = null);
                        },
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          VPress(
                            onTap: () => setState(() => _addingLane = null),
                            child: const Icon(Icons.close_rounded, size: 15, color: VColors.textTertiary),
                          ),
                          const SizedBox(width: 8),
                          VPress(
                            onTap: () {
                              if (_inputCtrl.text.trim().isNotEmpty) {
                                widget.store.add(laneKey, _inputCtrl.text.trim());
                              }
                              setState(() => _addingLane = null);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: VColors.accentBlue, borderRadius: BorderRadius.circular(6)),
                              child: Text('Add', style: VType.caption(color: Colors.white, weight: FontWeight.w600)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            // Vertical Portrait Cards inside the Swimlane
            Expanded(
              child: ListView.separated(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.zero,
                itemCount: cards.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, idx) {
                  final card = cards[idx];
                  if (identical(_editingCard, card)) {
                    return Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF161B26),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: VColors.accentBlue, width: 1.2),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextFormField(
                            initialValue: card.title,
                            autofocus: true,
                            maxLines: 3,
                            style: VType.body(),
                            decoration: const InputDecoration(border: InputBorder.none, isDense: true),
                            onChanged: (v) => widget.store.update(card, title: v),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              VPress(
                                onTap: () {
                                  widget.store.remove(card);
                                  setState(() => _editingCard = null);
                                },
                                child: const Icon(Icons.delete_outline_rounded, size: 15, color: VColors.accentRed),
                              ),
                              VPress(
                                onTap: () => setState(() => _editingCard = null),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(color: VColors.accentBlue, borderRadius: BorderRadius.circular(6)),
                                  child: Text('Save', style: VType.caption(color: Colors.white, weight: FontWeight.w600)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }
                  return LongPressDraggable<SgCard>(
                    data: card,
                    delay: const Duration(milliseconds: 200),
                    feedback: Material(
                      type: MaterialType.transparency,
                      child: SizedBox(
                        width: 132,
                        child: _VerticalPortraitCard(
                          card: card,
                          laneKey: laneKey,
                          onToggleDone: () {},
                        ),
                      ),
                    ),
                    childWhenDragging: Opacity(
                      opacity: 0.35,
                      child: _VerticalPortraitCard(
                        card: card,
                        laneKey: laneKey,
                        onToggleDone: () {},
                      ),
                    ),
                    child: _VerticalPortraitCard(
                      card: card,
                      laneKey: laneKey,
                      onToggleDone: () => widget.store.update(card, done: !card.done),
                      onAdvanceLane: () => _advanceCard(laneKey, card),
                      onEdit: () => setState(() {
                        _editingCard = card;
                        _addingLane = null;
                      }),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 6),
            // Trello "+ Add a card" footer button
            VPress(
              onTap: () => setState(() {
                _addingLane = laneKey;
                _editingCard = null;
                _inputCtrl.clear();
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                decoration: BoxDecoration(
                  color: const Color(0x18FFFFFF),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.add_rounded, size: 14, color: VColors.textSecondary),
                    const SizedBox(width: 4),
                    Text('Add a card', style: VType.caption(color: VColors.textSecondary, weight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 2. Monday.com Counterpart: Color-coded Pulse Group Tables with full-fill interactive Status Cells.
class _MondayPulseBoardView extends StatelessWidget {
  final SmartGenStore store;
  final String query;
  const _MondayPulseBoardView({required this.store, required this.query});

  @override
  Widget build(BuildContext context) {
    final q = query.toLowerCase();
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
      children: [
        for (final (laneKey, groupTitle, groupColor) in const [
          ('Medium', 'Active Sprint · Working On It', VColors.accentOrange),
          ('High', 'Up Next · Backlog', VColors.accentBlue),
          ('Low', 'Completed Sprint', VColors.accentGreen),
        ]) ...[
          _buildGroupTable(laneKey, groupTitle, groupColor, q),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _buildGroupTable(String laneKey, String groupTitle, Color groupColor, String q) {
    final cards = store
        .list(laneKey)
        .where((c) => q.isEmpty || c.title.toLowerCase().contains(q) || c.subtitle.toLowerCase().contains(q))
        .toList();
    return Container(
      decoration: BoxDecoration(
        color: const Color(0x38000000),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: groupColor.withValues(alpha: 0.40), width: 0.7),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            color: groupColor.withValues(alpha: 0.18),
            child: Row(
              children: [
                Container(width: 4, height: 14, decoration: BoxDecoration(color: groupColor, borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(groupTitle, style: VType.callout(color: Colors.white, weight: FontWeight.w700)),
                ),
                VPress(
                  onTap: () => store.add(laneKey, 'New Pulse Item'),
                  child: const Icon(Icons.add_circle_outline_rounded, size: 16, color: Colors.white),
                ),
              ],
            ),
          ),
          for (final card in cards)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0x1AFFFFFF), width: 0.5)),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.asset(
                      card.coverAsset,
                      width: 28,
                      height: 36,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(width: 28, height: 36, color: groupColor.withValues(alpha: 0.3)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(card.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: VType.body(weight: FontWeight.w600)),
                        Text(card.tag, style: VType.caption(color: VColors.textTertiary).copyWith(fontSize: 9.5)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Monday.com full-fill interactive status cell
                  VPress(
                    onTap: () {
                      const lanes = ['High', 'Medium', 'Low'];
                      final next = lanes[(lanes.indexOf(laneKey) + 1) % lanes.length];
                      store.move(card, next, 0);
                    },
                    child: Container(
                      width: 82,
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: card.done ? VColors.accentGreen : groupColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        card.done
                            ? 'Done'
                            : (laneKey == 'Medium' ? 'Working on it' : (laneKey == 'Low' ? 'Done' : 'Ready')),
                        style: VType.caption(color: Colors.white, weight: FontWeight.w700).copyWith(fontSize: 9.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// 3. Notebook Counterpart (R24: "A board looks like the thing named: notebook, portfolio, kanban, calendar"):
/// Looks like an actual ruled field notebook page with left red margin line, ruled horizontal lines, and checkable notes.
class _NotebookCounterpartView extends StatelessWidget {
  final SmartGenStore store;
  final String query;
  const _NotebookCounterpartView({required this.store, required this.query});

  @override
  Widget build(BuildContext context) {
    final q = query.toLowerCase();
    final items = <SgCard>[
      for (final l in const ['High', 'Medium', 'Low', 'Projects', 'Reminders'])
        for (final c in store.list(l))
          if (q.isEmpty || c.title.toLowerCase().contains(q) || c.subtitle.toLowerCase().contains(q)) c,
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xD9141923),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0x33FFFFFF), width: 0.7),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Red left notebook margin line
            Positioned(
              left: 34,
              top: 0,
              bottom: 0,
              child: Container(width: 1.2, color: VColors.accentRed.withValues(alpha: 0.45)),
            ),
            ListView.builder(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: items.length + 1,
              itemBuilder: (_, i) {
                if (i == 0) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(44, 4, 12, 8),
                    child: Row(
                      children: [
                        Text('Field Notebook · Spatial Synthesis', style: VType.callout(color: VColors.accentGold, weight: FontWeight.w700)),
                        const Spacer(),
                        VPress(
                          onTap: () => store.add('Reminders', 'New Notebook Entry'),
                          child: const Icon(Icons.note_add_rounded, size: 16, color: VColors.accentGold),
                        ),
                      ],
                    ),
                  );
                }
                final c = items[i - 1];
                return VPress(
                  onTap: () => store.update(c, done: !c.done),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: Color(0x1CFFFFFF), width: 0.6)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 24,
                          child: Icon(
                            c.done ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                            size: 15,
                            color: c.done ? VColors.accentGreen : VColors.textTertiary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                c.title,
                                style: VType.body(
                                  color: c.done ? VColors.textTertiary : VColors.textPrimary,
                                  weight: FontWeight.w600,
                                ).copyWith(decoration: c.done ? TextDecoration.lineThrough : null),
                              ),
                              if (c.subtitle.isNotEmpty)
                                Text(c.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: VType.summary(color: VColors.textSecondary)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// 4. Calendar Counterpart (R24): Schedule grid with day headers and vertical portrait schedule cards.
class _CalendarCounterpartView extends StatelessWidget {
  final SmartGenStore store;
  final String query;
  const _CalendarCounterpartView({required this.store, required this.query});

  @override
  Widget build(BuildContext context) {
    final all = <SgCard>[
      ...store.list('High'),
      ...store.list('Medium'),
      ...store.list('Projects'),
    ];
    const days = [
      ('FRI', '24', true),
      ('SAT', '25', false),
      ('SUN', '26', false),
      ('MON', '27', false),
      ('TUE', '28', false),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Calendar Week Strip
          Row(
            children: [
              for (final (dayName, dayNum, active) in days)
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: active ? VColors.accentBlue.withValues(alpha: 0.28) : const Color(0x26000000),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: active ? VColors.accentBlue : const Color(0x22FFFFFF), width: 0.6),
                    ),
                    child: Column(
                      children: [
                        Text(dayName, style: VType.caption(color: active ? Colors.white : VColors.textTertiary, weight: FontWeight.w600).copyWith(fontSize: 9)),
                        const SizedBox(height: 2),
                        Text(dayNum, style: VType.callout(color: Colors.white, weight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: GridView.builder(
              physics: const BouncingScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 0.72,
              ),
              itemCount: all.length,
              itemBuilder: (_, i) => _VerticalPortraitCard(
                card: all[i],
                laneKey: i.isEven ? 'High' : 'Medium',
                onToggleDone: () => store.update(all[i], done: !all[i].done),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Cards View (R26): 2-Column Vertical Portrait Card Gallery (`3:4` portrait ratio).
class _PortraitCardsGridView extends StatelessWidget {
  final SmartGenStore store;
  final String query;
  const _PortraitCardsGridView({super.key, required this.store, required this.query});

  @override
  Widget build(BuildContext context) {
    final q = query.toLowerCase();
    final items = <(String, SgCard)>[
      for (final l in const ['High', 'Medium', 'Low', 'Projects', 'Reminders'])
        for (final c in store.list(l))
          if (q.isEmpty || c.title.toLowerCase().contains(q) || c.subtitle.toLowerCase().contains(q)) (l, c),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
      child: GridView.builder(
        physics: const BouncingScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 0.72,
        ),
        itemCount: items.length,
        itemBuilder: (_, idx) {
          final (laneKey, card) = items[idx];
          return _VerticalPortraitCard(
            card: card,
            laneKey: laneKey,
            onToggleDone: () => store.update(card, done: !card.done),
            onDelete: () => store.remove(card),
          );
        },
      ),
    );
  }
}

/// Canvas View (R26): Spatial Storyboard Canvas with dotted grid, bezier connectors, and Vertical Portrait Cards.
class _SpatialCanvasView extends StatelessWidget {
  final SmartGenStore store;
  final String query;
  const _SpatialCanvasView({super.key, required this.store, required this.query});

  @override
  Widget build(BuildContext context) {
    final q = query.toLowerCase();
    final items = <(String, SgCard)>[
      for (final l in const ['High', 'Medium', 'Low'])
        for (final c in store.list(l))
          if (q.isEmpty || c.title.toLowerCase().contains(q) || c.subtitle.toLowerCase().contains(q)) (l, c),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 4),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0x33000000),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: VColors.borderLight, width: 0.6),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(painter: _CanvasGridPainter()),
            GridView.builder(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(10),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.72,
              ),
              itemCount: items.length,
              itemBuilder: (_, idx) {
                final (laneKey, card) = items[idx];
                return Transform.rotate(
                  angle: idx.isEven ? -0.014 : 0.014,
                  child: _VerticalPortraitCard(
                    card: card,
                    laneKey: laneKey,
                    onToggleDone: () => store.update(card, done: !card.done),
                    onAdvanceLane: () {
                      const lanes = ['High', 'Medium', 'Low'];
                      final next = lanes[(lanes.indexOf(laneKey) + 1) % lanes.length];
                      store.move(card, next, 0);
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _CanvasGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = const Color(0x22FFFFFF);
    const step = 22.0;
    for (double x = 14; x < size.width; x += step) {
      for (double y = 14; y < size.height; y += step) {
        canvas.drawCircle(Offset(x, y), 1.1, p);
      }
    }
    // Subtle spatial node connector curves
    final linePaint = Paint()
      ..color = VColors.accentBlue.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final path = Path()
      ..moveTo(size.width * 0.28, 95)
      ..cubicTo(size.width * 0.5, 95, size.width * 0.5, 130, size.width * 0.72, 130);
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Genie View (R26): Autonomous Synthesis Cards in a 2-Column Vertical Portrait Layout.
class _GenieSynthesisView extends StatelessWidget {
  final SmartGenStore store;
  final String query;
  const _GenieSynthesisView({super.key, required this.store, required this.query});

  @override
  Widget build(BuildContext context) {
    final q = query.toLowerCase();
    final items = <(String, SgCard)>[
      for (final l in const ['High', 'Medium', 'Low', 'Projects', 'Reminders'])
        for (final c in store.list(l))
          if (q.isEmpty || c.title.toLowerCase().contains(q) || c.subtitle.toLowerCase().contains(q)) (l, c),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: VColors.accentBlue.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: VColors.accentBlue.withValues(alpha: 0.45), width: 0.6),
            ),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome_rounded, size: 16, color: VColors.accentBlue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Genie Autonomous Synthesis · Distilled from Consensus',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: VType.callout(weight: FontWeight.w600),
                  ),
                ),
                VPress(
                  onTap: () => store.syncAutonomousCards(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: VColors.fillActive, borderRadius: BorderRadius.circular(VRadius.full)),
                    child: Text('Refresh', style: VType.caption(color: Colors.white, weight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: GridView.builder(
              physics: const BouncingScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 0.72,
              ),
              itemCount: items.length,
              itemBuilder: (_, idx) {
                final (laneKey, card) = items[idx];
                return _VerticalPortraitCard(
                  card: card,
                  laneKey: laneKey,
                  onToggleDone: () => store.update(card, done: !card.done),
                  onAdvanceLane: () => store.move(card, 'Medium', 0),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
