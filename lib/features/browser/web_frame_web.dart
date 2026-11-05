// Browser page surface (web): the raw URL in an iframe. The /api/page proxy
// is gone — it 404s without the Collider server (v8.4 W5). Sites that refuse
// framing are caught on load and show the error card instead of a dead white
// frame: a refused frame loads a same-origin about:blank whose body stays
// empty, while a real cross-origin page throws on document access.
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import 'browser_commands.dart';

int _epoch = 0;
final Set<String> _registered = {};
// The mounted state owning each frame type hears about refusals through its
// hook here; factories outlive states, so they must not capture one.
final Map<String, void Function()> _failHooks = {};

bool _isRefused(web.HTMLIFrameElement f) {
  try {
    final doc = f.contentDocument;
    if (doc == null) return false;
    final href = doc.location?.href ?? '';
    final text = doc.body?.textContent ?? '';
    return href == 'about:blank' && text.isEmpty;
  } catch (_) {
    return false; // Cross-origin access threw: the page really loaded.
  }
}

class WebFrame extends StatefulWidget {
  final String url;
  /// Page zoom (the address bar's Aa): the page lays out at 1/zoom of the
  /// frame and is scaled up, like a browser's zoom.
  final double zoom;
  const WebFrame({super.key, required this.url, this.zoom = 1});

  /// Clear Cache (side nav): bump the epoch so every iframe is torn down and
  /// rebuilt — a fresh document with no carried-over state.
  static Future<void> clearAllCaches() async {
    _epoch++;
    _registered.clear();
    _failHooks.clear();
  }

  @override
  State<WebFrame> createState() => _WebFrameState();
}

class _WebFrameState extends State<WebFrame> {
  bool _failed = false;
  late String _boundType;

  String get _src => normalizeBrowserUrl(widget.url);
  String get _type => 'collider-frame-${_src.hashCode}-${widget.zoom}-$_epoch';

  @override
  void initState() {
    super.initState();
    _bind();
  }

  @override
  void didUpdateWidget(covariant WebFrame old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url || old.zoom != widget.zoom) {
      _unbind();
      _failed = false;
      _bind();
    }
  }

  @override
  void dispose() {
    _unbind();
    super.dispose();
  }

  void _bind() {
    _boundType = _type;
    _failHooks[_boundType] = _onFailed;
    _register();
  }

  void _unbind() {
    if (identical(_failHooks[_boundType], _onFailed)) _failHooks.remove(_boundType);
  }

  void _onFailed() {
    if (mounted && !_failed) setState(() => _failed = true);
  }

  void _register() {
    final type = _type;
    if (!_registered.add(type)) return;
    final src = _src;
    final zoom = widget.zoom;
    ui_web.platformViewRegistry.registerViewFactory(type, (int _) {
      final f = web.HTMLIFrameElement()
        ..src = src
        ..style.border = '0'
        ..style.width = '${100 / zoom}%'
        ..style.height = '${100 / zoom}%'
        ..style.transform = 'scale($zoom)'
        ..style.transformOrigin = '0 0'
        ..style.background = 'white';
      f.addEventListener('load', ((web.Event _) {
        if (_isRefused(f)) _failHooks[type]?.call();
      }).toJS);
      return f;
    });
  }

  void _openExternally() {
    // A real anchor navigation — popup blockers allow it inside a gesture.
    final a = web.HTMLAnchorElement()
      ..href = _src
      ..target = '_blank'
      ..rel = 'noopener noreferrer';
    web.document.body?.appendChild(a);
    a.click();
    a.remove();
  }

  void _reload() {
    _epoch++;
    _registered.clear();
    _unbind();
    _bind();
    if (mounted) setState(() => _failed = false);
  }

  @override
  Widget build(BuildContext context) {
    _register(); // idempotent; covers an epoch bump from clearAllCaches
    return Stack(
      fit: StackFit.expand,
      children: [
        HtmlElementView(key: ValueKey(_type), viewType: _type),
        if (_failed)
          BrowserEmbedError(url: _src, onOpenExternal: _openExternally, onReload: _reload),
      ],
    );
  }
}
