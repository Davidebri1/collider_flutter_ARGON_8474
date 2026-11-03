// Browser page surface (native platforms via webview_flutter).
import 'package:flutter/widgets.dart';
import 'package:webview_flutter/webview_flutter.dart';

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
  WebViewController? _controller;
  String _showing = '';

  @override
  void initState() {
    super.initState();
    _showing = widget.url;
    try {
      final ctrl = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: (url) async {
              _showing = url;
              String title = '';
              try {
                title = (await _controller?.getTitle()) ?? '';
              } catch (_) {}
              widget.onNavigated?.call(url, title);
            },
          ),
        )
        ..loadRequest(Uri.parse(widget.url));
      _controller = ctrl;
    } catch (_) {}
  }

  @override
  void didUpdateWidget(covariant WebFrame old) {
    super.didUpdateWidget(old);
    if (widget.reload != old.reload) {
      _controller?.reload();
    } else if (widget.url != _showing) {
      _showing = widget.url;
      _controller?.loadRequest(Uri.parse(widget.url));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null) return Center(child: Text(widget.url));
    return WebViewWidget(controller: _controller!);
  }
}
