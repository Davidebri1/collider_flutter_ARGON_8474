import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api/collider_api.dart';
import '../../../core/media/theme_cloud.dart';
import '../../../core/vision/vision_kit.dart';
import '../../../models/theme_def.dart';
import '../../media/generations_pane.dart' show BreathingTile;
import '../../media/picture_viewer.dart';

/// Discover Market. Rebuilt by Claude (2026-10-21) to David's direction of 21 Oct: "Discover market is just images for
/// now. But Unsplash has shown that can be displayed well"; it "needs to match grok imagine market in terms of color
/// sharpness, layout, design, features, but also needs to extract the cinematic effect. Through dimming the background";
/// and remix goes to the media chat, as Grok's does ("Grok merely transfers you to the chat window when you hit remix
/// ... it's the same chat window and agent and you type in a prompt. We should be the same").
/// References (Mobbin, iOS): Grok's Imagine feed (pictures edge to edge on black, hairline gaps, the box to type in
/// floating at the foot) and its picture view; Unsplash's feed (each picture at its own shape, never cropped).
///  - the room behind dims to nearly black; the window is black, the pictures the only light in it;
///  - two columns on a phone, more on wider screens, each picture at its own shape (Unsplash), 2-point gaps (Grok);
///  - the pictures: what the picture models made here (newest first), then the live wallpapers' pictures;
///  - a picture opens large (PictureViewer): keep it in My Gallery, Files, share, remix;
///  - the box at the foot sends its words to the media chat, which makes the pictures (one place for making).
class MarketScreen extends StatefulWidget {
  final VoidCallback onClose;
  final String view; // 'discover' or 'gallery'
  final ValueChanged<String> onImagine; // words for the media chat
  final ValueChanged<String> onRemix; // a picture's place in Files, as the media chat's reference

  const MarketScreen({super.key, required this.onClose, required this.onImagine, required this.onRemix, this.view = 'discover'});

  @override
  State<MarketScreen> createState() => _MarketScreenState();
}

class _Item {
  final String id;
  final String url;
  final double aspect;
  final String? fileRef;
  final WallpaperTheme? theme;
  const _Item({required this.id, required this.url, required this.aspect, this.fileRef, this.theme});
}

class _MarketScreenState extends State<MarketScreen> {
  static const _savedKey = 'market_saved_v1';
  static final Set<String> _savedCache = {};
  static bool _savedLoaded = false;
  final Set<String> _saved = {..._savedCache};
  List<Creation> _made = const [];
  Timer? _poll;
  final _text = TextEditingController();

