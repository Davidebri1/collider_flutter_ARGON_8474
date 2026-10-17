// Live wallpapers from David's Cloudflare bucket. Made by Claude (2026-10-17).
// The local server builds the list from the bucket (GET /api/themes, see tools/collider_server.py themes()).
// The last list is kept on this device so the market opens at once; a fresh one replaces it when it arrives.
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/theme_def.dart';

class ThemeCloud extends ChangeNotifier {
  ThemeCloud._();
  static final ThemeCloud instance = ThemeCloud._();

  static const _prefsKey = 'theme_cloud_v1';
  List<WallpaperTheme> _themes = const [];
  bool _started = false;

  /// The live wallpapers, empty until the first list has been read.
  List<WallpaperTheme> get themes => _themes;

  Future<void> init() async {
    if (_started) return;
    _started = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_prefsKey);
      if (cached != null) _set(_parse(cached));
    } catch (_) {}
    try {
      final r = await Dio().get<String>('${Uri.base.origin}/api/themes', options: Options(responseType: ResponseType.plain));
      final body = r.data ?? '';
      final fresh = _parse(body);
      if (fresh.isNotEmpty) {
        _set(fresh);
        (await SharedPreferences.getInstance()).setString(_prefsKey, body);
      }
    } catch (e) {
      debugPrint('ThemeCloud: $e');
    }
  }

  void _set(List<WallpaperTheme> t) {
    if (t.isEmpty) return;
    _themes = t;
    notifyListeners();
  }

  static List<WallpaperTheme> _parse(String body) {
    final out = <WallpaperTheme>[];
    final list = jsonDecode(body);
    if (list is! List) return out;
    for (final j in list) {
      if (j is! Map || j['video'] is! String) continue;
      final poster = (j['poster'] as String?) ?? '';
      final tracks = <AmbientTrack>[
        for (final (i, t) in ((j['tracks'] as List?) ?? const []).indexed)
          if (t is Map && t['url'] is String)
            AmbientTrack(number: i + 1, title: (t['title'] as String?) ?? '', duration: '', mood: '', audioUrl: t['url'] as String),
      ];
      out.add(WallpaperTheme(
        id: j['id'] as String,
        name: (j['name'] as String?) ?? '',
        assetPath: poster,
        videoPath: j['video'] as String,
        isPremium: true,
        tier: '',
        creator: '',
        collection: '',
        productId: j['productId'] as String?,
        priceLabel: j['price'] as String?,
        tracks: tracks,
      ));
    }
    return out;
  }
}
