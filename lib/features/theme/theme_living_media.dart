import 'dart:ui' as ui show Image;
import 'dart:ui' show ImageFilter;
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:video_player/video_player.dart';
import '../../models/theme_def.dart';
import '../../core/media/live_frames.dart';
import '../../core/media/theme_blur_cache.dart';

/// Still poster for CoverFlow thumbs & backdrops, backed by [ThemeBlurCache] for 0ms synchronous hits.
class ThemePosterImage extends StatefulWidget {
  final WallpaperTheme theme;
  final BoxFit fit;
  final FilterQuality filterQuality;
  final Widget? placeholder;

  const ThemePosterImage({
    super.key,
    required this.theme,
    this.fit = BoxFit.cover,
    this.filterQuality = FilterQuality.high,
    this.placeholder,
  });

  @override
  State<ThemePosterImage> createState() => _ThemePosterImageState();
}

class _ThemePosterImageState extends State<ThemePosterImage> {
  @override
  void initState() {
    super.initState();
    if (widget.theme.assetPath.isNotEmpty) {
      ThemeBlurCache.instance.ensurePoster(widget.theme.assetPath);
    }
  }

  @override
  void didUpdateWidget(covariant ThemePosterImage old) {
    super.didUpdateWidget(old);
    if (old.theme.assetPath != widget.theme.assetPath && widget.theme.assetPath.isNotEmpty) {
      ThemeBlurCache.instance.ensurePoster(widget.theme.assetPath);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cached = ThemeBlurCache.instance.posterOf(widget.theme.assetPath);
    if (cached != null) {
      return RawImage(
        image: cached,
        fit: widget.fit,
        width: double.infinity,
        height: double.infinity,
        filterQuality: widget.filterQuality,
      );
    }
    final isNet = widget.theme.assetPath.startsWith('http://') || widget.theme.assetPath.startsWith('https://');
    if (isNet) {
      return Image.network(
        widget.theme.assetPath,
        fit: widget.fit,
        gaplessPlayback: true,
        filterQuality: widget.filterQuality,
        frameBuilder: widget.placeholder == null ? null : (_, child, frame, sync) => frame == null && !sync ? widget.placeholder! : child,
        errorBuilder: (_, __, ___) =>
            widget.placeholder ??
            Container(
              color: const Color(0xFF1A1B22),
              child: const Icon(Icons.wallpaper_rounded, color: Colors.white38),
            ),
      );
    }
    return Image.asset(
      widget.theme.assetPath,
      fit: widget.fit,
      gaplessPlayback: true,
      filterQuality: widget.filterQuality,
      frameBuilder: widget.placeholder == null ? null : (_, child, frame, sync) => frame == null && !sync ? widget.placeholder! : child,
      errorBuilder: (_, __, ___) =>
          widget.placeholder ??
          Container(
            color: const Color(0xFF1A1B22),
            child: const Icon(Icons.wallpaper_rounded, color: Colors.white38),
          ),
    );
  }
}

class PremiumAmbient {
  PremiumAmbient._();

  static final ValueNotifier<bool> playing = ValueNotifier(true);
}

class BuilderAmbientFilter {
  BuilderAmbientFilter._();

  static const double blurSigma = 20.0;
  static const double layerOpacity = 0.7;
  static const Color darkOverlay = Color(0x33000000);

  static const ColorFilter _brightness = ColorFilter.matrix(<double>[
    0.5, 0, 0, 0, 0,
    0, 0.5, 0, 0, 0,
    0, 0, 0.5, 0, 0,
    0, 0, 0, 1, 0,
  ]);

  static const ColorFilter _contrast = ColorFilter.matrix(<double>[
    1.2, 0, 0, 0, -25.5,
    0, 1.2, 0, 0, -25.5,
    0, 0, 1.2, 0, -25.5,
    0, 0, 0, 1, 0,
  ]);

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
        AnimatedOpacity(duration: const Duration(milliseconds: 350), curve: Curves.easeInOut, opacity: loading ? 0.3 : layerOpacity, child: filtered),
        const ColoredBox(color: darkOverlay),
      ],
    );
  }
}

/// Full-bleed living wallpaper: renders its clean 2D-canvas-synchronized [LiveFrames] on Web
/// (eliminating WebGL YUV green-swamp chroma corruption and scanline tearing), with instant
/// 0ms [ThemePosterImage] fallback while the video initializes.
class ThemeLivingBackdrop extends StatefulWidget {
  final WallpaperTheme theme;
  final bool preferVideo;
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

String themeMediaUrl(String path) => path.startsWith('http') ? path : 'assets/$path';

class _ThemeLivingBackdropState extends State<ThemeLivingBackdrop> {
  static final Map<String, VideoPlayerController> _videoPool = {};
  static const int _maxVideoPool = 2;

