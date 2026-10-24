import '../../core/drafts.dart';
import 'dart:math' as math;
import 'package:material_ui/material_ui.dart';
import '../../core/vision/vision_kit.dart';
import '../../models/model_def.dart';
import '../../models/ticker_item.dart';
import '../browser/models/browser_tab.dart';
import '../drawers/history_drawer.dart';

enum ActiveWorkSurface {
  chat,
  smartgen,
  market,
  themes,
  browser,
  files,
}

enum SideNavTab { local, global }

/// Contextual glass panel beside the rail: History, Models selector (active lit at top, inactive dimmed below), etc.
class ContextualSideNav extends StatefulWidget {
  final ActiveWorkSurface activeSurface;

  // AI Chat props
  final ModelCategory activeCategory;
  final List<String> selectedModelIds;
  final Map<String, List<ConversationHistorySession>> localHistory;
  final List<ConversationHistorySession> globalHistory;
  final String consensusRatio;
  final String consensusSummary;
  final String? expandedModelId;
  final ValueChanged<ModelCategory> onSelectCategory;
  final ValueChanged<String> onToggleModel;
  final ValueChanged<ConversationHistorySession> onSelectSession;
  final VoidCallback onOpenConsensus;
  final VoidCallback onNewConversation;
  final String chatSection; // history | models

  // Smart Gen props
  final String activeSmartGenView;
  final String activeSmartGenBoardType;
  final ValueChanged<String>? onSelectSmartGenView;
  final ValueChanged<String>? onSelectSmartGenBoardType;

  // Market props
  final String activeMarketCategory;
  final ValueChanged<String>? onSelectMarketCategory;

  // Themes props
  final String activeThemeSection;
  final ValueChanged<String>? onSelectThemeSection;

  // Browser props
  final List<BrowserTab>? browserTabs;
  final String? activeBrowserTabId;
  final ValueChanged<String>? onSelectBrowserTab;
  final ValueChanged<String>? onCloseBrowserTab;
  final VoidCallback? onClearBrowserCache;

  // Files props
  final String activeFilesCategory;
  final ValueChanged<String>? onSelectFilesCategory;

  final ValueChanged<ActiveWorkSurface>? onRequestSwitchSurface;
  final VoidCallback onPaneInteraction;
  final VoidCallback? onClose;

  const ContextualSideNav({
    super.key,
    this.activeSurface = ActiveWorkSurface.chat,
    required this.activeCategory,
    required this.selectedModelIds,
    required this.localHistory,
    required this.globalHistory,
    required this.consensusRatio,
    required this.consensusSummary,
    required this.expandedModelId,
    required this.onSelectCategory,
    required this.onToggleModel,
    required this.onSelectSession,
    required this.onOpenConsensus,
    required this.onNewConversation,
    this.chatSection = 'history',
    this.activeSmartGenView = 'cards',
    this.activeSmartGenBoardType = 'kanban',
    this.onSelectSmartGenView,
    this.onSelectSmartGenBoardType,
    this.activeMarketCategory = 'discover',
    this.onSelectMarketCategory,
    this.activeThemeSection = 'gallery',
    this.onSelectThemeSection,
    this.browserTabs,
    this.activeBrowserTabId,
    this.onSelectBrowserTab,
    this.onCloseBrowserTab,
    this.onClearBrowserCache,
    this.activeFilesCategory = 'all',
    this.onSelectFilesCategory,
    this.onRequestSwitchSurface,
    required this.onPaneInteraction,
    this.onClose,
  });

  @override
  State<ContextualSideNav> createState() => _ContextualSideNavState();
}

class _ContextualSideNavState extends State<ContextualSideNav> {
  SideNavTab _chatTab = SideNavTab.global;
  final TextEditingController _chatSearchCtrl = Drafts.text('sidenav.search');
  String _chatQuery = '';

