import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/platform/open_url.dart';
import '../../../core/api/collider_api.dart';
import '../../../core/vision/vision_kit.dart';
import '../models/browser_tab.dart';
import '../web_frame.dart';

/// In-app browser. Made by Claude.
/// Safari for visionOS, from Apple VisionOS Apps 1:71 (the frame is 3840 wide; its bar and window are 1280).
///   bar 1280 x 80, radius 44, #808080 30%: three round buttons 60 across and 20 apart, 48, the address field
///   724 x 64 (#000000 30%), 48, three round buttons; the window 1280 x 853, radius 40, sits 40 under the bar.
/// The nine options, left to right: sidebar, back, forward | Aa (text size), lock and address, reload |
/// share, new tab, tabs. The sidebar holds the open tabs, Save and Close. One browser; tabs replace the page.
/// Where sizes depart from the frame, docs\DEVIATIONS.md says where and why.
class InAppBrowserSheet extends StatefulWidget {
  final String initialTabId;
  final List<BrowserTab> tabs;
  final Function(BrowserTab updatedTab)? onTabUpdated;
  final Function(BrowserTab newTab)? onNewUserTab;

  const InAppBrowserSheet({
    super.key,
    required this.initialTabId,
    required this.tabs,
    this.onTabUpdated,
    this.onNewUserTab,
  });

  @override
  State<InAppBrowserSheet> createState() => _InAppBrowserSheetState();
}

class _InAppBrowserSheetState extends State<InAppBrowserSheet> {
  // Bing: a search engine whose results the app's page loader can show. Google's results page comes back empty through it.
  static const _homePage = 'https://www.bing.com/';
  static const _search = 'https://www.bing.com/search?q=';

  late String _activeTabId;
  bool _overview = false;
  final TextEditingController _addr = TextEditingController();
  final Map<String, List<String>> _back = {};
  final Map<String, List<String>> _forward = {};
  int _reload = 0;
  bool _sidebar = false;
  double _zoom = 1;
  String? _shownUrl;
  String? _savedName; // set for a moment after something was saved to Files

  // The sheet keeps its own list: the app may replace its list while the browser is open.
  late final List<BrowserTab> _tabs = List.of(widget.tabs);

  BrowserTab get _tab => _tabs.firstWhere((t) => t.id == _activeTabId, orElse: () => _tabs.first);

  @override
  void initState() {
    super.initState();
    _activeTabId = widget.initialTabId;
  }

  @override
  void dispose() {
    _addr.dispose();
    super.dispose();
  }

  void _switchTab(String id) => setState(() {
        _activeTabId = id;
        _overview = false;
      });

  void _newTab() {
    final t = BrowserTab(
      id: 'user_${DateTime.now().millisecondsSinceEpoch}',
      title: 'Search',
      url: _homePage,
      isModelAssigned: false,
      isUserControlling: true,
    );
    _tabs.add(t);
    widget.onNewUserTab?.call(t);
    _switchTab(t.id);
  }

  String _host(String url) => url.replaceFirst(RegExp(r'^https?://'), '');

  /// The site's name alone, as the address field shows it.
  String _site(String url) {
    final h = Uri.tryParse(url)?.host ?? '';
    return h.isEmpty ? _host(url) : h.replaceFirst(RegExp(r'^www\.'), '');
  }

  void _show(String url, {String? title}) {
    final updated = _tab.copyWith(url: url, title: title ?? _host(url));
    final i = _tabs.indexWhere((t) => t.id == updated.id);
    if (i != -1) _tabs[i] = updated;
    widget.onTabUpdated?.call(updated);
    setState(() => _overview = false);
  }

  /// Address bar: a web address opens directly; anything else is searched.
  void _go(String input) {
    final q = input.trim();
    if (q.isEmpty) return;
    final isUrl = !q.contains(' ') && (q.contains('.') || q.startsWith('http'));
    final url = isUrl ? (q.startsWith('http') ? q : 'https://$q') : '$_search${Uri.encodeComponent(q)}';
    if (url == _tab.url) {
      setState(() => _reload++);
      return;
    }
    (_back[_tab.id] ??= []).add(_tab.url);
    _forward[_tab.id]?.clear();
    _show(url, title: isUrl ? null : q);
  }

