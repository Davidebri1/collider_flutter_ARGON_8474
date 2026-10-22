import 'dart:math' as math;
import 'dart:ui' show ImageFilter;
import 'package:material_ui/material_ui.dart';
import '../../../models/theme_def.dart';
import '../../../core/audio/music_player.dart';
import '../../../core/media/theme_blur_cache.dart';
import '../../../core/vision/vision_kit.dart';
import '../../theme/theme_living_media.dart';
import '../../theme/theme_pack_store.dart';

/// Theme Gallery, from Vision Pro Spatial UI Kit 69:1926 ("Photos - Memories", a 1920 x 1080 frame).
/// The frame, in its own numbers:
///   picture 731 x 725 at 594,98, radius 25, with a blurred copy of itself behind it as its glow
///   round controls 50 across, 26 below the picture's top; the left one 31 in, the right one 24 in
///   name 700 24/29 at 49 in from the left, 134 above the picture's foot
///   play, progress line and speaker in one row, 49 in from the left, 36 in from the right, 33 above the foot
///   strip of thumbnails 700 x 86, 22 under the picture: the chosen one 86 x 86 in the middle, the others
///   50 x 86, 10 apart; it fades out over its first 258 and its last 169
/// Every one of these is multiplied by one scale, k = picture width / 731, so the relationships hold.
/// Where the app departs from the frame, docs\DEVIATIONS.md says where and why.
class WindowlessThemeScroller extends StatefulWidget {
  final WallpaperTheme currentTheme;
  final ValueChanged<WallpaperTheme> onLivePreview;
  final ValueChanged<WallpaperTheme> onConfirmTheme;
  final VoidCallback onCancel;
  final VoidCallback onUpgradeTier;

  const WindowlessThemeScroller({
    super.key,
    required this.currentTheme,
    required this.onLivePreview,
    required this.onConfirmTheme,
    required this.onCancel,
    required this.onUpgradeTier,
  });

  @override
  State<WindowlessThemeScroller> createState() => _WindowlessThemeScrollerState();
}

class _WindowlessThemeScrollerState extends State<WindowlessThemeScroller> {
  late WallpaperTheme _previewed;
  final ScrollController _strip = ScrollController();
  final _p = MusicPlayer.instance;

  /// How far the gallery has been pulled up toward the live wallpapers: 0 at rest, 1 in focus.
  double _pull = 0;

  // Deviation D3: a thumbnail is 56 tall, not 86 x k (39 on a phone): a finger has to hit it.
  static const _thumbH = 56.0;
  static const _thumbW = _thumbH * 50 / 86;
  static const _gap = 6.0;

  static const _shadow = [Shadow(color: Color(0x99000000), blurRadius: 16)];

  /// The free themes, then the live wallpapers that have been bought
  /// (David, 4 Oct 2026: "the theme gallery can be the place for the 'purchased' section").
  List<WallpaperTheme> get _themes => [
        ...WallpaperCatalog.freeThemes,
        for (final t in WallpaperCatalog.premiumThemes)
          if (ThemePackStore.instance.isUnlocked(t.id)) t,
      ];

