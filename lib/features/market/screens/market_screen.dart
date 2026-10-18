import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

import '../../../core/media/theme_cloud.dart';
import '../../../core/platform/open_url.dart';
import '../../../core/vision/vision_kit.dart';
import '../../../core/vision/work_surface.dart';
import '../../../models/theme_def.dart';
import '../../theme/theme_pack_store.dart';

/// Discover Market. Rebuilt by Claude (2026-10-18) as a copy of Grok's Imagine (Mobbin, Grok iOS):
///  - the feed: two or more columns of tall tiles edge to edge, a video tile marked with a small play button;
///  - a tile opens the viewer: back at the top left, the picture in the middle, play/pause and sound on the left and
///    save, download and share on the right, the position line, then the title in a bar; a sideways swipe moves to
///    the next one;
///  - Saved: the saved ones, from the heart (Grok's Saved view).
/// What it shows: David's live wallpapers from his Cloudflare bucket (ThemeCloud). No prompts anywhere.
/// It is a pane, like Smart Gen: the side rail switches between Imagine and Saved.
class MarketScreen extends StatefulWidget {
  final VoidCallback onClose;
  final String view; // 'imagine' or 'saved'

  const MarketScreen({super.key, required this.onClose, this.view = 'imagine'});

  @override
  State<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends State<MarketScreen> {
  static const _savedKey = 'market_saved_v1';
  final Set<String> _saved = {};
  int? _open; // index into the list on show

  @override
  void initState() {
    super.initState();
    ThemeCloud.instance.addListener(_changed);
    ThemeCloud.instance.init();
    ThemePackStore.instance.init();
    SharedPreferences.getInstance().then((p) {
      if (!mounted) return;
      setState(() => _saved.addAll(p.getStringList(_savedKey) ?? const []));
    });
  }

  @override
  void dispose() {
    ThemeCloud.instance.removeListener(_changed);
    super.dispose();
  }

  void _changed() => mounted ? setState(() {}) : null;

  List<WallpaperTheme> get _items {
    final all = [for (final t in ThemeCloud.instance.themes) if (t.videoPath != null) t];
    return widget.view == 'saved' ? [for (final t in all) if (_saved.contains(t.id)) t] : all;
  }

  Future<void> _toggleSave(WallpaperTheme t) async {
    setState(() => _saved.contains(t.id) ? _saved.remove(t.id) : _saved.add(t.id));
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
          _Poster(url: theme.assetPath),
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

class _Poster extends StatelessWidget {
  final String url;
  const _Poster({required this.url});

  @override
  Widget build(BuildContext context) {
    const empty = ColoredBox(color: Color(0xFF111318));
    if (url.isEmpty) return empty;
    final img = url.startsWith('http')
        ? Image.network(url, fit: BoxFit.cover, gaplessPlayback: true, errorBuilder: (_, __, ___) => empty,
            frameBuilder: (_, child, frame, sync) => frame == null && !sync ? empty : child)
        : Image.asset(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => empty);
    return img;
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

  @override
  Widget build(BuildContext context) {
    final rail = MediaQuery.sizeOf(context).width < 768 ? 56.0 : 0.0;
    return Stack(
      children: [
        VScrim(onTap: widget.onClose),
        Padding(
          padding: EdgeInsets.only(left: rail),
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(VSpace.sm, VSpace.sm, VSpace.sm, 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: VCircleButton(icon: Icons.arrow_back_rounded, tooltip: 'Back', onTap: widget.onClose),
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _pages,
                    itemCount: widget.items.length,
                    onPageChanged: (i) => setState(() => _i = i),
                    itemBuilder: (_, i) => _Page(
                      key: ValueKey(widget.items[i].id),
                      theme: widget.items[i],
                      active: i == _i,
                      saved: widget.saved.contains(widget.items[i].id),
                      onSave: () async {
                        await widget.onSave(widget.items[i]);
                        if (mounted) setState(() {});
                      },
                      onDownload: () => _download(widget.items[i]),
                      onShare: () => _share(widget.items[i]),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Page extends StatefulWidget {
  final WallpaperTheme theme;
  final bool active;
  final bool saved;
  final VoidCallback onSave;
  final VoidCallback onDownload;
  final VoidCallback onShare;
  const _Page({super.key, required this.theme, required this.active, required this.saved, required this.onSave, required this.onDownload, required this.onShare});

  @override
  State<_Page> createState() => _PageState();
}

class _PageState extends State<_Page> {
  VideoPlayerController? _c;
  bool _muted = true;

  @override
  void initState() {
    super.initState();
    if (widget.active) _start();
  }

  @override
  void didUpdateWidget(_Page old) {
    super.didUpdateWidget(old);
    if (widget.active && _c == null) _start();
    if (!widget.active) _c?.pause();
    if (widget.active && _c != null && _c!.value.isInitialized && !_c!.value.isPlaying) _c!.play();
  }

  void _start() {
    final c = _c = VideoPlayerController.networkUrl(Uri.parse(widget.theme.videoPath!));
    c.addListener(() => mounted ? setState(() {}) : null);
    c.initialize().then((_) async {
      await c.setLooping(true);
      await c.setVolume(0);
      if (widget.active) await c.play();
    });
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  void _seek(double dx, double w) {
    final c = _c;
    if (c == null || w <= 0) return;
    final d = c.value.duration;
    if (d == Duration.zero) return;
    c.seekTo(d * (dx / w).clamp(0.0, 1.0));
  }

  Widget _pill(List<Widget> children) => VGlass(
        material: VMaterial.elevated,
        radius: VRadius.full,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(mainAxisSize: MainAxisSize.min, children: children),
      );

  Widget _btn(IconData icon, VoidCallback onTap, {Color color = Colors.white, String? tip}) => VPress(
        onTap: onTap,
        tooltip: tip,
        child: SizedBox(width: 36, height: 32, child: Icon(icon, size: 19, color: color)),
      );

  @override
  Widget build(BuildContext context) {
    final c = _c;
    final v = c?.value;
    final ready = v != null && v.isInitialized;
    final ar = ready && v.aspectRatio > 0 ? v.aspectRatio : 16 / 9;
    final d = ready ? v.duration.inMilliseconds : 0;
    final f = d == 0 ? 0.0 : (v!.position.inMilliseconds / d).clamp(0.0, 1.0);
    return GestureDetector(
      onTap: () {}, // taps on the viewer stay in it
      child: Padding(
        padding: const EdgeInsets.fromLTRB(VSpace.md, VSpace.sm, VSpace.md, VSpace.md),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Flexible(
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: ar,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(VRadius.md),
                        child: ready ? VideoPlayer(c!) : _Poster(url: widget.theme.assetPath),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: VSpace.sm),
                Row(
                  children: [
                    _pill([
                      _btn(ready && v.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, () {
                        if (!ready) return;
                        v.isPlaying ? c!.pause() : c!.play();
                      }),
                      _btn(_muted ? Icons.volume_off_rounded : Icons.volume_up_rounded, () {
                        setState(() => _muted = !_muted);
                        c?.setVolume(_muted ? 0 : 1);
                      }),
                    ]),
                    const Spacer(),
                    _pill([
                      _btn(widget.saved ? Icons.favorite_rounded : Icons.favorite_border_rounded, widget.onSave,
                          color: widget.saved ? const Color(0xFFE5484D) : Colors.white),
                      _btn(Icons.download_rounded, widget.onDownload),
                      _btn(Icons.ios_share_rounded, widget.onShare),
                    ]),
                  ],
                ),
                const SizedBox(height: VSpace.xs),
                LayoutBuilder(
                  builder: (_, box) => GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (e) => _seek(e.localPosition.dx, box.maxWidth),
                    onHorizontalDragUpdate: (e) => _seek(e.localPosition.dx, box.maxWidth),
                    child: SizedBox(
                      height: 16,
                      child: Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(VRadius.full),
                          child: LinearProgressIndicator(value: f, minHeight: 3, backgroundColor: VColors.fillCell, valueColor: const AlwaysStoppedAnimation(Colors.white)),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: VSpace.xs),
                VGlass(
                  material: VMaterial.elevated,
                  radius: VRadius.lg,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Text(widget.theme.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: VType.callout(color: Colors.white, weight: FontWeight.w500)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
