import 'dart:async';
import 'dart:js_interop';
import 'dart:ui' as ui;
import 'dart:ui_web' as ui_web;

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

class LiveFrames {
  LiveFrames(String url, {this.width = 480, int fps = 20}) {
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
    // Kept in the page (some browsers only decode attached videos), invisible and out of the way.
    final s = v.style;
    s.position = 'fixed';
    s.left = '0';
    s.top = '0';
    s.width = '2px';
    s.height = '2px';
    s.opacity = '0';
    s.pointerEvents = 'none';
    s.zIndex = '-1';
    v.src = url;
    web.document.body?.append(v);
    v.play().toDart.catchError((_) => null);
    _v = v;
    _tick = Timer.periodic(Duration(milliseconds: 1000 ~/ fps), (_) => _grab());
  }

  /// Width of the copied frames; height follows the video's shape.
  final int width;
  final ValueNotifier<ui.Image?> frame = ValueNotifier(null);
  web.HTMLVideoElement? _v;
  Timer? _tick;
  bool _busy = false;
  bool _paused = false;

  Future<void> _grab() async {
    final v = _v;
    if (v == null || _busy || v.readyState < 2 || v.videoWidth == 0) return;
    if (_paused && frame.value != null) return;
    _busy = true;
    try {
      final w = width < v.videoWidth ? width : v.videoWidth;
      final h = (v.videoHeight * w / v.videoWidth).round();
      final img = await ui_web.createImageFromTextureSource(v, width: w, height: h);
      if (_v == null) {
        img.dispose();
        return;
      }
      final old = frame.value;
      frame.value = img;
      old?.dispose();
    } catch (_) {
      // No frame yet (or the host refuses to share it): the poster stays.
    } finally {
      _busy = false;
    }
  }

  void play() {
    _paused = false;
    _v?.play().toDart.catchError((_) => null);
  }

  void pause() {
    _paused = true;
    _v?.pause();
  }

  void dispose() {
    _tick?.cancel();
    final v = _v;
    _v = null;
    if (v != null) {
      v.pause();
      v.removeAttribute('src');
      v.load();
      v.remove();
    }
    frame.value?.dispose();
    frame.dispose();
  }
}
