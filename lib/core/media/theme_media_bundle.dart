import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' show ImmutableBuffer;

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';

/// Asset bundle that also resolves absolute http(s) keys over the network.
/// Taken from Grok's build (core/media/theme_media_bundle.dart) by Claude, 2026-10-17.
///
/// Theme posters now come from David's Cloudflare bucket, and many places draw a theme with
/// `Image.asset(theme.assetPath)`. Installed as the app's DefaultAssetBundle, this lets them load
/// those posters unchanged. Non-URL keys go to [rootBundle].
class ThemeMediaAssetBundle extends AssetBundle {
  ThemeMediaAssetBundle(this._fallback);

  static final ThemeMediaAssetBundle instance = ThemeMediaAssetBundle(rootBundle);

  final AssetBundle _fallback;
  final Dio _dio = Dio(BaseOptions(
    responseType: ResponseType.bytes,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
  ));

  // In-flight / recent network loads, so the face + reflection of one cover
  // share a single request. Bounded; decoded images live in ImageCache.
  final Map<String, Future<ByteData>> _recent = {};
  static const int _maxRecent = 48;

  static bool isNetworkKey(String key) => key.startsWith('https://') || key.startsWith('http://');

  @override
  Future<ByteData> load(String key) {
    if (!isNetworkKey(key)) return _fallback.load(key);
    final existing = _recent[key];
    if (existing != null) return existing;
    final f = _fetch(key);
    _recent[key] = f;
    if (_recent.length > _maxRecent) _recent.remove(_recent.keys.first);
    f.catchError((Object _) {
      _recent.remove(key);
      return ByteData(0);
    });
    return f;
  }

  Future<ByteData> _fetch(String url) async {
    final res = await _dio.get<List<int>>(url);
    final data = res.data;
    if (res.statusCode != 200 || data == null || data.isEmpty) {
      throw StateError('ThemeMediaAssetBundle: ${res.statusCode} for $url');
    }
    final bytes = data is Uint8List ? data : Uint8List.fromList(data);
    return ByteData.sublistView(bytes);
  }

  @override
  Future<ImmutableBuffer> loadBuffer(String key) async {
    if (!isNetworkKey(key)) return _fallback.loadBuffer(key);
    final d = await load(key);
    return ImmutableBuffer.fromUint8List(d.buffer.asUint8List(d.offsetInBytes, d.lengthInBytes));
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) =>
      isNetworkKey(key) ? super.loadString(key, cache: cache) : _fallback.loadString(key, cache: cache);

  @override
  Future<T> loadStructuredData<T>(String key, Future<T> Function(String value) parser) =>
      _fallback.loadStructuredData<T>(key, parser);

  @override
  Future<T> loadStructuredBinaryData<T>(String key, FutureOr<T> Function(ByteData data) parser) =>
      _fallback.loadStructuredBinaryData<T>(key, parser);

  @override
  void evict(String key) {
    _recent.remove(key);
    _fallback.evict(key);
  }

  @override
  void clear() {
    _recent.clear();
    _fallback.clear();
  }
}
