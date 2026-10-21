import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../models/theme_def.dart';
import '../vision/vision_tokens.dart';
import 'theme_media_bundle.dart';

/// Pre-rendered blur and poster presets cached once per theme asset.
/// Eliminates redundant per-frame / per-open Gaussian blur regeneration across
/// resting workspace scrims, Theme Gallery room & card glow, and Premium Theme Market ambient backgrounds.
enum ThemeBlurPreset {
  /// Decoded sharp poster image at native/display resolution.
  poster,

  /// Resting overlay scrim blur (VBlur.medium = 22px + VOverlay.scrim dim).
  scrim,

  /// Theme Gallery room blur (sigma 16px + 0.22 dark tint).
  galleryRoom,

  /// Theme Gallery behind-card color glow (sigma 36px).
  galleryGlow,

  /// Premium Theme Market BuilderAmbientFilter (sigma 20px + brightness 0.5 + contrast 1.2 + 0.20 dark overlay).
  ambient,
}

class ThemeBlurCache extends ChangeNotifier {
  ThemeBlurCache._();
  static final ThemeBlurCache instance = ThemeBlurCache._();

  final Map<String, ui.Image> _posters = {};
  final Map<String, Future<ui.Image?>> _posterPending = {};

  final Map<(String, ThemeBlurPreset), ui.Image> _blurred = {};
  final Map<(String, ThemeBlurPreset), Future<ui.Image?>> _blurPending = {};

  String _activeAssetPath = WallpaperCatalog.defaultTheme.assetPath;
  String get activeAssetPath => _activeAssetPath;

  void setActiveTheme(WallpaperTheme theme) {
    if (theme.assetPath.isEmpty) return;
    _activeAssetPath = theme.assetPath;
    unawaited(ensureAllPresets(theme.assetPath));
  }

  /// Synchronous lookup of a decoded sharp poster image.
  ui.Image? posterOf(String assetPath) => _posters[assetPath];

  /// Synchronous lookup of a pre-rendered blurred surface for [assetPath] and [preset].
  ui.Image? blurredOf(String assetPath, ThemeBlurPreset preset) {
    if (preset == ThemeBlurPreset.poster) return _posters[assetPath];
    return _blurred[(assetPath, preset)];
  }

  /// Synchronous lookup of the active theme's pre-blurred surface for [preset].
  ui.Image? activeBlurred(ThemeBlurPreset preset) => blurredOf(_activeAssetPath, preset);

  /// Gets the pictures of the themes about to be seen ready: their posters only. Each theme's blurred surfaces are made
  /// when something shows them (CachedThemeSurface) and for the theme in use.
  /// Claude, 2026-10-21: this made four full-size blurred copies of every theme it was given (ten at start alone), kept
  /// for good. A phone's browser has far less memory than a PC's, and on David's iPhone Safari ended the page at once
  /// ("A problem repeatedly occurred"). The cache now keeps a bounded number of themes (see _keep).
  Future<void> prewarmThemes(Iterable<WallpaperTheme> themes) async {
    for (final t in themes) {
      if (t.assetPath.isEmpty) continue;
      unawaited(ensurePoster(t.assetPath));
    }
  }

  // How many themes' pictures stay decoded: posters for the themes around the one in view, blurred surfaces for the few
  // most recently shown. The theme in use is always kept. Dropped pictures are decoded again if they come back.
  static const _keepPosters = 8;
  static const _keepBlurred = 3;

  void _keep() {
    while (_posters.length > _keepPosters) {
      final old = _posters.keys.firstWhere((k) => k != _activeAssetPath, orElse: () => '');
      if (old.isEmpty) break;
      _posters.remove(old);
    }
    final themes = <String>[];
    for (final k in _blurred.keys) {
      if (!themes.contains(k.$1)) themes.add(k.$1);
    }
    for (final old in themes.where((p) => p != _activeAssetPath).take((themes.length - _keepBlurred).clamp(0, themes.length))) {
      _blurred.removeWhere((k, _) => k.$1 == old);
    }
  }