  VideoPlayerController? _controller;
  LiveFrames? _frames;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _boot();
    PremiumAmbient.playing.addListener(_follow);
  }

  @override
  void didUpdateWidget(covariant ThemeLivingBackdrop old) {
    super.didUpdateWidget(old);
    if (old.theme.id != widget.theme.id ||
        old.theme.videoPath != widget.theme.videoPath ||
        old.preferVideo != widget.preferVideo ||
        old.builderAmbient != widget.builderAmbient) {
      _detachCurrent(wasAmbient: old.builderAmbient);
      _boot();
    }
  }

  void _detachCurrent({required bool wasAmbient}) {
    _controller?.pause();
    _controller = null;
    _frames?.release(wantAmbient: wasAmbient);
    _frames = null;
    _ready = false;
  }

  void _follow() {
    final f = _frames;
    if (f == null) return;
    PremiumAmbient.playing.value ? f.play() : f.pause();
  }

  Future<void> _boot() async {
    if (widget.theme.assetPath.isNotEmpty) {
      ThemeBlurCache.instance.ensureAllPresets(widget.theme.assetPath);
    }
    final path = widget.theme.videoPath;
    if (!widget.preferVideo || path == null || path.isEmpty) {
      if (mounted) setState(() => _ready = false);
      return;
    }
    if (kIsWeb || widget.builderAmbient) {
      _frames = LiveFrames(
        themeMediaUrl(path),
        width: widget.builderAmbient ? 960 : 1440,
        fps: widget.builderAmbient ? 18 : 24,
        wantAmbient: widget.builderAmbient,
      );
      _follow();
      if (mounted) setState(() => _ready = true);
      return;
    }
    try {
      final existing = _videoPool.remove(path);
      if (existing != null && existing.value.isInitialized) {
        _videoPool[path] = existing;
        _controller = existing;
        _ready = true;
        existing.play();
        if (mounted) setState(() {});
        return;
      }
      if (_videoPool.length >= _maxVideoPool) {
        final oldestKey = _videoPool.keys.first;
        _videoPool.remove(oldestKey)?.dispose();
      }
      final c = path.startsWith('http') ? VideoPlayerController.networkUrl(Uri.parse(path)) : VideoPlayerController.asset(path);
      _controller = c;
      await c.initialize();
      await c.setLooping(true);
      await c.setVolume(0);
      await c.play();
      _videoPool[path] = c;
      if (mounted && _controller == c) setState(() => _ready = true);
    } catch (e) {
      debugPrint('ThemeLivingBackdrop video fallback: $e');
      _controller = null;
    }
  }

  @override
  void dispose() {
    PremiumAmbient.playing.removeListener(_follow);
    _controller?.pause();
    _frames?.release(wantAmbient: widget.builderAmbient);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.builderAmbient) {
      final cachedAmbientPoster = CachedThemeSurface(
        assetPath: widget.theme.assetPath,
        preset: ThemeBlurPreset.ambient,
      );
      final f = _frames;
      if (f == null) return cachedAmbientPoster;
      return ValueListenableBuilder<ui.Image?>(
        valueListenable: f.frame,
        builder: (_, img, __) {
          if (img != null) {
            return ClipRect(
              child: themeBlurLook(
                ThemeBlurPreset.ambient,
                RawImage(image: img, fit: BoxFit.cover, width: double.infinity, height: double.infinity, filterQuality: FilterQuality.high),
              ),
            );
          }
          return cachedAmbientPoster;
        },
      );
    }
    final f = _frames;
    if (kIsWeb && f != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          ThemePosterImage(theme: widget.theme, filterQuality: FilterQuality.high),
          ValueListenableBuilder<ui.Image?>(
            valueListenable: f.frame,
            builder: (_, img, __) {
              if (img == null) return const SizedBox.shrink();
              return RawImage(
                image: img,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                filterQuality: FilterQuality.high,
              );
            },
          ),
        ],
      );
    }
    final c = _controller;
    return Stack(
      fit: StackFit.expand,
      children: [
        ThemePosterImage(theme: widget.theme, filterQuality: FilterQuality.high),
        if (_ready && c != null && c.value.isInitialized && !c.value.hasError)
          FittedBox(
            fit: BoxFit.cover,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(width: c.value.size.width, height: c.value.size.height, child: VideoPlayer(c)),
          ),
      ],
    );
  }
}

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
    final useVideo = playVideo && theme.videoPath != null && !kIsWeb;
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