  List<ConversationHistorySession> _sessions() {
    final q = _chatQuery.toLowerCase().trim();
    final source = _local
        ? (widget.localHistory[widget.expandedModelId] ?? const <ConversationHistorySession>[])
        : widget.globalHistory;
    if (q.isEmpty) return source;
    return source
        .where((s) =>
            s.title.toLowerCase().contains(q) ||
            s.summary.toLowerCase().contains(q) ||
            s.messages.any((m) => m.text.toLowerCase().contains(q)))
        .toList();
  }

  bool get _local => widget.expandedModelId != null && _chatTab == SideNavTab.local;

  String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 768;
    final width = isMobile ? math.min(236.0, size.width - 96) : 276.0;
    final maxHeight = math.min(460.0, size.height * 0.56);

    final history = widget.activeSurface == ActiveWorkSurface.chat && widget.chatSection != 'models';
    final title = switch (widget.activeSurface) {
      ActiveWorkSurface.chat => history ? 'History' : 'Models',
      ActiveWorkSurface.smartgen => 'Smart Gen',
      ActiveWorkSurface.market => 'Discover',
      ActiveWorkSurface.themes => 'Theme Studio',
      ActiveWorkSurface.browser => 'Web Browser',
      ActiveWorkSurface.files => 'Files Library',
    };