  /// Ensures all common blur presets for [assetPath] are generated and cached in memory.
  Future<void> ensureAllPresets(String assetPath) async {
    if (assetPath.isEmpty) return;
    final img = await ensurePoster(assetPath);
    if (img == null) return;
    await Future.wait([
      ensureBlurred(assetPath, ThemeBlurPreset.scrim),
      ensureBlurred(assetPath, ThemeBlurPreset.galleryRoom),
      ensureBlurred(assetPath, ThemeBlurPreset.galleryGlow),
      ensureBlurred(assetPath, ThemeBlurPreset.ambient),
    ]);
  }

  /// Decodes and caches the base poster [ui.Image] for [assetPath] once.
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

  /// Rasterizes and caches the blurred variant once on an offscreen canvas.
  /// Downscaling before blurring produces a mathematically equivalent Gaussian kernel
  /// in <1ms and stores a compact GPU texture that draws with a single RawImage pass.
  Future<ui.Image?> ensureBlurred(String assetPath, ThemeBlurPreset preset) {
    if (assetPath.isEmpty) return SynchronousFuture(null);
    if (preset == ThemeBlurPreset.poster) return ensurePoster(assetPath);
    final key = (assetPath, preset);
    final hit = _blurred.remove(key);
    if (hit != null) {
      _blurred[key] = hit; // most recently used last
      return SynchronousFuture(hit);
    }
    final inflight = _blurPending[key];
    if (inflight != null) return inflight;

    final fut = _rasterizeBlur(assetPath, preset);
    _blurPending[key] = fut;
    fut.whenComplete(() => _blurPending.remove(key));
    return fut;
  }

  Future<ui.Image?> _rasterizeBlur(String assetPath, ThemeBlurPreset preset) async {
    final src = await ensurePoster(assetPath);
    if (src == null) return null;
    try {
      // Up to 1280 wide (Claude, 2026-10-21; was the poster's own size up to 2560, and before that 360). These are blurred
      // by 16 to 36 points: nothing finer than the blur survives it, so 1280 (a phone screen's full width) shows the same
      // picture as 2560 at a quarter of the memory. 360 had been visibly soft.
      final int targetW = src.width.clamp(1, 1280);
      final int targetH = ((src.height * targetW) / (src.width <= 0 ? 1 : src.width)).round();
      final double scale = targetW / 1440.0; // reference desktop width

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, targetW.toDouble(), targetH.toDouble()));
      final dstRect = Rect.fromLTWH(0, 0, targetW.toDouble(), targetH.toDouble());
      final srcRect = Rect.fromLTWH(0, 0, src.width.toDouble(), src.height.toDouble());

