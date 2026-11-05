// Browser page surface on iOS / Android: the page itself in a WebView
// (webview_flutter). No proxy is needed natively: a WebView is not a frame,
// so sites that refuse framing load as they would in a browser.
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'browser_commands.dart';

final Set<WebViewController> _live = {};

class WebFrame extends StatefulWidget {
  final String url;
  final double zoom; // reserved: native WebViews zoom themselves
  const WebFrame({super.key, required this.url, this.zoom = 1});

  /// Clear Cache (side nav): drop HTTP cache + local storage on every live
  /// WebView and reload it.
  static Future<void> clearAllCaches() async {
    for (final c in List.of(_live)) {
      try {
        await c.clearCache();
        await c.clearLocalStorage();
        await c.reload();
      } catch (_) {
        // A torn-down controller must not break the sweep.
      }
    }
  }

  @override
  State<WebFrame> createState() => _WebFrameState();
}

class _WebFrameState extends State<WebFrame> {
  late final WebViewController _ctrl;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _ctrl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) {
          if (mounted) {
            setState(() {
              _loading = true;
              _failed = false;
            });
          }
        },
        onPageFinished: (_) {
          if (mounted) setState(() => _loading = false);
        },
        onWebResourceError: (e) {
          // Only a failed main frame leaves a dead white page; sub-resource
          // errors are the site's problem.
          if (e.isForMainFrame == true && mounted) {
            setState(() {
              _loading = false;
              _failed = true;
            });
          }
        },
      ))
      ..loadRequest(Uri.parse(normalizeBrowserUrl(widget.url)));
    _live.add(_ctrl);
  }

  @override
  void didUpdateWidget(covariant WebFrame old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url) _ctrl.loadRequest(Uri.parse(normalizeBrowserUrl(widget.url)));
  }

  @override
  void dispose() {
    _live.remove(_ctrl);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
        children: [
          Positioned.fill(child: WebViewWidget(controller: _ctrl)),
          if (_loading)
            const Positioned(left: 0, right: 0, top: 0, child: LinearProgressIndicator(minHeight: 2)),
          if (_failed)
            Positioned.fill(
              child: BrowserEmbedError(
                url: widget.url,
                onReload: () {
                  setState(() {
                    _failed = false;
                    _loading = true;
                  });
                  _ctrl.reload();
                },
              ),
            ),
        ],
      );
}
