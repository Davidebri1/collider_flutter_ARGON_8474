// Browser page surface (web).
// Uses a clean, native browser iframe with full scrolling and standard web capabilities.
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;
import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

int _frames = 0;

class WebFrame extends StatefulWidget {
  final String url;
  final int reload;
  final double zoom;
  final void Function(String url, String title)? onNavigated;
  final void Function(String name)? onDownloaded;

  const WebFrame({super.key, required this.url, this.reload = 0, this.zoom = 1, this.onNavigated, this.onDownloaded});

  @override
  State<WebFrame> createState() => _WebFrameState();
}

class _WebFrameState extends State<WebFrame> {
  late final String _type = 'collider-frame-${_frames++}';
  late final web.HTMLIFrameElement _el;
  late final JSFunction _listener;
  String _showing = '';

  static String _resolveUrl(String url) {
    final u = url.trim();
    // Google supports direct iframe embedding when igu=1 is present; Wikipedia, Bing, DuckDuckGo, and local pages embed directly.
    if (u.startsWith('https://www.google.com/') || u.startsWith('https://google.com/')) {
      if (!u.contains('igu=1')) {
        return u.contains('?') ? '$u&igu=1' : '${u.endsWith('/') ? u : '$u/'}webhp?igu=1';
      }
      return u;
    }
    if (u.startsWith('http://') || u.startsWith('https://')) {
      return '/api/page?url=${Uri.encodeComponent(u)}';
    }
    return u;
  }

  @override
  void initState() {
    super.initState();
    _showing = widget.url;
    _el = web.HTMLIFrameElement()
      ..src = _resolveUrl(widget.url)
      ..style.border = '0'
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.background = 'white';
    _el.style.setProperty('zoom', '${widget.zoom}');
    _el.setAttribute('allow', 'accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share');
    ui_web.platformViewRegistry.registerViewFactory(_type, (int _) => _el);
    _listener = ((web.Event e) {
      final m = e as web.MessageEvent;
      final from = m.source as JSAny?;
      if (from == null || !from.strictEquals(_el.contentWindow as JSAny?).toDart) return;
      final d = m.data.dartify();
      if (d is! Map) return;
      if (d['collider'] == 'nav') {
        final u = '${d['url'] ?? ''}';
        if (u.isEmpty) return;
        _showing = u;
        widget.onNavigated?.call(u, '${d['title'] ?? ''}');
      } else if (d['collider'] == 'download') {
        widget.onDownloaded?.call('${d['name'] ?? ''}');
      }
    }).toJS;
    web.window.addEventListener('message', _listener);
  }

  @override
  void didUpdateWidget(covariant WebFrame old) {
    super.didUpdateWidget(old);
    if (widget.zoom != old.zoom) _el.style.setProperty('zoom', '${widget.zoom}');
    if (widget.reload != old.reload || widget.url != _showing) {
      _showing = widget.url;
      _el.src = _resolveUrl(widget.url);
    }
  }

  @override
  void dispose() {
    web.window.removeEventListener('message', _listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => HtmlElementView(viewType: _type);
}
