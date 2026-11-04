// E.D. — Collider — Signed: Gemini 4 Argon (2026-11-03)
import 'dart:async';
import 'dart:js_interop';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:ui_web' as ui_web;

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

/// Hardware-safe, reference-counted live video frame extractor.
/// Uses an intermediate 2D HTMLCanvasElement blit before importing into Skia/CanvasKit
/// so hardware-decoded YUV420/NV12 video streams are atomically converted to RGBA8888,
/// completely eliminating WebGL YUV chroma dropouts ("green swamp"), scanline tearing,
/// and multi-decoder GPU starvation.
class LiveFrames {
  static final Map<String, LiveFrames> _pool = {};
  static const int _maxPoolSize = 2;

  factory LiveFrames(String url, {int width = 1280, int fps = 24, bool wantAmbient = false}) {
    final existing = _pool.remove(url);
    if (existing != null) {
      _pool[url] = existing;
      existing._refs++;
      if (width > existing.width) {
        existing.width = width;
      }
      if (wantAmbient) {
        existing._ambientRefs++;
      }
      existing.play();
      return existing;
    }

    // Evict any unused (refs <= 0) entries immediately so hardware decoders are freed
    final unusedKeys = _pool.keys.where((k) => (_pool[k]?._refs ?? 0) <= 0).toList();
    for (final k in unusedKeys) {
      _pool.remove(k)?._destroy();
    }
    if (_pool.length >= _maxPoolSize) {
      final oldestKey = _pool.keys.first;
      _pool.remove(oldestKey)?._destroy();
    }

    final created = LiveFrames._internal(url, width: width, fps: fps, wantAmbient: wantAmbient);
    _pool[url] = created;
    return created;
  }

  LiveFrames._internal(this.url, {this.width = 1280, int fps = 24, bool wantAmbient = false})
      : _fps = fps.clamp(15, 30),
        _ambientRefs = wantAmbient ? 1 : 0 {
    final v = web.document.createElement('video') as web.HTMLVideoElement;
    v.muted = true;
    v.defaultMuted = true;
    v.loop = true;
    v.autoplay = true;
    v.playsInline = true;
    v.setAttribute('muted', '');
    v.setAttribute('playsinline', '');
    v.crossOrigin = 'anonymous';
    v.preload = 'auto';
    final s = v.style;
    s.position = 'fixed';
    s.left = '-9999px';
    s.top = '-9999px';
    s.width = '1px';
    s.height = '1px';
    s.opacity = '0';
    s.pointerEvents = 'none';
    v.src = url;
    web.document.body?.append(v);
    v.play().toDart.catchError((_) => null);
    _v = v;

    final c = web.document.createElement('canvas') as web.HTMLCanvasElement;
    _canvas = c;
    _ctx = c.getContext('2d') as web.CanvasRenderingContext2D?;
    _startTimer();
  }

  final String url;
  int width;
  final int _fps;
  int _refs = 1;
  int _ambientRefs;

  final ValueNotifier<ui.Image?> frame = ValueNotifier(null);
  final ValueNotifier<ui.Image?> ambientFrame = ValueNotifier(null);
  web.HTMLVideoElement? _v;
  web.HTMLCanvasElement? _canvas;
  web.CanvasRenderingContext2D? _ctx;
  Timer? _tick;
  bool _busy = false;
  bool _paused = false;

  void _startTimer() {
    _tick?.cancel();
    final ms = (1000 / _fps).round();
    _tick = Timer.periodic(Duration(milliseconds: ms), (_) => _grab());
  }

  Future<void> _grab() async {
    final v = _v;
    final canvas = _canvas;
    final ctx = _ctx;
    if (v == null || canvas == null || ctx == null || _busy || v.readyState < 2) return;
    final vw = v.videoWidth;
    final vh = v.videoHeight;
    if (vw <= 0 || vh <= 0) return;
    if (_paused && frame.value != null) return;
    if (v.paused && !_paused) {
      v.play().toDart.catchError((_) => null);
    }

    _busy = true;
    try {
      final maxEdge = math.min(width, math.max(vw, vh));
      final scale = maxEdge / math.max(vw, vh);
      final targetW = math.max(2, (vw * scale).round());
      final targetH = math.max(2, (vh * scale).round());
      if (canvas.width != targetW || canvas.height != targetH) {
        canvas.width = targetW;
        canvas.height = targetH;
      }
      // Atomic 2D canvas blit converts hardware YUV420/NV12 to clean sRGB RGBA8888,
      // preventing green-swamp chroma loss and scanline tearing in WebGL.
      ctx.drawImage(v, 0, 0, targetW.toDouble(), targetH.toDouble());
      try {
        final px = ctx.getImageData(targetW >> 1, math.max(0, targetH - 4), 1, 1).data.toDart;
        if (px.length >= 3 && px[0] < 24 && px[1] > 110 && px[2] < 24) {
          return; // Skip D3D11 NV12 uninitialized green macroblock frame
        }
      } catch (_) {}
      final img = await ui_web.createImageFromTextureSource(canvas, width: targetW, height: targetH);
      if (_v == null) {
        img.dispose();
        return;
      }
      final old = frame.value;
      frame.value = img;
      old?.dispose();
    } catch (_) {
      // Poster fallback remains visible until next clean frame.
    } finally {
      _busy = false;
    }
  }

  void play() {
    _paused = false;
    if (_tick == null || !_tick!.isActive) _startTimer();
    _v?.play().toDart.catchError((_) => null);
  }

  void pause() {
    _paused = true;
    _v?.pause();
  }

  void release({bool wantAmbient = false}) {
    if (wantAmbient && _ambientRefs > 0) _ambientRefs--;
    if (_refs > 0) _refs--;
    if (_refs <= 0) {
      final urlKey = url;
      _pool.remove(urlKey);
      _destroy();
    }
  }

  void dispose() => release();

  void _destroy() {
    _tick?.cancel();
    _tick = null;
    final v = _v;
    _v = null;
    _canvas = null;
    _ctx = null;
    if (v != null) {
      try {
        v.pause();
        v.removeAttribute('src');
        v.load();
        v.remove();
      } catch (_) {}
    }
    frame.value?.dispose();
    frame.value = null;
    ambientFrame.value?.dispose();
    ambientFrame.value = null;
  }
}