      switch (preset) {
        case ThemeBlurPreset.poster:
          canvas.drawImageRect(src, srcRect, dstRect, Paint()..filterQuality = FilterQuality.medium);
        case ThemeBlurPreset.scrim:
          final sigma = VBlur.medium * scale;
          final paint = Paint()
            ..filterQuality = FilterQuality.high
            ..imageFilter = ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma, tileMode: TileMode.clamp);
          canvas.drawImageRect(src, srcRect, dstRect, paint);
          canvas.drawRect(dstRect, Paint()..color = VOverlay.scrim);
        case ThemeBlurPreset.galleryRoom:
          final sigma = 16.0 * scale;
          final paint = Paint()
            ..filterQuality = FilterQuality.high
            ..imageFilter = ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma, tileMode: TileMode.clamp);
          canvas.drawImageRect(src, srcRect, dstRect, paint);
          canvas.drawRect(dstRect, Paint()..color = const Color(0x38000000));
        case ThemeBlurPreset.galleryGlow:
          final sigma = 36.0 * scale;
          final paint = Paint()
            ..filterQuality = FilterQuality.high
            ..imageFilter = ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma, tileMode: TileMode.decal);
          canvas.drawImageRect(src, srcRect, dstRect, paint);
        case ThemeBlurPreset.ambient:
          // SimpleBackgroundVideo.tsx: black base, blur(20px) + brightness(0.5) + contrast(1.2) at 0.7 opacity, dark overlay 0.2.
          canvas.drawRect(dstRect, Paint()..color = Colors.black);
          final sigma = 20.0 * scale;
          // Combined brightness(0.5) * contrast(1.2) matrix: scale = 0.6, translate = -25.5, alpha = 0.7
          const matrix = <double>[
            0.36, 0, 0, 0, -25.5,
            0, 0.36, 0, 0, -25.5,
            0, 0, 0.36, 0, -25.5,
            0, 0, 0, 0.7, 0,
          ];
          final paint = Paint()
            ..filterQuality = FilterQuality.high
            ..colorFilter = const ColorFilter.matrix(matrix)
            ..imageFilter = ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma, tileMode: TileMode.clamp);
          canvas.drawImageRect(src, srcRect, dstRect, paint);
          canvas.drawRect(dstRect, Paint()..color = const Color(0x59000000));
          canvas.drawRect(dstRect, Paint()..shader = _edges(dstRect));
      }

      final picture = recorder.endRecording();
      final out = await picture.toImage(targetW, targetH);
      picture.dispose();
      _blurred[(assetPath, preset)] = out;
      _keep();
      notifyListeners();
      return out;
    } catch (e) {
      debugPrint('ThemeBlurCache blur rasterize failed ($assetPath, $preset): $e');
      return null;
    }
  }

  /// Rasterizes an already-decoded [ui.Image] frame (such as a LiveFrames video frame) into an ambient blurred image.
  static Future<ui.Image?> rasterizeFrameAmbient(ui.Image frame) async {
    try {
      // The frame's own size (Claude, 2026-10-20: this was at most 360 px).
      final int w = frame.width.clamp(1, 1280); // blurred by 20 points: 1280 shows all of it (Claude, 2026-10-21)
      final int h = ((frame.height * w) / (frame.width <= 0 ? 1 : frame.width)).round();
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()));
      final dst = Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble());
      final src = Rect.fromLTWH(0, 0, frame.width.toDouble(), frame.height.toDouble());
      canvas.drawRect(dst, Paint()..color = Colors.black);
      const matrix = <double>[
        0.36, 0, 0, 0, -25.5,
        0, 0.36, 0, 0, -25.5,
        0, 0, 0.36, 0, -25.5,
        0, 0, 0, 0.7, 0,
      ];
      final sigma = 20.0 * w / 1440.0;
      final paint = Paint()
        ..filterQuality = FilterQuality.high
        ..colorFilter = const ColorFilter.matrix(matrix)
        ..imageFilter = ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma, tileMode: TileMode.clamp);
      canvas.drawImageRect(frame, src, dst, paint);
      canvas.drawRect(dst, Paint()..color = const Color(0x59000000));
      canvas.drawRect(dst, Paint()..shader = _edges(dst));
      final pic = recorder.endRecording();
      final img = await pic.toImage(w, h);
      pic.dispose();
      return img;
    } catch (_) {
      return null;
    }
  }
}

/// Renders a cached blurred or sharp surface from [ThemeBlurCache] without regenerating shaders on rebuild.
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
    if (old.assetPath != widget.assetPath || old.preset != widget.preset) {
      _syncOrLoad();
    }
  }

  void _syncOrLoad() {
    final cache = ThemeBlurCache.instance;
    final syncHit = cache.blurredOf(widget.assetPath, widget.preset);
    if (syncHit != null) {
      _img = syncHit;
      return;
    }
    // Fallback to sharp poster while blurred variant finishes (or vice versa)
    _img = cache.posterOf(widget.assetPath);
    cache.ensureBlurred(widget.assetPath, widget.preset).then((res) {
      if (mounted && res != null) {
        setState(() => _img = res);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final img = _img ?? ThemeBlurCache.instance.blurredOf(widget.assetPath, widget.preset);
    if (img != null) {
      return RawImage(
        image: img,
        fit: widget.fit,
        width: double.infinity,
        height: double.infinity,
        filterQuality: FilterQuality.high,
      );
    }
    return widget.placeholder ?? const ColoredBox(color: Color(0xFF0B0D13));
  }
}

/// The source's letterbox: the picture falls away to black toward the top and bottom edges (Claude, 2026-10-21).
Shader _edges(Rect r) => const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xF2000000), Color(0x00000000), Color(0x00000000), Color(0xF2000000)],
      stops: [0.0, 0.3, 0.7, 1.0],
    ).createShader(r);