  /// The page followed a link, sent a form or was redirected.
  void _onNavigated(String url, String title) {
    final tab = _tab;
    if (url != tab.url) {
      (_back[tab.id] ??= []).add(tab.url);
      _forward[tab.id]?.clear();
    } else if (title.isEmpty || title == tab.title) {
      return;
    }
    _show(url, title: title.isEmpty ? null : title);
  }

  void _goBack() {
    final stack = _back[_tab.id];
    if (stack == null || stack.isEmpty) return;
    (_forward[_tab.id] ??= []).add(_tab.url);
    _show(stack.removeLast());
  }

  void _goForward() {
    final stack = _forward[_tab.id];
    if (stack == null || stack.isEmpty) return;
    (_back[_tab.id] ??= []).add(_tab.url);
    _show(stack.removeLast());
  }

  void _flashSaved(String? name) {
    if (name == null || name.isEmpty || !mounted) return;
    setState(() => _savedName = name);
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) setState(() => _savedName = null);
    });
  }

  /// Saves the page being shown to Files > Downloaded.
  Future<void> _save() async => _flashSaved(await ColliderApi.instance.download(_tab.url));

  @override
  Widget build(BuildContext context) {
    final tab = _tab;
    if (_shownUrl != tab.url) {
      _shownUrl = tab.url;
      _addr.text = _site(tab.url);
    }
    final size = MediaQuery.sizeOf(context);
    final h = math.max(size.height - 56 - 84 - 54, 320.0);
    final canBack = (_back[tab.id] ?? const []).isNotEmpty;
    final canForward = (_forward[tab.id] ?? const []).isNotEmpty;

    // Deviation D6: the round buttons are 30 across, not 60 x k (18 on a phone): a finger has to hit them.
    Widget round(IconData icon, String tip, VoidCallback? onTap, {bool on = false}) => VCircleButton(
          icon: icon,
          size: 30,
          selected: true,
          tooltip: tip,
          iconColor: onTap == null ? VColors.textTertiary : (on ? VColors.accentBlue : null),
          onTap: onTap,
        );

    return Stack(
      children: [
        Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      alignment: Alignment.topCenter,
      insetPadding: const EdgeInsets.fromLTRB(VSpace.xl, 56, VSpace.xl, 92),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // The bar. A downward swipe on it closes the browser.
            GestureDetector(
              onVerticalDragEnd: (d) {
                if ((d.primaryVelocity ?? 0) > 250) Navigator.of(context).pop();
              },
              child: VGlass(
                material: VMaterial.elevated,
                radius: VRadius.full,
                fill: const Color(0x4D808080),
                padding: const EdgeInsets.all(6),
                child: Row(
                  children: [
                    round(Icons.view_sidebar_outlined, 'Sidebar', () => setState(() => _sidebar = !_sidebar), on: _sidebar),
                    const SizedBox(width: 3),
                    round(Icons.chevron_left_rounded, 'Back', canBack ? _goBack : null),
                    const SizedBox(width: 3),
                    round(Icons.chevron_right_rounded, 'Forward', canForward ? _goForward : null),
                    const SizedBox(width: 6),
                    Expanded(
                      child: VRecessed(
                        height: 30,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Row(
                          children: [
                            VPress(
                              tooltip: 'Text Size',
                              onTap: () => setState(() => _zoom = _zoom >= 1.3 ? 1 : _zoom + 0.15),
                              child: Text('Aa', style: VType.caption(color: VColors.textPrimary, weight: FontWeight.w500).copyWith(fontSize: 12)),
                            ),
                            const SizedBox(width: 3),
                            const Icon(Icons.lock_rounded, size: 10, color: Color(0x99FFFFFF)),
                            const SizedBox(width: 3),
                            Expanded(
                              child: TextField(
                                controller: _addr,
                                textAlign: TextAlign.center,
                                cursorColor: VColors.textPrimary,
                                style: VType.caption(color: VColors.textPrimary, weight: FontWeight.w500).copyWith(fontSize: 12),
                                keyboardType: TextInputType.url,
                                textInputAction: TextInputAction.go,
                                decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
                                onTap: () {
                                  _addr.text = _tab.url;
                                  _addr.selection = TextSelection(baseOffset: 0, extentOffset: _addr.text.length);
                                },
                                onSubmitted: _go,
                              ),
                            ),
                            const SizedBox(width: 4),
                            VPress(
                              tooltip: 'Reload',
                              onTap: () => setState(() => _reload++),
                              child: const Icon(Icons.refresh_rounded, size: 15, color: VColors.textPrimary),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    round(Icons.ios_share_rounded, 'Share', _share),
                    const SizedBox(width: 3),
                    round(Icons.add_rounded, 'New Tab', _newTab),
                    const SizedBox(width: 3),
                    round(Icons.filter_none_rounded, 'Tabs', () => setState(() => _overview = !_overview), on: _overview),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // The window: the page inside glass, the sidebar over its left side when it is open.
            SizedBox(
              height: h,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: VGlass(
                      material: VMaterial.work,
                      radius: 20,
                      padding: const EdgeInsets.all(5),
                      child: AnimatedSwitcher(
                        duration: VMotion.base,
                        child: _overview ? _tabsOverview() : _page(tab),
                      ),
                    ),
                  ),
                  if (_sidebar) Positioned(left: 8, top: 8, width: 200, child: _sidebarPanel()),
                ],
              ),
            ),
          ],
        ),
      ),
        ),
      ],
    );
  }

  /// Shares the page's address; where the device has no share sheet, copies it.
  Future<void> _share() async {
    if (canShareText && await shareText(_tab.url)) return;
    await Clipboard.setData(ClipboardData(text: _tab.url));
    _flashSaved('Copied');
  }

  /// The sidebar: the open tabs, then Save (the page, to Files) and Close.
  Widget _sidebarPanel() {
    Widget row(IconData? icon, String label, VoidCallback onTap, {bool on = false}) => VPress(
          onTap: onTap,
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(color: on ? const Color(0x24FFFFFF) : Colors.transparent, borderRadius: BorderRadius.circular(11)),
            child: Row(
              children: [
                if (icon != null) ...[Icon(icon, size: 16, color: VColors.textSecondary), const SizedBox(width: 10)],
                Expanded(child: Text(label, maxLines: 1, softWrap: false, overflow: TextOverflow.fade, style: VType.callout(weight: FontWeight.w500))),
              ],
            ),
          ),
        );
    // Solid backing: the page under this panel is a web frame, which glass cannot blur.
    return DecoratedBox(
      decoration: BoxDecoration(color: const Color(0xFF1C2026), borderRadius: BorderRadius.circular(16)),
      child: VGlass(
      material: VMaterial.modal,
      radius: 16,
      padding: const EdgeInsets.all(6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final t in _tabs)
            row(null, t.title.isEmpty ? _host(t.url) : t.title, () {
              _switchTab(t.id);
              setState(() => _sidebar = false);
            }, on: t.id == _activeTabId),
          row(_savedName != null ? Icons.check_rounded : Icons.download_rounded, _savedName ?? 'Save', _save),
          row(Icons.close_rounded, 'Close', () => Navigator.of(context).pop()),
        ],
      ),
      ),
    );
  }

  Widget _page(BrowserTab tab) {
    return ClipRRect(
      key: ValueKey('page-${tab.id}'),
      borderRadius: BorderRadius.circular(15),
      child: WebFrame(
        key: ValueKey('frame-${tab.id}'),
        url: tab.url,
        reload: _reload,
        zoom: _zoom,
        onNavigated: _onNavigated,
        onDownloaded: _flashSaved,
      ),
    );
  }

  Widget _tabsOverview() {
    return LayoutBuilder(
      key: const ValueKey('tabs'),
      builder: (context, c) {
        final cols = c.maxWidth < 420 ? 2 : 3;
        return Padding(
          padding: const EdgeInsets.all(VSpace.sm),
          child: GridView.builder(
            physics: const BouncingScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: cols, childAspectRatio: 0.9),
            itemCount: _tabs.length,
            itemBuilder: (_, i) {
              final t = _tabs[i];
              return VTile(
                selected: t.id == _activeTabId,
                onTap: () => _switchTab(t.id),
                aspect: 4 / 3,
                title: t.title,
                subtitle: t.isModelAssigned ? (t.modelName ?? 'Model') : _host(t.url),
                media: Container(
                  color: VColors.fillCell,
                  child: Icon(t.isModelAssigned ? Icons.terminal_rounded : Icons.public_rounded, size: 26, color: VColors.textSecondary),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
