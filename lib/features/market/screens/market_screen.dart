import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api/collider_api.dart';
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
/// What it shows: David's live wallpapers from his Cloudflare bucket (ThemeCloud), and (Claude, 2026-10-20) what is
/// made here through fal: the bar at the foot of the pane makes pictures or a video from words, as Imagine does.
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
  List<Creation> _made = const [];
  Timer? _poll;
  (Creation, Map<String, dynamic>)? _picture; // a picture opened large
  Map<String, dynamic>? _film; // a made video opened

  @override
  void initState() {
    super.initState();
    ThemeCloud.instance.addListener(_changed);
    ThemeCloud.instance.init();
    ThemePackStore.instance.init();
    _refresh();
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
    _poll?.cancel();
    ThemeCloud.instance.removeListener(_changed);
    super.dispose();
  }

  void _changed() => mounted ? setState(() {}) : null;

  /// What has been made; while anything is still being made, asked again every two seconds.
  Future<void> _refresh() async {
    final list = await ColliderApi.instance.creations();
    if (!mounted) return;
    setState(() => _made = list);
    _poll?.cancel();
    if (list.any((c) => c.making)) _poll = Timer(const Duration(seconds: 2), _refresh);
  }

  Future<void> _make(String text, bool video) async {
    await ColliderApi.instance.make(text, video ? 'video' : 'image');
    await _refresh();
  }

  Future<void> _motion(Creation c) async {
    setState(() => _picture = null);
    await ColliderApi.instance.make(c.text, 'motion', from: c.id);
    await _refresh();
  }

  List<WallpaperTheme> get _items {
    final all = [for (final t in ThemeCloud.instance.themes) if (t.videoPath != null) t];
    return widget.view == 'gallery' ? [for (final t in all) if (_saved.contains(t.id)) t] : all;
  }

  /// One tile per picture or video made; while making, the tiles it will fill.
  List<(Creation, Map<String, dynamic>?)> get _madeTiles {
    final out = <(Creation, Map<String, dynamic>?)>[];
    for (final c in _made) {
      if (widget.view == 'gallery' && !c.media.any((m) => _saved.contains('c:${m['name']}'))) continue;
      if (c.media.isEmpty) {
        for (var i = 0; i < (c.kind == 'image' && c.making ? 4 : 1); i++) {
          out.add((c, null));
        }
      } else {
        for (final m in c.media) {
          if (widget.view != 'gallery' || _saved.contains('c:${m['name']}')) out.add((c, m));
        }
      }
    }
    return out;
  }

  Future<void> _toggleSaveId(String id) async {
    setState(() {
      if (_saved.contains(id)) {
        _saved.remove(id);
        _savedCache.remove(id);
      } else {
        _saved.add(id);
        _savedCache.add(id);
      }
    });
    (await SharedPreferences.getInstance()).setStringList(_savedKey, _saved.toList()..sort());
  }

  Future<void> _toggleSave(WallpaperTheme t) => _toggleSaveId(t.id);

  @override
  void didUpdateWidget(MarketScreen old) {
    super.didUpdateWidget(old);
    if (old.view != widget.view) _open = null;
  }

  void _tapMade(Creation c, Map<String, dynamic>? m) {
    if (c.status == 'failed') {
      ColliderApi.instance.make(c.text, c.kind, from: c.from, replace: c.id).then((_) => _refresh());
      return;
    }
    if (m == null) return;
    setState(() => m['kind'] == 'video' ? _film = m : _picture = (c, m));
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final made = _madeTiles;
    return Stack(
      children: [
        VWorkSurface(
          title: 'Discover Market',
          onClose: widget.onClose,
          child: Stack(children: [
            Positioned.fill(child: _grid(made, items)),
            Positioned(left: VSpace.md, right: VSpace.md, bottom: VSpace.md, child: _MakeBar(onMake: _make)),
          ]),
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
        if (_picture != null)
          Positioned.fill(
            child: _PictureWindow(
              c: _picture!.$1,
              m: _picture!.$2,
              saved: _saved.contains('c:${_picture!.$2['name']}'),
              onClose: () => setState(() => _picture = null),
              onMotion: () => _motion(_picture!.$1),
              onSave: () => _toggleSaveId('c:${_picture!.$2['name']}'),
            ),
          ),
        if (_film != null)
          Positioned.fill(
            child: Stack(children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _film = null),
                child: const ColoredBox(color: Color(0xCC06080E), child: SizedBox.expand()),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(VSpace.md, VSpace.lg, VSpace.md, VSpace.md),
                child: VideoWindow(
                  key: ValueKey(_film!['name']),
                  url: ColliderApi.instance.fileUrl(ColliderFile('${_film!['name']}', 'generated', 0, DateTime.now(), 'video', '${_film!['url']}')),
                  onClose: () => setState(() => _film = null),
                ),
              ),
            ]),
          ),
      ],
    );
  }

  Widget _grid(List<(Creation, Map<String, dynamic>?)> made, List<WallpaperTheme> items) {
    if (items.isEmpty && made.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(builder: (context, c) {
      final cols = (c.maxWidth / 200).floor().clamp(2, 5);
      return ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(VRadius.xl)),
        child: EdgeFade(
          focus: FadeFocus.top,
          child: GridView.builder(
            // room at the foot for the bar, so the last row can be scrolled clear of it
            padding: const EdgeInsets.fromLTRB(2, 0, 2, 96),
            physics: const BouncingScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: cols, mainAxisSpacing: 2, crossAxisSpacing: 2, childAspectRatio: 0.78),
            itemCount: made.length + items.length,
            itemBuilder: (_, i) {
              if (i < made.length) {
                final (cr, m) = made[i];
                return VPress(onTap: () => _tapMade(cr, m), child: _CreationTile(cr, m));
              }
              final k = i - made.length;
              return VPress(onTap: () => setState(() => _open = k), child: _Tile(theme: items[k]));
            },
          ),
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

// ======================================================================================================
// Making pictures and videos in Discover Market, as in Grok's Imagine (Claude, 2026-10-20).
// David: "discover market should be wired to Fal ... whatever functionality imagine market has, discover market has."
// The bar at the foot of the pane: picture or video, the words, and the button that makes them. What is made appears
// at the head of the feed while it is being made, then as itself; a picture opens large and can be set in motion.
// No words of Grok's are used, and none on the bar at all.
// ======================================================================================================

/// The bar that makes: a picture or a video, then the words.
class _MakeBar extends StatefulWidget {
  final Future<void> Function(String text, bool video) onMake;
  const _MakeBar({required this.onMake});
  @override
  State<_MakeBar> createState() => _MakeBarState();
}

class _MakeBarState extends State<_MakeBar> {
  final _text = TextEditingController();
  bool _video = false;
  bool _sending = false;

  Future<void> _go() async {
    final t = _text.text.trim();
    if (t.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await widget.onMake(t, _video);
      _text.clear();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return VGlass(
      material: VMaterial.elevated,
      radius: 28,
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
      child: Row(children: [
        VCircleButton(icon: Icons.image_rounded, size: 34, selected: !_video, onTap: () => setState(() => _video = false)),
        VCircleButton(icon: Icons.movie_rounded, size: 34, selected: _video, onTap: () => setState(() => _video = true)),
        const SizedBox(width: 6),
        Expanded(
          child: VRecessed(
            radius: 18,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: TextField(
              controller: _text,
              minLines: 1,
              maxLines: 4,
              cursorColor: VColors.textPrimary,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _go(),
              style: VType.callout(weight: FontWeight.w500),
              decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 13)),
            ),
          ),
        ),
        const SizedBox(width: 6),
        VCircleButton(
          icon: _sending ? Icons.more_horiz_rounded : Icons.arrow_upward_rounded,
          size: 34,
          selected: true,
          onTap: _sending ? null : _go,
        ),
      ]),
    );
  }
}

/// A making in the feed: a soft light breathing while it is made, then the picture or the video's first frame.
class _CreationTile extends StatelessWidget {
  final Creation c;
  final Map<String, dynamic>? m;
  const _CreationTile(this.c, this.m);

  @override
  Widget build(BuildContext context) {
    if (c.making || m == null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: c.status == 'failed'
            ? const ColoredBox(color: Color(0x22FFFFFF), child: Center(child: Icon(Icons.refresh_rounded, color: Colors.white70)))
            : const _Breathing(),
      );
    }
    final api = ColliderApi.instance;
    final file = ColliderFile('${m!['name']}', 'generated', 0, DateTime.now(), m!['kind'] == 'video' ? 'video' : 'image', '${m!['url']}');
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Stack(fit: StackFit.expand, children: [
        Image.network(m!['kind'] == 'video' ? api.thumbUrl(file) : api.fileUrl(file), fit: BoxFit.cover, filterQuality: FilterQuality.high,
            errorBuilder: (_, __, ___) => const ColoredBox(color: Color(0xFF111318))),
        if (m!['kind'] == 'video')
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
      ]),
    );
  }
}

