import 'package:flutter/foundation.dart';

/// Cross-widget bus so the module rail's search actuator can command the
/// in-app browser (map W6: the browser's side nav includes Search; the
/// actuator lives in the rail, the result lands in the address bar).
class BrowserBus {
  BrowserBus._();

  /// Push a search query; the open browser sheet navigates to the engine.
  static final ValueNotifier<String?> search = ValueNotifier(null);

  static void pushSearch(String q) => search.value = q;

  /// Consume the last pushed search (the sheet clears it after acting).
  static void consume() => search.value = null;
}