  @override
  void initState() {
    super.initState();
    _previewed = widget.currentTheme;
    ThemeBlurCache.instance.prewarmThemes(_themes);
    ThemePackStore.instance.init().then((_) {
      if (mounted) {
        ThemeBlurCache.instance.prewarmThemes(_themes);
        setState(() {});
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final i = _themes.indexWhere((t) => t.id == _previewed.id);
      if (i > 0 && _strip.hasClients) _strip.jumpTo(i * (_thumbW + _gap));
    });
  }

  @override
  void dispose() {
    _strip.dispose();
    super.dispose();
  }

  void _select(WallpaperTheme t) {
    if (t.id == _previewed.id) return;
    ThemeBlurCache.instance.setActiveTheme(t);
    setState(() => _previewed = t);
    widget.onLivePreview(t);
    final i = _themes.indexWhere((x) => x.id == t.id);
    // the chosen thumbnail comes to the middle of the strip, as in the frame
    if (_strip.hasClients) _strip.animateTo(i * (_thumbW + _gap), duration: VMotion.base, curve: Curves.easeOutCubic);
  }

  void _step(int by) {
    final i = _themes.indexWhere((t) => t.id == _previewed.id);
    _select(_themes[(i + by).clamp(0, _themes.length - 1)]);
  }

  /// True while the player is on this theme's own music.
  bool get _mine => _p.queueId == _previewed.id && _p.index != null;

  void _playPause() => _mine ? _p.toggle() : _p.play(0, list: MusicPlayer.forTheme(_previewed), id: _previewed.id);

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    // The frame leaves 98 of its 1080 above the picture: 9.07% of its short side. The same margin is kept
    // on this screen's short side, and the picture is never more of the height than it is in the frame.
    final margin = math.min(size.width, size.height) * 98 / 1080;
    final s = math.min(size.width - 2 * margin, size.height * 725 / 1080).clamp(200.0, 640.0).toDouble();
    final k = s / 731;
    final pictureH = s * 725 / 731;
    final stripW = 700 * k;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onVerticalDragUpdate: (d) => setState(() => _pull = (_pull - d.delta.dy / 150).clamp(0.0, 1.0)),
      onVerticalDragEnd: (d) {
        final go = (d.primaryVelocity ?? 0) < -300 || _pull > 0.55;
        setState(() => _pull = 0);
        if (go) widget.onUpgradeTier();
      },
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // The live wallpapers are one tier up: seen above the gallery, out of focus, fading upward.
            // Pulling up brings them into focus and opens them. (Not in the frame: deviation D5.)
            SizedBox(width: s, child: _LivePeek(pull: _pull, onTap: widget.onUpgradeTier)),
            SizedBox(height: 22 * k),
            SizedBox(width: s, height: pictureH, child: _picture(k)),
            SizedBox(height: 22 * k),
            SizedBox(width: stripW, height: _thumbH, child: _thumbnails(stripW)),
          ],
        ),
      ),
    );
  }

  Widget _picture(double k) {
    final radius = math.max(25 * k, 12.0);
    final image = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: AnimatedSwitcher(
        duration: VMotion.base,
        child: SizedBox.expand(
          key: ValueKey(_previewed.assetPath),
          child: ThemePosterImage(theme: _previewed, filterQuality: FilterQuality.medium),
        ),
      ),
    );
    return GestureDetector(
      onHorizontalDragEnd: (d) {
        final v = d.primaryVelocity ?? 0;
        if (v < -150) _step(1);
        if (v > 150) _step(-1);
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // the picture's own colour, blurred, behind it — pulled from ThemeBlurCache (galleryGlow preset)
          Positioned(
            left: -24 * k,
            right: -24 * k,
            top: -24 * k,
            bottom: -24 * k,
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.85,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(radius + 16),
                  child: CachedThemeSurface(
                    assetPath: _previewed.assetPath,
                    preset: ThemeBlurPreset.galleryGlow,
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(child: image),
          // Deviation D2: the round controls are 36 across, not 50 x k (23 on a phone): a finger has to hit them.
          // Deviation D1: the left one is the cross, the right one the check; the frame's middle capsule is not carried.
          Positioned(
            left: 31 * k,
            top: 26 * k,
            child: VCircleButton(icon: Icons.close_rounded, floating: true, selected: true, tooltip: 'Close', onTap: widget.onCancel),
          ),
          Positioned(
            right: 24 * k,
            top: 26 * k,
            child: VCircleButton(icon: Icons.check_rounded, floating: true, selected: true, tooltip: 'Set Wallpaper', onTap: () => widget.onConfirmTheme(_previewed)),
          ),
          Positioned(
            left: 49 * k,
            right: 36 * k,
            bottom: 33 * k,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Deviation D4: the name is 20, not 24 x k (11 on a phone): it has to be read.
                Opacity(
                  opacity: 1 - 0.7 * _pull,
                  child: Text(
                    _previewed.name,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.fade,
                    style: VType.title().copyWith(fontSize: 20, height: 24 / 20, fontWeight: FontWeight.w700, letterSpacing: 1.2, shadows: _shadow),
                  ),
                ),
                if (WallpaperCatalog.tracksFor(_previewed).isNotEmpty) ...[
                  SizedBox(height: math.max(35 * k, 12)),
                  AnimatedBuilder(animation: _p, builder: (_, __) => _playRow(k)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Play, how far the theme's music has played, and the speaker. Frame: glyph, line 520 of 646, glyph.
  Widget _playRow(double k) {
    const white = Colors.white;
    final progress = _mine ? _p.progress : 0.0;
    return Row(
      children: [
        VPress(
          onTap: _playPause,
          tooltip: _mine && _p.playing ? 'Pause' : 'Play',
          child: Icon(_mine && _p.playing ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 24, color: white, shadows: _shadow),
        ),
        SizedBox(width: math.max(39 * k, 12)),
        Expanded(
          child: LayoutBuilder(
            builder: (_, c) => GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) {
                if (_mine && _p.duration > 0) _p.seek(d.localPosition.dx / c.maxWidth);
              },
              child: SizedBox(
                height: 24,
                child: Center(
                  child: Stack(
                    children: [
                      Container(height: 3, decoration: BoxDecoration(color: const Color(0x80FFFFFF), borderRadius: BorderRadius.circular(2))),
                      Container(width: c.maxWidth * progress, height: 3, decoration: BoxDecoration(color: white, borderRadius: BorderRadius.circular(2))),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        SizedBox(width: math.max(34 * k, 12)),
        VPress(
          onTap: _p.toggleMute,
          tooltip: _p.muted ? 'Sound On' : 'Mute',
          child: Icon(_p.muted ? Icons.volume_off_rounded : Icons.volume_up_rounded, size: 22, color: white, shadows: _shadow),
        ),
      ],
    );
  }

  /// The strip: the chosen picture square in the middle, the others narrow beside it, fading out gradually
  /// over the first 258 of 700 and the last 169 of 700, as the frame's two gradients do.
  Widget _thumbnails(double stripW) {
    final themes = _themes;
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (r) => const LinearGradient(
        colors: [Color(0x00FFFFFF), Colors.white, Colors.white, Color(0x00FFFFFF)],
        stops: [0, 258 / 700, 1 - 169 / 700, 1],
      ).createShader(r),
      child: ListView.separated(
        controller: _strip,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: (stripW - _thumbH) / 2),
        itemCount: themes.length,
        separatorBuilder: (_, __) => const SizedBox(width: _gap),
        itemBuilder: (_, i) {
          final t = themes[i];
          final sel = t.id == _previewed.id;
          return VPress(
            onTap: () => _select(t),
            tooltip: t.name,
            child: AnimatedContainer(
              duration: VMotion.base,
              curve: Curves.easeOutCubic,
              width: sel ? _thumbH : _thumbW,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: Image.asset(t.assetPath, height: _thumbH, fit: BoxFit.cover, filterQuality: FilterQuality.medium),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The live wallpapers as they appear from the gallery below them. Made by Claude (2026-10-04).
class _LivePeek extends StatefulWidget {
  final double pull;
  final VoidCallback onTap;
  const _LivePeek({required this.pull, required this.onTap});

  @override
  State<_LivePeek> createState() => _LivePeekState();
}

class _LivePeekState extends State<_LivePeek> with SingleTickerProviderStateMixin {
  // slow enough that it never competes with the gallery: a card takes 12 seconds to pass
  late final AnimationController _drift = AnimationController(
    vsync: this,
    duration: Duration(seconds: 12 * WallpaperCatalog.premiumThemes.length.clamp(2, 60)),
  )..repeat();

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final live = WallpaperCatalog.premiumThemes;
    if (live.isEmpty) return const SizedBox.shrink();
    // The same card as the free row below, so it reads as one more shelf of the same thing.
    const w = 68.0, gap = 10.0, full = 116.0, rest = 60.0;
    final span = live.length * (w + gap);
    final p = widget.pull;
    final soft = 1.7 * (1 - p);
    // Only the cards in view are built, and the softness is one blur over the strip, not one per card
    // (Claude 2026-10-18: 236 blurred cards redrawn every frame held the gallery near 40 fps).
    Widget cards(double offset, double width) {
      final first = (offset / (w + gap)).floor();
      final n = (width / (w + gap)).ceil() + 2;
      return Stack(
        clipBehavior: Clip.none,
        children: [
          for (var k = first; k < first + n; k++)
            Positioned(
              left: k * (w + gap) - offset,
              bottom: 0,
              width: w,
              height: full,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: Image.asset(live[k % live.length].assetPath, width: w, height: full, fit: BoxFit.cover, filterQuality: FilterQuality.medium),
              ),
            ),
        ],
      );
    }
    return GestureDetector(
      onTap: widget.onTap,
      child: SizedBox(
        // at rest only the foot of each card shows; pulling up raises the whole card
        height: rest + (full - rest) * p,
        child: ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (r) => LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color.fromRGBO(255, 255, 255, p), Colors.white],
            stops: const [0, 0.8],
          ).createShader(r),
          child: EdgeFadeHorizontal(
            fade: 28,
            child: ClipRect(
              child: RepaintBoundary(
                child: ImageFiltered(
                  enabled: soft > 0.05,
                  imageFilter: ImageFilter.blur(sigmaX: soft, sigmaY: soft, tileMode: TileMode.decal),
                  child: LayoutBuilder(
                    builder: (_, box) => AnimatedBuilder(
                      animation: _drift,
                      builder: (_, __) => cards(_drift.value * span, box.maxWidth),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Horizontal edge fade for thumbnail strips.
class EdgeFadeHorizontal extends StatelessWidget {
  final Widget child;
  final double fade;
  const EdgeFadeHorizontal({super.key, required this.child, this.fade = 16});

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (r) {
        final f = (fade / (r.width <= 0 ? 1 : r.width)).clamp(0.0, 0.3);
        return LinearGradient(
          colors: const [Color(0x00FFFFFF), Colors.white, Colors.white, Color(0x00FFFFFF)],
          stops: [0, f, 1 - f, 1],
        ).createShader(r);
      },
      child: child,
    );
  }
}
