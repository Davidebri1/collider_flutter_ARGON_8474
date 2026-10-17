import 'dart:ui' as ui show Image;
import 'dart:ui' show ImageFilter;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../models/theme_def.dart';
import '../../core/media/live_frames.dart';

/// Still poster for CoverFlow thumbs (lightweight).
class ThemePosterImage extends StatelessWidget {
  final WallpaperTheme theme;
  final BoxFit fit;
  final FilterQuality filterQuality;

  const ThemePosterImage({
    super.key,
    required this.theme,
    this.fit = BoxFit.cover,
    this.filterQuality = FilterQuality.high,
  });

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      theme.assetPath,
      fit: fit,
      filterQuality: filterQuality,
      errorBuilder: (_, __, ___) => Container(
        color: const Color(0xFF1A1B22),
        child: const Icon(Icons.wallpaper_rounded, color: Colors.white38),
      ),
    );
  }
}

/// The Premium Theme Market's background, ported by Claude (2026-10-17) from David's Premium Theme Market source,
/// SimpleBackgroundVideo.tsx (the one App.tsx plays): the video behind everything with
/// `filter: blur(20px) brightness(0.5) contrast(1.2)`, opacity 0.7 (0.3 while it loads), over black,
/// under `rgba(0,0,0,0.2)`. The YouTube video it played is the theme's live wallpaper here.
class PremiumAmbient {
  PremiumAmbient._();

  /// The market's play / pause (Player.tsx) drives this; the background follows it.
  static final ValueNotifier<bool> playing = ValueNotifier(true);
}

class BuilderAmbientFilter {
  BuilderAmbientFilter._();

  static const double blurSigma = 20.0;
  static const double layerOpacity = 0.7;
  static const Color darkOverlay = Color(0x33000000); // rgba(0,0,0,0.2)

  // brightness(0.5)
  static const ColorFilter _brightness = ColorFilter.matrix(<double>[
    0.5, 0, 0, 0, 0,
    0, 0.5, 0, 0, 0,
    0, 0, 0.5, 0, 0,
    0, 0, 0, 1, 0,
  ]);

  // contrast(1.2) — translate = 0.5 * (1 - c) * 255 = -25.5
  static const ColorFilter _contrast = ColorFilter.matrix(<double>[
    1.2, 0, 0, 0, -25.5,
    0, 1.2, 0, 0, -25.5,
    0, 0, 1.2, 0, -25.5,
    0, 0, 0, 1, 0,
  ]);

  /// [child] with the source's treatment. [sigma] is the blur in the child's own pixels: the market draws a small
  /// copy of the video and blurs that, which looks the same as blurring the full screen at a fraction of the work.
  static Widget wrap(Widget child, {double sigma = blurSigma, bool loading = false}) {
    final filtered = ColorFiltered(
      colorFilter: _contrast,
      child: ColorFiltered(
        colorFilter: _brightness,
        child: sigma <= 0
            ? child
            : ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma, tileMode: TileMode.clamp), child: child),
      ),
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Colors.black),
        AnimatedOpacity(duration: const Duration(seconds: 1), curve: Curves.easeInOut, opacity: loading ? 0.3 : layerOpacity, child: filtered),
        const ColoredBox(color: darkOverlay),
      ],
    );
  }
}

/// Full-bleed living wallpaper: its loop when it has one, else its poster.
/// In the Premium Theme Market ([builderAmbient]) the loop is drawn from a small copy of its frames (LiveFrames)
/// under the source's blur, and pauses and plays with the market's player (PremiumAmbient.playing).
class ThemeLivingBackdrop extends StatefulWidget {
  final WallpaperTheme theme;
  /// When false, always show poster.
  final bool preferVideo;
  /// The Premium Theme Market's background (SimpleBackgroundVideo.tsx).
  final bool builderAmbient;

  const ThemeLivingBackdrop({
    super.key,
    required this.theme,
    this.preferVideo = true,
    this.builderAmbient = false,
  });

  @override
  State<ThemeLivingBackdrop> createState() => _ThemeLivingBackdropState();
}

