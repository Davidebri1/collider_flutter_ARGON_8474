// Made by Claude.
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:web/web.dart' as web;

void openUrl(String url) => web.window.open(url, '_blank');

/// System share sheet. Returns false when the browser has none, so the caller can copy instead.
Future<bool> shareText(String text) async {
  try {
    await web.window.navigator.share(web.ShareData(text: text)).toDart;
    return true;
  } catch (_) {
    return false;
  }
}

/// True when this device has a system share sheet.
bool get canShareText => (web.window.navigator as JSObject).has('share');
