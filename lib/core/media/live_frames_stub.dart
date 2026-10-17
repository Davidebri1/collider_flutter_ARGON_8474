import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';

class LiveFrames {
  LiveFrames(String url, {int width = 480, int fps = 20});
  final ValueNotifier<ui.Image?> frame = ValueNotifier(null);
  void play() {}
  void pause() {}
  void dispose() => frame.dispose();
}