/// Where the browser finds a theme's media: its own address, or the app's bundled asset.
String themeMediaUrl(String path) => path.startsWith('http') ? path : 'assets/$path';

class _ThemeLivingBackdropState extends State<ThemeLivingBackdrop> {
  VideoPlayerController? _controller;
  LiveFrames? _frames;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _boot();
    PremiumAmbient.playing.addListener(_follow);
  }

  void _follow() {
    final f = _frames;
    if (f == null) return;
    PremiumAmbient.playing.value ? f.play() : f.pause();
  }

  Future<void> _boot() async {
    final path = widget.theme.videoPath;
    if (!widget.preferVideo || path == null || path.isEmpty) return;
    if (widget.builderAmbient) {
      _frames = LiveFrames(themeMediaUrl(path), width: 360, fps: 15);
      _follow();
      return;
    }
    try {
      final c = path.startsWith('http') ? VideoPlayerController.networkUrl(Uri.parse(path)) : VideoPlayerController.asset(path);
      _controller = c;
      await c.initialize();
      await c.setLooping(true);
      await c.setVolume(0);
      await c.play();
      if (mounted) setState(() => _ready = true);
    } catch (e) {
      debugPrint('ThemeLivingBackdrop video fallback: $e');
      _controller = null;
    }
  }

  @override
  void dispose() {
    PremiumAmbient.playing.removeListener(_follow);
    _controller?.dispose();
    _frames?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final poster = ThemePosterImage(theme: widget.theme, filterQuality: FilterQuality.low);
    final f = _frames;
    if (widget.builderAmbient) {
      if (f == null) return BuilderAmbientFilter.wrap(poster);
      return ValueListenableBuilder<ui.Image?>(
        valueListenable: f.frame,
        builder: (_, img, __) => img == null
            ? BuilderAmbientFilter.wrap(poster, loading: true)
            : LayoutBuilder(builder: (_, box) {
                // The small copy is blurred at its own size, by the source's 20 px as it will appear on the screen,
                // then scaled up to cover: the same look as blurring the full screen, for a fraction of the work.
                final sx = box.maxWidth / img.width, sy = box.maxHeight / img.height;
                final scale = sx > sy ? sx : sy;
                return BuilderAmbientFilter.wrap(
                  FittedBox(
                    fit: BoxFit.cover,
                    clipBehavior: Clip.hardEdge,
                    child: SizedBox(
                      width: img.width.toDouble(),
                      height: img.height.toDouble(),
                      child: ImageFiltered(
                        imageFilter: ImageFilter.blur(
                          sigmaX: BuilderAmbientFilter.blurSigma / (scale <= 0 ? 1 : scale),
                          sigmaY: BuilderAmbientFilter.blurSigma / (scale <= 0 ? 1 : scale),
                          tileMode: TileMode.clamp,
                        ),
                        child: RawImage(image: img, filterQuality: FilterQuality.low),
                      ),
                    ),
                  ),
                  sigma: 0,
                );
              }),
      );
    }
    final c = _controller;
    if (_ready && c != null && c.value.isInitialized) {
      return FittedBox(
        fit: BoxFit.cover,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(width: c.value.size.width, height: c.value.size.height, child: VideoPlayer(c)),
      );
    }
    return ThemePosterImage(theme: widget.theme, filterQuality: FilterQuality.high);
  }
}

/// Cover media: poster by default; optional center video when [playVideo] and web-safe.
class ThemeCoverMedia extends StatelessWidget {
  final WallpaperTheme theme;
  final bool playVideo;

  const ThemeCoverMedia({
    super.key,
    required this.theme,
    this.playVideo = false,
  });

  @override
  Widget build(BuildContext context) {
    // Prefer poster for CoverFlow thumbs (lighter). On non-web, center may play loop.
    final useVideo = playVideo &&
        theme.videoPath != null &&
        !kIsWeb;
    if (useVideo) {
      return ThemeLivingBackdrop(
        key: ValueKey('cover-vid-${theme.id}'),
        theme: theme,
        preferVideo: true,
      );
    }
    return ThemePosterImage(theme: theme);
  }
}
