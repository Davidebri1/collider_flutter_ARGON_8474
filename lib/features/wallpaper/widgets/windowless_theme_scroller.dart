import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../core/figma/figma_stage.dart';
import '../../../core/vision/vision_kit.dart';
import '../../../models/theme_def.dart';
import '../../theme/theme_living_media.dart';
import '../../theme/theme_pack_store.dart';

/// REQ-06 Theme Gallery (map row 6, Vision Pro Spatial UI Kit 69-1926): the
/// previewed wallpaper in a rounded window over the blurred room, a
/// thumbnail strip under it whose selected frame widens.
/// v8.4 W4: the whole screen is laid out in real pixels - the scaled frame
/// shipped ~7-20px controls and ~9px text, below every touch/legibility
/// minimum. Live wallpapers loop silently: the play/scrub/volume row is gone
/// (no progress UI anywhere here), and strip tiles show their poster in full,
/// never centre-cropped. Bottom chrome stays: dot = close, bar = swipe down.
class WindowlessThemeScroller extends StatefulWidget {
  final WallpaperTheme currentTheme;

  /// External query from the module rail's search actuator (map W6).
  final String searchQuery;
  final ValueChanged<WallpaperTheme> onLivePreview;
  final ValueChanged<WallpaperTheme> onConfirmTheme;
  final VoidCallback onCancel;
  final VoidCallback onUpgradeTier;

  const WindowlessThemeScroller({
    super.key,
    required this.currentTheme,
    this.searchQuery = '',
    required this.onLivePreview,
    required this.onConfirmTheme,
    required this.onCancel,
    required this.onUpgradeTier,
  });

  @override
  State<WindowlessThemeScroller> createState() => _WindowlessThemeScrollerState();
}

/// Which shelf the gallery is showing. Free themes apply directly; premium
/// packs only appear here once the store says they are yours.
enum ThemeShelf { free, premium }

class _WindowlessThemeScrollerState extends State<WindowlessThemeScroller> {
  late WallpaperTheme _previewed;
  bool _expanded = false;
  ThemeShelf _shelf = ThemeShelf.free;

  // Strip geometry (real px, W4): selected >= 96 tall, neighbours >= 64,
  // 12px gaps, tiles at the poster's own 16:9 so no tile centre-crops.
  static const double _tileH = 96;
  static const double _tileHNb = 64;
  static const double _tileGap = 12;
  static const double _tileAspect = 16 / 9;

  // The window keeps the frame's 725 x 730 proportions at real px; the cap
  // keeps it from blowing up on wide desktop windows.
  static const double _winAspect = 725 / 730;
  static const double _winMaxW = 560;

  @override
  void initState() {
    super.initState();
    _previewed = widget.currentTheme;
    // Open on the shelf that actually holds the current wallpaper, so the
    // strip never starts on an empty list.
    _shelf = _premiumShelf.any((x) => x.id == widget.currentTheme.id)
        ? ThemeShelf.premium
        : ThemeShelf.free;
    ThemePackStore.instance.init();
  }

  @override
  void didUpdateWidget(covariant WindowlessThemeScroller old) {
    super.didUpdateWidget(old);
    // Rail search (map W6) refilters the shelves.
    if (old.searchQuery != widget.searchQuery) {
      setState(() {
        if (!_premiumShelf.any((x) => x.id == _previewed.id) &&
            !_freeShelf.any((x) => x.id == _previewed.id) &&
            _shelf == ThemeShelf.premium &&
            _premiumShelf.isNotEmpty) {
          _previewed = _premiumShelf.first;
        }
      });
    }
  }

  List<WallpaperTheme> get _freeShelf => _filtered(WallpaperCatalog.freeThemes);

  /// Every premium pack is browsable here. Ownership is the market's call,
  /// not the gallery's: hiding the packs until the store is open left this
  /// shelf empty and the strip with nothing to show.
  List<WallpaperTheme> get _premiumShelf => _filtered(WallpaperCatalog.premiumThemes);

  /// Rail search filter (map W6): name contains the query.
  List<WallpaperTheme> _filtered(List<WallpaperTheme> list) {
    final q = widget.searchQuery.trim().toLowerCase();
    if (q.isEmpty) return list;
    return list.where((t) => t.name.toLowerCase().contains(q)).toList();
  }

  /// Browsing never touches the applied wallpaper. The preview moves inside
  /// the gallery; the room behind it and the app's own background stay on the
  /// wallpaper that is actually set until Set Wallpaper is pressed.
  void _select(WallpaperTheme t) {
    if (t.id == _previewed.id) return;
    setState(() => _previewed = t);
  }

