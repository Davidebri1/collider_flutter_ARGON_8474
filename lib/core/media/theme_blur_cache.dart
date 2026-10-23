import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../../models/theme_def.dart';
import '../vision/vision_tokens.dart';
import 'theme_media_bundle.dart';

/// The looks a wallpaper is shown with. Each is the same decoded picture drawn through Flutter's own live filters
/// (ImageFiltered / ColorFiltered): nothing is stored per look.
/// Claude, 2026-10-23: each look used to be painted once into a separate full-size blurred copy and kept in memory,
/// four copies per wallpaper. David: "switch to the proper blurring".
enum ThemeBlurPreset {
  /// The picture as it is.
  poster,

  /// Behind a resting overlay: blur 22 and the scrim dim.
  scrim,

  /// Theme Gallery room: blur 16 and a light dark tint.
  galleryRoom,

  /// Theme Gallery colour glow behind a card: blur 36.
  galleryGlow,

  /// Premium Theme Market background: blur 20, darkened, with the picture falling away to black at top and bottom.
  ambient,
}

/// Draws [sharp] (a picture filling its box) with [preset]'s look, live.
Widget themeBlurLook(ThemeBlurPreset preset, Widget sharp) {
  Widget blur(double s, Widget c, {TileMode mode = TileMode.clamp}) =>
      ImageFiltered(imageFilter: ui.ImageFilter.blur(sigmaX: s, sigmaY: s, tileMode: mode), child: c);
  switch (preset) {
    case ThemeBlurPreset.poster:
      return sharp;
    case ThemeBlurPreset.scrim:
      return Stack(fit: StackFit.expand, children: [blur(VBlur.medium, sharp), ColoredBox(color: VOverlay.scrim)]);
    case ThemeBlurPreset.galleryRoom:
      return Stack(fit: StackFit.expand, children: [blur(16, sharp), const ColoredBox(color: Color(0x38000000))]);
    case ThemeBlurPreset.galleryGlow:
      return blur(36, sharp, mode: TileMode.decal);
    case ThemeBlurPreset.ambient:
      // SimpleBackgroundVideo.tsx: black base, blur(20px) + brightness(0.5) + contrast(1.2) at 0.7 opacity, dark overlay 0.2.
      const matrix = <double>[
        0.36, 0, 0, 0, -25.5,
        0, 0.36, 0, 0, -25.5,
        0, 0, 0.36, 0, -25.5,
        0, 0, 0, 0.7, 0,
      ];
      return Stack(fit: StackFit.expand, children: [
        const ColoredBox(color: Colors.black),
        blur(20, ColorFiltered(colorFilter: const ColorFilter.matrix(matrix), child: sharp)),
        const ColoredBox(color: Color(0x59000000)),
        // the source's letterbox: the picture falls away to black toward the top and bottom edges
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xF2000000), Color(0x00000000), Color(0x00000000), Color(0xF2000000)],
              stops: [0.0, 0.3, 0.7, 1.0],
            ),
          ),
        ),
      ]);
  }
}

/// Decoded wallpaper pictures, kept for the themes around the one in view.
class ThemeBlurCache extends ChangeNotifier {
  ThemeBlurCache._();
  static final ThemeBlurCache instance = ThemeBlurCache._();

  final Map<String, ui.Image> _posters = {};
  final Map<String, Future<ui.Image?>> _posterPending = {};

  String _activeAssetPath = WallpaperCatalog.defaultTheme.assetPath;
  String get activeAssetPath => _activeAssetPath;

  void setActiveTheme(WallpaperTheme theme) {
    if (theme.assetPath.isEmpty) return;
    _activeAssetPath = theme.assetPath;
    unawaited(ensurePoster(theme.assetPath));
  }

  /// Synchronous lookup of a decoded picture.
  ui.Image? posterOf(String assetPath) => _posters[assetPath];

  /// Decodes the pictures of the themes about to be seen.
  Future<void> prewarmThemes(Iterable<WallpaperTheme> themes) async {
    for (final t in themes) {
      if (t.assetPath.isEmpty) continue;
      unawaited(ensurePoster(t.assetPath));
    }
  }

  /// Kept for callers that ready a theme before showing it: the looks need only the picture.
  Future<void> ensureAllPresets(String assetPath) => ensurePoster(assetPath);

  // How many themes' pictures stay decoded. The theme in use is always kept; dropped pictures are decoded again if they
  // come back. (Claude, 2026-10-21: an unbounded cache ended the page on David's iPhone.)
  static const _keepPosters = 8;

  void _keep() {
    while (_posters.length > _keepPosters) {
      final old = _posters.keys.firstWhere((k) => k != _activeAssetPath, orElse: () => '');
      if (old.isEmpty) break;
      _posters.remove(old);
    }
  }

  /// Decodes and caches the picture for [assetPath] once.
  Future<ui.Image?> ensurePoster(String assetPath) {
    if (assetPath.isEmpty) return SynchronousFuture(null);
    final hit = _posters.remove(assetPath);
    if (hit != null) {
      _posters[assetPath] = hit; // most recently used last
      return SynchronousFuture(hit);
    }
    final inflight = _posterPending[assetPath];
    if (inflight != null) return inflight;

    final fut = _decodePoster(assetPath);
    _posterPending[assetPath] = fut;
    fut.whenComplete(() => _posterPending.remove(assetPath));
    return fut;
  }

  Future<ui.Image?> _decodePoster(String assetPath) async {
    try {
      final data = await ThemeMediaAssetBundle.instance.load(assetPath);
      if (data.lengthInBytes == 0) return null;
      final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final img = frame.image;
      _posters[assetPath] = img;
      _keep();
      notifyListeners();
      return img;
    } catch (e) {
      debugPrint('ThemeBlurCache poster decode failed ($assetPath): $e');
      return null;
    }
  }
}

/// A wallpaper picture drawn with one of the looks.
class CachedThemeSurface extends StatefulWidget {
  final String assetPath;
  final ThemeBlurPreset preset;
  final BoxFit fit;
  final Widget? placeholder;

  const CachedThemeSurface({
    super.key,
    required this.assetPath,
    required this.preset,
    this.fit = BoxFit.cover,
    this.placeholder,
  });

  @override
  State<CachedThemeSurface> createState() => _CachedThemeSurfaceState();
}

class _CachedThemeSurfaceState extends State<CachedThemeSurface> {
  ui.Image? _img;

  @override
  void initState() {
    super.initState();
    _syncOrLoad();
  }

  @override
  void didUpdateWidget(covariant CachedThemeSurface old) {
    super.didUpdateWidget(old);
    if (old.assetPath != widget.assetPath) _syncOrLoad();
  }

  void _syncOrLoad() {
    final cache = ThemeBlurCache.instance;
    _img = cache.posterOf(widget.assetPath);
    if (_img != null) return;
    final path = widget.assetPath;
    cache.ensurePoster(path).then((res) {
      if (mounted && res != null && widget.assetPath == path) setState(() => _img = res);
    });
  }

  @override
  Widget build(BuildContext context) {
    final img = _img;
    if (img == null) return widget.placeholder ?? const ColoredBox(color: Color(0xFF0B0D13));
    return RepaintBoundary(
      child: ClipRect(
        child: themeBlurLook(
          widget.preset,
          RawImage(image: img, fit: widget.fit, width: double.infinity, height: double.infinity, filterQuality: FilterQuality.medium),
        ),
      ),
    );
  }
}