  @override
  void initState() {
    super.initState();
    ThemeCloud.instance.addListener(_changed);
    ThemeCloud.instance.init();
    _refresh();
    if (!_savedLoaded) {
      SharedPreferences.getInstance().then((p) {
        _savedCache
          ..clear()
          ..addAll(p.getStringList(_savedKey) ?? const []);
        _savedLoaded = true;
        if (mounted) {
          setState(() => _saved
            ..clear()
            ..addAll(_savedCache));
        }
      });
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    _text.dispose();
    ThemeCloud.instance.removeListener(_changed);
    super.dispose();
  }

  void _changed() => mounted ? setState(() {}) : null;

  Future<void> _refresh() async {
    final list = await ColliderApi.instance.creations();
    if (!mounted) return;
    setState(() => _made = list);
    _poll?.cancel();
    if (list.any((c) => c.making)) _poll = Timer(const Duration(seconds: 3), _refresh);
  }

  List<_Item> get _items {
    final api = ColliderApi.instance;
    final out = <_Item>[
      for (final c in _made)
        if (c.kind == 'image' && c.status == 'done')
          for (final m in c.media)
            if (m['kind'] != 'video')
              _Item(
                id: 'c:${m['name']}',
                url: api.fileUrl(ColliderFile('${m['name']}', 'generated', 0, DateTime.now(), 'image', '${m['url']}')),
                aspect: (m['width'] is num && m['height'] is num && (m['height'] as num) > 0) ? (m['width'] as num) / (m['height'] as num) : 9 / 16,
                fileRef: 'generated/${m['name']}',
              ),
      // the wallpapers' pictures are 1168 x 1728 (measured 2026-10-21)
      for (final t in ThemeCloud.instance.themes) _Item(id: t.id, url: t.assetPath, aspect: 1168 / 1728, theme: t),
    ];
    return widget.view == 'gallery' ? [for (final i in out) if (_saved.contains(i.id)) i] : out;
  }

  Future<void> _save(ViewedPicture p) async {
    setState(() {
      if (_saved.contains(p.id)) {
        _saved.remove(p.id);
        _savedCache.remove(p.id);
      } else {
        _saved.add(p.id);
        _savedCache.add(p.id);
      }
    });
    (await SharedPreferences.getInstance()).setStringList(_savedKey, _saved.toList()..sort());
  }

  /// A wallpaper's picture is not in Files yet: it is saved there first (Files > Downloaded), so it can be a reference.
  Future<String?> _ref(ViewedPicture p) async {
    if (p.fileRef != null) return p.fileRef;
    final name = await ColliderApi.instance.download(p.url);
    return name == null ? null : 'downloaded/$name';
  }

  void _open(List<_Item> items, int i) {
    final pics = [
      for (final it in items)
        ViewedPicture(
          id: it.id,
          url: it.url,
          aspect: it.aspect,
          fileRef: it.fileRef,
          builder: it.theme == null ? null : (fit) => Image(image: _poster(it.theme!.assetPath), fit: fit, filterQuality: FilterQuality.high, gaplessPlayback: true),
        ),
    ];
    showGeneralDialog(
      context: context,
      barrierColor: Colors.transparent,
      pageBuilder: (ctx, _, __) => PictureViewer(
        pictures: pics,
        start: i,
        saved: _saved,
        onSave: _save,
        onFiles: (p) async {
          if (p.fileRef == null) await ColliderApi.instance.download(p.url);
        },
        onRemix: (p) async {
          final ref = await _ref(p);
          if (ref == null) return;
          if (ctx.mounted) Navigator.of(ctx).pop();
          widget.onRemix(ref);
        },
        onClose: () => Navigator.of(ctx).pop(),
      ),
    );
  }

  void _send() {
    final t = _text.text.trim();
    if (t.isEmpty) return;
    _text.clear();
    widget.onImagine(t);
  }

  /// A wallpaper's picture: from the theme server, or packed in the app.
  static ImageProvider _poster(String path) => path.startsWith('http') ? NetworkImage(path) as ImageProvider : AssetImage(path);

  /// Unsplash's feed: each picture at its own shape, laid into the shortest column.
  Widget _feed(List<_Item> items, double width) {
    final cols = width >= 1000 ? 4 : (width >= 600 ? 3 : 2);
    const gap = 2.0;
    final colW = (width - gap * (cols - 1)) / cols;
    final px = (colW * MediaQuery.devicePixelRatioOf(context)).round();
    final heights = List<double>.filled(cols, 0);
    final columns = List.generate(cols, (_) => <Widget>[]);
    for (int i = 0; i < items.length; i++) {
      final it = items[i];
      int c = 0;
      for (int k = 1; k < cols; k++) {
        if (heights[k] < heights[c]) c = k;
      }
      final h = colW / it.aspect;
      heights[c] += h + gap;
      final index = i;
      columns[c].add(Padding(
        padding: const EdgeInsets.only(bottom: gap),
        child: VPress(
          onTap: () => _open(items, index),
          child: SizedBox(
            width: colW,
            height: h,
            // Each tile is decoded at the size it is shown (no blur work, no full-size textures), so a phone's browser
            // keeps the whole feed in memory. (Claude, 2026-10-21)
            child: it.theme != null
                ? Image(
                    image: ResizeImage(_poster(it.theme!.assetPath), width: px, policy: ResizeImagePolicy.fit),
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.medium,
                    gaplessPlayback: true,
                    frameBuilder: (_, child, frame, sync) => frame == null && !sync ? const BreathingTile() : child,
                    errorBuilder: (_, __, ___) => const ColoredBox(color: Color(0xFF0B0B0D)))
                : Image.network(it.url, fit: BoxFit.cover, filterQuality: FilterQuality.medium, gaplessPlayback: true, cacheWidth: px,
                    frameBuilder: (_, child, frame, sync) => frame == null && !sync ? const BreathingTile() : child,
                    errorBuilder: (_, __, ___) => const ColoredBox(color: Color(0xFF0B0B0D))),
          ),
        ),
      ));
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int c = 0; c < cols; c++) ...[if (c > 0) const SizedBox(width: gap), SizedBox(width: colW, child: Column(children: columns[c]))],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final phone = size.width < 768;
    final items = _items;
    return Stack(children: [
      // The room dims to nearly black: the cinema goes dark around the screen.
      Positioned.fill(
        child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: widget.onClose, child: const ColoredBox(color: Color(0xE6000000))),
      ),
      SafeArea(
        bottom: false,
        child: Padding(
          // on a phone the pictures run edge to edge, as Grok's feed; the side rail (Discover, My Gallery) floats over them
          // (Claude, 2026-10-21)
          padding: EdgeInsets.fromLTRB(0, phone ? 0 : 8, 0, phone ? 0 : 8),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: ClipRRect(
                borderRadius: phone
                    ? const BorderRadius.vertical(bottom: Radius.circular(VRadius.xl))
                    : BorderRadius.circular(VRadius.xl),
                child: ColoredBox(
                  color: Colors.black,
                  child: LayoutBuilder(builder: (context, box) {
                    return Stack(children: [
                      Positioned.fill(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          // on a phone the pictures start under the head, which floats over them (Grok)
                          padding: EdgeInsets.only(top: phone ? 0 : 60, bottom: 96),
                          child: _feed(items, box.maxWidth),
                        ),
                      ),
                      // the head: fades from black so the feed passes under it
                      Positioned(
                        left: 0,
                        right: 0,
                        top: 0,
                        height: 72,
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Colors.black.withValues(alpha: 0.85), Colors.black.withValues(alpha: 0.4), Colors.transparent],
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 10,
                        top: 8,
                        right: 10,
                        child: Row(children: [
                          VCircleButton(icon: Icons.close_rounded, tooltip: 'Close', floating: true, onTap: widget.onClose),
                          const SizedBox(width: 10),
                          Text('Discover Market', style: VType.headline(color: Colors.white)),
                        ]),
                      ),
                      // the foot: the box to type in, floating over the feed, which fades out beneath it
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        height: 110,
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [Colors.black.withValues(alpha: 0.9), Colors.black.withValues(alpha: 0.5), Colors.transparent],
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: phone ? 76 : 10, // clear of the side rail's foot on a phone
                        right: 10,
                        bottom: 12,
                        child: VGlass(
                          material: VMaterial.elevated,
                          radius: 28,
                          padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
                          child: Row(children: [
                            Expanded(
                              child: TextField(
                                controller: _text,
                                minLines: 1,
                                maxLines: 4,
                                cursorColor: VColors.textPrimary,
                                textInputAction: TextInputAction.send,
                                onSubmitted: (_) => _send(),
                                style: VType.callout(weight: FontWeight.w500),
                                decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 13)),
                              ),
                            ),
                            const SizedBox(width: 6),
                            VCircleButton(icon: Icons.arrow_upward_rounded, size: 44, selected: true, onTap: _send),
                          ]),
                        ),
                      ),
                    ]);
                  }),
                ),
              ),
            ),
          ),
        ),
      ),
    ]);
  }
}
