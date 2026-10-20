import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/media/theme_cloud.dart';
import '../../../core/media/video_window.dart';
import '../../../core/platform/open_url.dart';
import '../../../core/vision/vision_kit.dart';
import '../../../core/vision/work_surface.dart';
import '../../../models/theme_def.dart';
import '../../theme/theme_living_media.dart';
import '../../theme/theme_pack_store.dart';

/// Discover Market. Rebuilt by Claude (2026-10-18) on the layout of Grok's Imagine feed (Mobbin, Grok iOS):
///  - the feed: two or more columns of tall tiles edge to edge, a video tile marked with a small play button;
///  - a tile opens Collider's own video player (VideoWindow, Figma row 19); its "more" holds save, download and share;
///    a sideways swipe moves to the next one;
///  - the side rail: Discover, and My Gallery for the saved ones.
/// What it shows: David's live wallpapers from his Cloudflare bucket (ThemeCloud). No prompts anywhere.
/// It is a pane, like Smart Gen. The labels are David's: "I'm discover market. so dont copy words."
class MarketScreen extends StatefulWidget {
  final VoidCallback onClose;
  final String view; // 'discover' or 'gallery'

  const MarketScreen({super.key, required this.onClose, this.view = 'discover'});

  @override
  State<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends State<MarketScreen> {
  static const _savedKey = 'market_saved_v1';
  static final Set<String> _savedCache = {};
  static bool _savedLoaded = false;
  final Set<String> _saved = {..._savedCache};
  int? _open; // index into the list on show

  @override
  void initState() {
    super.initState();
    ThemeCloud.instance.addListener(_changed);
    ThemeCloud.instance.init();
    ThemePackStore.instance.init();
    if (!_savedLoaded) {
      SharedPreferences.getInstance().then((p) {
        final list = p.getStringList(_savedKey) ?? const [];
        _savedCache
          ..clear()
          ..addAll(list);
        _savedLoaded = true;
        if (!mounted) return;
        setState(() => _saved
          ..clear()
          ..addAll(_savedCache));
      });
    }
  }

  @override
  void dispose() {
    ThemeCloud.instance.removeListener(_changed);
    super.dispose();
  }

  void _changed() => mounted ? setState(() {}) : null;

  List<WallpaperTheme> get _items {
    final all = [for (final t in ThemeCloud.instance.themes) if (t.videoPath != null) t];
    return widget.view == 'gallery' ? [for (final t in all) if (_saved.contains(t.id)) t] : all;
  }

  Future<void> _toggleSave(WallpaperTheme t) async {
    setState(() {
      if (_saved.contains(t.id)) {
        _saved.remove(t.id);
        _savedCache.remove(t.id);
      } else {
        _saved.add(t.id);
        _savedCache.add(t.id);
      }
    });
    (await SharedPreferences.getInstance()).setStringList(_savedKey, _saved.toList()..sort());
  }

  @override
  void didUpdateWidget(MarketScreen old) {
    super.didUpdateWidget(old);
    if (old.view != widget.view) _open = null;
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return Stack(
      children: [
        VWorkSurface(
          title: 'Discover Market',
          onClose: widget.onClose,
          child: _grid(items),
        ),
        if (_open != null && _open! < items.length)
          Positioned.fill(
            child: _Viewer(
              items: items,
              start: _open!,
              saved: _saved,
              onSave: _toggleSave,
              onClose: () => setState(() => _open = null),
            ),
          ),
      ],
    );
  }

  Widget _grid(List<WallpaperTheme> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(builder: (context, c) {
      final cols = (c.maxWidth / 200).floor().clamp(2, 5);
      return ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(VRadius.xl)),
        child: GridView.builder(
          padding: const EdgeInsets.fromLTRB(2, 0, 2, 2),
          physics: const BouncingScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: cols, mainAxisSpacing: 2, crossAxisSpacing: 2, childAspectRatio: 0.78),
          itemCount: items.length,
          itemBuilder: (_, i) => VPress(onTap: () => setState(() => _open = i), child: _Tile(theme: items[i])),
        ),
      );
    });
  }
}

/// A feed tile: the poster, and Grok's small play button in the corner for a video.
class _Tile extends StatelessWidget {
  final WallpaperTheme theme;
  const _Tile({required this.theme});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ThemePosterImage(
            theme: theme,
            placeholder: const ColoredBox(color: Color(0xFF111318)),
          ),
          Positioned(
            right: 8,
            bottom: 8,
            child: Container(
              width: 26,
              height: 26,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0x66000000)),
              child: const Icon(Icons.play_arrow_rounded, size: 16, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

/// Grok's viewer, inside the pane: one item at a time, a sideways swipe to the next.
class _Viewer extends StatefulWidget {
  final List<WallpaperTheme> items;
  final int start;
  final Set<String> saved;
  final Future<void> Function(WallpaperTheme) onSave;
  final VoidCallback onClose;
  const _Viewer({required this.items, required this.start, required this.saved, required this.onSave, required this.onClose});

  @override
  State<_Viewer> createState() => _ViewerState();
}

class _ViewerState extends State<_Viewer> {
  late final PageController _pages = PageController(initialPage: widget.start);
  late int _i = widget.start;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _toast(String text) {
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text), behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 2)));
  }

  /// A pack not yet owned is bought first (the store's own sheet, or the bypass); then the file opens.
  Future<void> _download(WallpaperTheme t) async {
    final store = ThemePackStore.instance;
    if (store.priceFor(t) != null && !store.isUnlocked(t.id)) {
      final outcome = await store.buy(t);
      if (!mounted) return;
      await PurchaseNotice.show(context, outcome, bypassed: store.bypass);
      if (outcome != PurchaseOutcome.purchased) return;
    }
    openUrl(t.videoPath!);
  }

  Future<void> _share(WallpaperTheme t) async {
    await Clipboard.setData(ClipboardData(text: t.videoPath!));
    if (mounted) _toast('Copied');
  }

  Widget _icon(IconData icon, VoidCallback onTap, {Color color = Colors.white}) => VPress(
        onTap: onTap,
        child: SizedBox(width: 36, height: 30, child: Icon(icon, size: 18, color: color)),
      );

  @override
  Widget build(BuildContext context) {
    final rail = MediaQuery.sizeOf(context).width < 768 ? 56.0 : 0.0;
    return Stack(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onClose,
          child: const ColoredBox(color: Color(0xCC06080E), child: SizedBox.expand()),
        ),
        Padding(
          padding: EdgeInsets.only(left: rail),
          child: SafeArea(
            child: PageView.builder(
              controller: _pages,
              itemCount: widget.items.length,
              onPageChanged: (i) => setState(() => _i = i),
              itemBuilder: (_, i) {
                final t = widget.items[i];
                final saved = widget.saved.contains(t.id);
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onClose,
                  child: Padding(
                  padding: const EdgeInsets.fromLTRB(VSpace.md, VSpace.lg, VSpace.md, VSpace.md),
                  child: VideoWindow(
                    key: ValueKey(t.id),
                    url: t.videoPath!,
                    poster: t.assetPath,
                    active: i == _i,
                    onClose: widget.onClose,
                    actions: [
                      _icon(saved ? Icons.favorite_rounded : Icons.favorite_border_rounded, () async {
                        await widget.onSave(t);
                        if (mounted) setState(() {});
                      }, color: saved ? const Color(0xFFE5484D) : Colors.white),
                      _icon(Icons.download_rounded, () => _download(t)),
                      _icon(Icons.ios_share_rounded, () => _share(t)),
                    ],
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
}