  void _setShelf(ThemeShelf s) {
    if (_shelf == s) return;
    final list = s == ThemeShelf.free ? _freeShelf : _premiumShelf;
    setState(() {
      _shelf = s;
      // Keep the selection inside the shelf the user just switched to.
      if (!list.any((x) => x.id == _previewed.id)) {
        if (list.isNotEmpty) _previewed = list.first;
      }
    });
  }

  List<WallpaperTheme> get _themes => _shelf == ThemeShelf.free ? _freeShelf : _premiumShelf;

  /// Real-pixel gallery (W4): window, shelf pills, strip and window bar laid
  /// out in logical px, replacing the scaled stage whose controls were
  /// ~7-20px and whose text fell under 13px.
  Widget _gallery(List<WallpaperTheme> themes, EdgeInsets pad) {
    return Padding(
      // Reserve the module rail's strip so the window never sits under it.
      padding: const EdgeInsets.only(left: 72),
      child: Column(
        children: [
          SizedBox(height: pad.top + 12),
        Expanded(
          child: Center(
            child: LayoutBuilder(builder: (context, bc) {
              final winW =
                  math.max(120.0, math.min(math.min(bc.maxWidth - 32, bc.maxHeight * _winAspect), _winMaxW));
              return SizedBox(
                width: winW,
                height: winW / _winAspect,
                child: _PreviewWindow(
                  key: ValueKey('win-${_previewed.id}'),
                  theme: _previewed,
                  onBack: widget.onCancel,
                  onExpand: () => setState(() => _expanded = true),
                  onSet: () => widget.onConfirmTheme(_previewed),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 14),
        _ShelfSelector(
          shelf: _shelf,
          freeCount: _freeShelf.length,
          premiumCount: _premiumShelf.length,
          onChanged: _setShelf,
        ),
        const SizedBox(height: 12),
        _stripBox(themes),
        const SizedBox(height: 4),
        _windowBar(),
        SizedBox(height: math.max(12.0, pad.bottom)),
        ],
      ),
    );
  }

  /// Real-pixel strip (W4): selected tile centred and widened, neighbours at
  /// 16:9 around it, drag flips themes, the mask fades the strip's ends.
  Widget _stripBox(List<WallpaperTheme> themes) {
    if (themes.isEmpty) return const SizedBox(height: _tileH);
    // A preview that is not on this shelf (the shelf just switched, or the
    // catalog changed under us) must still draw a strip: fall back to the
    // head of the list instead of rendering nothing at all.
    var sel = themes.indexWhere((t) => t.id == _previewed.id);
    if (sel < 0) sel = 0;
    return SizedBox(
      height: _tileH,
      child: EdgeFadeHorizontal(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragEnd: (d) {
            final v = d.primaryVelocity ?? 0;
            if (v.abs() < 100) return;
            final j = (sel + (v < 0 ? 1 : -1)).clamp(0, themes.length - 1);
            _select(themes[j]);
          },
          child: LayoutBuilder(builder: (context, bc) {
            const selW = _tileH * _tileAspect;
            const nbW = _tileHNb * _tileAspect;
            final selLeft = bc.maxWidth / 2 - selW / 2;
            return Stack(
              children: [
                for (var k = -6; k <= 6; k++)
                  if (sel + k >= 0 && sel + k < themes.length)
                    _stripTile(themes, sel, k, selLeft: selLeft, selW: selW, nbW: nbW),
              ],
            );
          }),
        ),
      ),
    );
  }

  AnimatedPositioned _stripTile(
    List<WallpaperTheme> themes,
    int sel,
    int k, {
    required double selLeft,
    required double selW,
    required double nbW,
  }) {
    final i = sel + k;
    final selected = k == 0;
    final h = selected ? _tileH : _tileHNb;
    final w = selected ? selW : nbW;
    final left = selected
        ? selLeft
        : k < 0
            ? selLeft - (-k) * (_tileGap + nbW)
            : selLeft + selW + _tileGap + (k - 1) * (_tileGap + nbW);
    return AnimatedPositioned(
      key: ValueKey(themes[i].id),
      duration: VMotion.base,
      curve: Curves.easeOutCubic,
      left: left,
      top: (_tileH - h) / 2,
      width: w,
      height: h,
      child: _tile(themes[i], selected: selected, distance: k.abs()),
    );
  }

  Widget _tile(WallpaperTheme t, {required bool selected, required int distance}) {
    // Depth fade toward the ends; the mask fades the strip's screen edges.
    final fade = distance <= 3 ? 1.0 : (distance == 4 ? 0.7 : 0.45);
    return Semantics(
      button: true,
      selected: selected,
      label: t.name,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _select(t),
        child: Opacity(
          opacity: fade,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Backing so a theme whose poster is still loading, or
                // missing, still reads as a tile instead of a hole.
                const ColoredBox(color: Color(0x33FFFFFF)),
                // Contain, never cover: the poster shows in full (W4); the
                // 16:9 tile matches the poster aspect, so it fills edge to edge.
                ThemePosterImage(theme: t, fit: BoxFit.contain, filterQuality: FilterQuality.medium),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// visionOS window bar at real px: the dot closes on tap, the grabber on a
  /// swipe down; both keep a 44px hit target.
  Widget _windowBar() {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Semantics(
        button: true,
        label: 'Close',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onCancel,
          child: const SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: SizedBox(
                width: 12,
                height: 12,
                child: DecoratedBox(decoration: BoxDecoration(shape: BoxShape.circle, color: Color(0x99FFFFFF))),
              ),
            ),
          ),
        ),
      ),
      GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragEnd: (d) {
          if ((d.primaryVelocity ?? 0) > 200) widget.onCancel();
        },
        child: SizedBox(
          width: 120,
          height: 44,
          child: Center(
            child: Container(
              width: 120,
              height: 5,
              decoration: BoxDecoration(color: const Color(0x99FFFFFF), borderRadius: BorderRadius.circular(2.5)),
            ),
          ),
        ),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.of(context).padding;
    return ListenableBuilder(
      listenable: ThemePackStore.instance,
      builder: (context, _) {
        final themes = _themes;
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onVerticalDragEnd: (d) {
            if ((d.primaryVelocity ?? 0) < -300) widget.onUpgradeTier();
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              // The room, blurred (the environment behind the window). It
              // tracks the wallpaper that is actually applied, not the theme
              // being browsed: looking around must not repaint the room.
              Positioned.fill(
                child: AnimatedSwitcher(
                  duration: VMotion.base,
                  child: KeyedSubtree(
                    key: ValueKey('room-${widget.currentTheme.id}-$_expanded'),
                    child: _expanded
                        ? GestureDetector(
                            onTap: () => setState(() => _expanded = false),
                            child: ThemePosterImage(theme: widget.currentTheme, fit: BoxFit.cover, fullBleed: true),
                          )
                        : ImageFiltered(
                            imageFilter: ImageFilter.blur(sigmaX: 28, sigmaY: 28, tileMode: TileMode.clamp),
                            child: ColorFiltered(
                              colorFilter: const ColorFilter.mode(Color(0x55000000), BlendMode.darken),
                              child: ThemePosterImage(theme: widget.currentTheme, fit: BoxFit.cover, fullBleed: true),
                            ),
                          ),
                  ),
                ),
              ),
              if (_expanded && _previewed.isLive)
                Positioned.fill(child: IgnorePointer(child: _LoopVideo(key: ValueKey('full-${_previewed.id}'), url: _previewed.videoUrl!))),
              if (_expanded)
                Positioned(
                  left: VSpace.md,
                  top: pad.top + VSpace.sm,
                  child: VCircleButton(icon: Icons.fullscreen_exit_rounded, floating: true, size: 44, tooltip: 'Back', onTap: () => setState(() => _expanded = false)),
                ),
              if (!_expanded) Positioned.fill(child: _gallery(themes, pad)),
            ],
          ),
        );
      },
    );
  }
}

/// The shelf switch: Free Themes and Premium Themes pills side by side.
/// v8.4 W4: real px (the scaled one rendered its labels at ~6px); the shelf
/// you are not looking at recedes instead of disappearing.
class _ShelfSelector extends StatelessWidget {
  final ThemeShelf shelf;
  final int freeCount;
  final int premiumCount;
  final ValueChanged<ThemeShelf> onChanged;

  const _ShelfSelector({
    required this.shelf,
    required this.freeCount,
    required this.premiumCount,
    required this.onChanged,
  });

  Widget _pill(ThemeShelf s, String label, int count) {
    final active = shelf == s;
    return Semantics(
      button: true,
      selected: active,
      label: '$label, $count themes',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(s),
        child: AnimatedOpacity(
          duration: VMotion.base,
          curve: Curves.easeOutCubic,
          opacity: active ? 1.0 : 0.55,
          child: AnimatedContainer(
            duration: VMotion.base,
            curve: Curves.easeOutCubic,
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(VRadius.full),
              color: active ? const Color(0x4DFFFFFF) : const Color(0x26FFFFFF),
              border: Border.all(
                color: active ? const Color(0x66FFFFFF) : const Color(0x1FFFFFFF),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FText(label, size: 14, height: 18, weight: active ? FontWeight.w700 : FontWeight.w500),
                const SizedBox(width: 8),
                FText('$count', size: 13, height: 18, weight: FontWeight.w600, opacity: active ? 0.72 : 0.5),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      _pill(ThemeShelf.free, 'Free Themes', freeCount),
      const SizedBox(width: 10),
      _pill(ThemeShelf.premium, 'Premium Themes', premiumCount),
    ]);
  }
}

/// The rounded preview window: wallpaper, 44px chrome (back / Expand View /
/// Set Wallpaper) and the theme name. Live themes loop silently behind the
/// poster - W4 removed the play/scrub/volume row; a looping wallpaper needs
/// no controls and no progress indicator.
class _PreviewWindow extends StatefulWidget {
  final WallpaperTheme theme;
  final VoidCallback onBack;
  final VoidCallback onExpand;
  final VoidCallback onSet;
  const _PreviewWindow({super.key, required this.theme, required this.onBack, required this.onExpand, required this.onSet});

  @override
  State<_PreviewWindow> createState() => _PreviewWindowState();
}

class _PreviewWindowState extends State<_PreviewWindow> {
  VideoPlayerController? _c;

  @override
  void initState() {
    super.initState();
    final url = widget.theme.videoUrl;
    if (widget.theme.isLive && url != null) {
      final c = VideoPlayerController.networkUrl(Uri.parse(url), videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true));
      _c = c;
      // Loops silently (W4); with no player row there is no per-frame listener.
      c.setLooping(true);
      c.setVolume(0);
      c.initialize().then((_) {
        if (!mounted) return;
        c.play();
        setState(() {});
      }).catchError((_) {});
    }
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  Widget _chromeCircle(IconData icon, String label, VoidCallback onTap) => Semantics(
        button: true,
        label: label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: FGlass(
            width: 44,
            height: 44,
            radius: BorderRadius.circular(22),
            fill: const Color(0x4D808080),
            blur: 50,
            child: Icon(icon, size: 22, color: Colors.white),
          ),
        ),
      );

  // The capsule itself is 40 tall inside a 44px hit box (W4 touch minimum).
  Widget _expandCapsule() => Semantics(
        button: true,
        label: 'Expand View',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onExpand,
          child: Container(
            height: 44,
            alignment: Alignment.center,
            child: FGlass(
              radius: BorderRadius.circular(20),
              fill: const Color(0x4D808080),
              blur: 50,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.open_in_full_rounded, size: 18, color: Colors.white),
                SizedBox(width: 8),
                FText('Expand View', size: 14, height: 18, weight: FontWeight.w600),
              ]),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    final c = _c;
    final ready = c != null && c.value.isInitialized;
    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), boxShadow: VShadow.heavy),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ThemePosterImage(theme: t, fit: BoxFit.cover, fullBleed: true),
            if (ready)
              FittedBox(
                fit: BoxFit.cover,
                clipBehavior: Clip.hardEdge,
                child: SizedBox(width: c.value.size.width, height: c.value.size.height, child: VideoPlayer(c)),
              ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x26000000), Color(0x00000000), Color(0x00000000), Color(0x80000000)],
                  stops: [0, 0.2, 0.65, 1],
                ),
              ),
            ),
            // Chrome at real px (W4): back / Expand View / Set Wallpaper, all
            // on a 44px hit target, text >= 13.
            Positioned(
              left: 12,
              right: 12,
              top: 12,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _chromeCircle(Icons.chevron_left_rounded, 'Back', widget.onBack),
                  _expandCapsule(),
                  _chromeCircle(Icons.check_rounded, 'Set Wallpaper', widget.onSet),
                ],
              ),
            ),
            // Name only (W4 text scrub): no sentences, no metadata line.
            Positioned(
              left: 20,
              right: 20,
              bottom: 16,
              child: FText(t.name, size: 18, height: 24, weight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

/// A silent looping wallpaper (Expand View of a live theme).
class _LoopVideo extends StatefulWidget {
  final String url;
  const _LoopVideo({super.key, required this.url});
  @override
  State<_LoopVideo> createState() => _LoopVideoState();
}

class _LoopVideoState extends State<_LoopVideo> {
  late final VideoPlayerController _c = VideoPlayerController.networkUrl(Uri.parse(widget.url), videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true));

  @override
  void initState() {
    super.initState();
    _c.setLooping(true);
    _c.setVolume(0);
    _c.initialize().then((_) {
      if (!mounted) return;
      _c.play();
      setState(() {});
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_c.value.isInitialized) return const SizedBox.shrink();
    return FittedBox(
      fit: BoxFit.cover,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(width: _c.value.size.width, height: _c.value.size.height, child: VideoPlayer(_c)),
    );
  }
}

/// Horizontal edge fade for thumbnail strips.
class EdgeFadeHorizontal extends StatelessWidget {
  final Widget child;
  const EdgeFadeHorizontal({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (r) {
        final f = (16 / (r.width <= 0 ? 1 : r.width)).clamp(0.0, 0.3);
        return LinearGradient(
          colors: const [Color(0x00FFFFFF), Colors.white, Colors.white, Color(0x00FFFFFF)],
          stops: [0, f, 1 - f, 1],
        ).createShader(r);
      },
      child: child,
    );
  }
}