    final hug = widget.activeSurface == ActiveWorkSurface.chat;
    final body = AnimatedSwitcher(
      duration: VMotion.base,
      child: KeyedSubtree(
        key: ValueKey('${widget.activeSurface}-${widget.chatSection}-$_local'),
        child: _content(),
      ),
    );
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: SizedBox(
        width: width,
        height: hug ? null : maxHeight,
        child: VGlass(
          material: VMaterial.elevated,
          radius: 22,
          padding: const EdgeInsets.fromLTRB(12, 10, 10, 12),
          child: Column(
            mainAxisSize: hug ? MainAxisSize.min : MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 28,
                child: Row(
                  children: [
                    const SizedBox(width: 2),
                    Expanded(
                      child: history && widget.expandedModelId != null
                          ? Align(alignment: Alignment.centerLeft, child: _historyTabs())
                          : Text(title, maxLines: 1, style: VType.callout(weight: FontWeight.w600)),
                    ),
                    if (widget.onClose != null)
                      VCircleButton(icon: Icons.close_rounded, size: 26, tooltip: 'Close', onTap: widget.onClose),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              hug ? Flexible(child: body) : Expanded(child: body),
            ],
          ),
        ),
      ),
    );
  }

  Widget _content() => switch (widget.activeSurface) {
        ActiveWorkSurface.chat => _chat(),
        ActiveWorkSurface.smartgen => _smartGen(),
        ActiveWorkSurface.market => _market(),
        ActiveWorkSurface.themes => _themes(),
        ActiveWorkSurface.browser => _browser(),
        ActiveWorkSurface.files => _files(),
      };

  // ---------------- AI Chat ----------------
  Widget _historyTabs() {
    Widget tab(SideNavTab t, String label) => VPress(
          onTap: () => setState(() => _chatTab = t),
          child: AnimatedContainer(
            duration: VMotion.fast,
            height: 26,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _chatTab == t ? const Color(0x29FFFFFF) : Colors.transparent,
              borderRadius: BorderRadius.circular(VRadius.full),
            ),
            child: Text(
              label,
              style: VType.callout(
                weight: FontWeight.w600,
                color: _chatTab == t ? VColors.textPrimary : VColors.textSecondary,
              ),
            ),
          ),
        );
    return Row(mainAxisSize: MainAxisSize.min, children: [tab(SideNavTab.local, 'Local'), tab(SideNavTab.global, 'Global')]);
  }

  Widget _chat() {
    if (widget.chatSection == 'models') return _models();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        VSearchField(
          controller: _chatSearchCtrl,
          hint: 'Search conversations',
          height: 32,
          onChanged: (v) => setState(() => _chatQuery = v),
        ),
        const SizedBox(height: 6),
        Flexible(child: _history()),
      ],
    );
  }

  /// Models selector:
  /// - Categories: General, Image, Video, Audio (Coding/Writing omitted per user directive).
  /// - Active models are sorted to the top of the container and kept LIT; inactive models sit below and are DIMMED.
  Widget _models() {
    final cats = [
      for (final c in ModelCategory.values)
        if (ModelRoster.forCategory(c).isNotEmpty) c,
    ];
    final cat = cats.contains(widget.activeCategory) || cats.isEmpty ? widget.activeCategory : cats.first;
    final rawModels = ModelRoster.forCategory(cat);
    final activeModels = [
      for (final m in rawModels)
        if (widget.selectedModelIds.contains(m.id)) m,
    ];
    final inactiveModels = [
      for (final m in rawModels)
        if (!widget.selectedModelIds.contains(m.id)) m,
    ];
    final orderedModels = [...activeModels, ...inactiveModels];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (cats.length > 1) ...[
          GestureDetector(
            onHorizontalDragEnd: (d) {
              final v = d.primaryVelocity ?? 0;
              if (v.abs() < 120) return;
              final next = (cats.indexOf(cat) + (v < 0 ? 1 : -1)).clamp(0, cats.length - 1);
              widget.onPaneInteraction();
              widget.onSelectCategory(cats[next]);
            },
            child: VSegmented(
              ornament: false,
              labels: [for (final c in cats) _cap(c.name)],
              active: cats.indexOf(cat),
              onSelect: (i) {
                widget.onPaneInteraction();
                widget.onSelectCategory(cats[i]);
              },
            ),
          ),
          const SizedBox(height: 8),
        ],
        Flexible(
          child: EdgeFade(
            fadeHeight: 12,
            child: ListView.separated(
              shrinkWrap: true,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 2),
              itemCount: orderedModels.length,
              separatorBuilder: (_, i) {
                if (activeModels.isNotEmpty && i == activeModels.length - 1 && inactiveModels.isNotEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Divider(height: 1, thickness: 0.6, color: Colors.white.withValues(alpha: 0.14)),
                  );
                }
                return const SizedBox(height: 5);
              },
              itemBuilder: (_, i) {
                final m = orderedModels[i];
                final isSelected = widget.selectedModelIds.contains(m.id);
                final c = m.providerColor;
                return AnimatedOpacity(
                  duration: VMotion.base,
                  opacity: isSelected ? 1.0 : 0.42,
                  child: VPress(
                    onTap: () {
                      widget.onPaneInteraction();
                      widget.onToggleModel(m.id);
                    },
                    child: AnimatedContainer(
                      duration: VMotion.base,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: isSelected
                            ? LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  c.withValues(alpha: 0.28),
                                  c.withValues(alpha: 0.12),
                                ],
                              )
                            : null,
                        color: isSelected ? null : const Color(0x1F10121A),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? c.withValues(alpha: 0.55) : const Color(0x1AFFFFFF),
                          width: isSelected ? 0.8 : 0.5,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: c.withValues(alpha: 0.16),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : const [],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSelected ? c : c.withValues(alpha: 0.45),
                              boxShadow: isSelected
                                  ? [BoxShadow(color: c.withValues(alpha: 0.85), blurRadius: 6)]
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              m.label,
                              maxLines: 1,
                              softWrap: false,
                              overflow: TextOverflow.fade,
                              style: VType.body(
                                weight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                color: isSelected ? VColors.textPrimary : VColors.textSecondary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                            size: 17,
                            color: isSelected ? c : VColors.textTertiary,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _history() {
    final sessions = _sessions();
    if (sessions.isEmpty) {
      return const SizedBox(height: 12);
    }
    return HistoryRows(sessions: sessions, onSelect: widget.onSelectSession);
  }

  // ---------------- Smart Gen ----------------
  Widget _smartGen() {
    const views = [
      ('cards', 'Cards', Icons.style_rounded),
      ('boards', 'Boards', Icons.dashboard_rounded),
      ('canvas', 'Canvas', Icons.crop_free_rounded),
      ('genie', 'Smart Genie', Icons.assistant_rounded),
    ];
    const boards = [
      ('kanban', 'Kanban'),
      ('calendar', 'Calendar'),
      ('notebook', 'Notebook'),
      ('photo', 'Photo Album'),
      ('storyboard', 'Storyboard'),
      ('vision', 'Vision Board'),
      ('swimlane', 'Swimlanes'),
      ('desk', 'Portfolio Desk'),
      ('us_map', 'US Map'),
      ('world_map', 'World Map'),
    ];
    return EdgeFade(
      fadeHeight: 12,
      child: ListView(
        physics: const BouncingScrollPhysics(),
        children: [
          for (final v in views)
            VSidebarItem(
              icon: v.$3,
              label: v.$2,
              selected: widget.activeSmartGenView == v.$1,
              onTap: () => widget.onSelectSmartGenView?.call(v.$1),
            ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: VSpace.xs),
            child: Divider(height: 0.5, color: VColors.borderLight),
          ),
          for (final b in boards)
            VSidebarItem(
              icon: Icons.view_kanban_outlined,
              label: b.$2,
              selected: widget.activeSmartGenBoardType == b.$1,
              onTap: () => widget.onSelectSmartGenBoardType?.call(b.$1),
            ),
        ],
      ),
    );
  }

  // ---------------- Market ----------------
  Widget _market() {
    const views = [
      ('discover', 'Discover', Icons.explore_outlined),
      ('gallery', 'My Gallery', Icons.collections_outlined),
    ];
    return ListView(
      physics: const BouncingScrollPhysics(),
      children: [
        for (final v in views)
          VSidebarItem(
            icon: v.$3,
            label: v.$2,
            selected: widget.activeMarketCategory == v.$1,
            onTap: () => widget.onSelectMarketCategory?.call(v.$1),
          ),
      ],
    );
  }

  // ---------------- Themes ----------------
  Widget _themes() {
    const sections = [
      ('gallery', 'Theme Gallery', Icons.collections_rounded),
      ('premium', 'Premium Theme Market', Icons.workspace_premium_rounded),
    ];
    return ListView(
      physics: const BouncingScrollPhysics(),
      children: [
        for (final s in sections)
          VSidebarItem(
            icon: s.$3,
            label: s.$2,
            selected: widget.activeThemeSection == s.$1,
            onTap: () => widget.onSelectThemeSection?.call(s.$1),
          ),
      ],
    );
  }

  // ---------------- Browser ----------------
  Widget _browser() {
    final tabs = widget.browserTabs ?? const <BrowserTab>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: tabs.isEmpty
              ? const SizedBox.shrink()
              : ListView(
                  physics: const BouncingScrollPhysics(),
                  children: [
                    for (final t in tabs)
                      VSidebarItem(
                        icon: t.isModelAssigned ? Icons.terminal_rounded : Icons.person_outline_rounded,
                        label: t.title.isEmpty ? t.url : t.title,
                        selected: widget.activeBrowserTabId == t.id,
                        onTap: () => widget.onSelectBrowserTab?.call(t.id),
                        trailing: widget.onCloseBrowserTab == null
                            ? null
                            : VCircleButton(
                                icon: Icons.close_rounded,
                                size: 24,
                                tooltip: 'Close tab',
                                onTap: () => widget.onCloseBrowserTab!(t.id),
                              ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  // ---------------- Files ----------------
  Widget _files() {
    const categories = ['All', 'Documents', 'Code', 'Images', 'Audio', 'Video', 'Artifacts'];
    return ListView(
      physics: const BouncingScrollPhysics(),
      children: [
        for (final c in categories)
          VSidebarItem(
            icon: Icons.folder_rounded,
            label: c,
            selected: widget.activeFilesCategory.toLowerCase() == c.toLowerCase(),
            onTap: () => widget.onSelectFilesCategory?.call(c.toLowerCase()),
          ),
      ],
    );
  }
}