/// While something is being made: the tile's light rises and falls slowly, as a held breath, nothing flashing.
class _Breathing extends StatefulWidget {
  const _Breathing();
  @override
  State<_Breathing> createState() => _BreathingState();
}

class _BreathingState extends State<_Breathing> with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))..repeat(reverse: true);
  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _a,
        builder: (_, __) {
          final t = Curves.easeInOut.transform(_a.value);
          return DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -0.2),
                radius: 0.9,
                colors: [Colors.white.withValues(alpha: 0.10 + 0.08 * t), Colors.white.withValues(alpha: 0.03)],
              ),
            ),
          );
        },
      );
}

/// A picture opened large: set it in motion, keep it in My Gallery, or copy where it is.
class _PictureWindow extends StatelessWidget {
  final Creation c;
  final Map<String, dynamic> m;
  final bool saved;
  final VoidCallback onClose;
  final VoidCallback onMotion;
  final VoidCallback onSave;
  const _PictureWindow({required this.c, required this.m, required this.saved, required this.onClose, required this.onMotion, required this.onSave});

  @override
  Widget build(BuildContext context) {
    final api = ColliderApi.instance;
    final file = ColliderFile('${m['name']}', 'generated', 0, DateTime.now(), 'image', '${m['url']}');
    return Stack(children: [
      GestureDetector(behavior: HitTestBehavior.opaque, onTap: onClose, child: const ColoredBox(color: Color(0xCC06080E), child: SizedBox.expand())),
      Center(
        child: LayoutBuilder(builder: (context, box) {
          return Column(mainAxisSize: MainAxisSize.min, children: [
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: box.maxWidth * 0.86, maxHeight: box.maxHeight * 0.78),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(VRadius.xl),
                child: Image.network(api.fileUrl(file), fit: BoxFit.contain, filterQuality: FilterQuality.high),
              ),
            ),
            const SizedBox(height: VSpace.sm),
            VGlass(
              material: VMaterial.elevated,
              radius: VRadius.full,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                VCircleButton(icon: Icons.close_rounded, size: 34, onTap: onClose),
                VCircleButton(icon: Icons.movie_rounded, size: 34, onTap: onMotion),
                VCircleButton(icon: saved ? Icons.favorite_rounded : Icons.favorite_border_rounded, size: 34, onTap: onSave),
                VCircleButton(
                  icon: Icons.ios_share_rounded,
                  size: 34,
                  onTap: () => Clipboard.setData(ClipboardData(text: api.fileUrl(file))),
                ),
              ]),
            ),
          ]);
        }),
      ),
    ]);
  }
}
