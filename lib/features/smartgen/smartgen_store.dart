// Smart Gen's cards, kept on this device. Made by Claude (2026-10-17); the idea of a small store that saves on every
// change is Grok's (smartgen/kanban_store.dart), held here in the browser's storage through shared_preferences.
// Nothing is made up: the board starts empty.
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SgCard {
  final String id;
  String title;
  bool done;
  SgCard({required this.id, required this.title, this.done = false});

  Map<String, dynamic> toJson() => {'id': id, 'title': title, if (done) 'done': true};
  factory SgCard.fromJson(Map<String, dynamic> j) => SgCard(id: j['id'] as String, title: (j['title'] as String?) ?? '', done: j['done'] == true);
}

class SmartGenStore extends ChangeNotifier {
  SmartGenStore._();
  static final SmartGenStore instance = SmartGenStore._();

  static const _key = 'smartgen_board_v1';
  final Map<String, List<SgCard>> _lists = {};
  bool _loaded = false;

  List<SgCard> list(String name) => _lists.putIfAbsent(name, () => []);

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final raw = (await SharedPreferences.getInstance()).getString(_key);
      if (raw != null) {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        for (final e in j.entries) {
          _lists[e.key] = [for (final c in (e.value as List)) SgCard.fromJson((c as Map).cast<String, dynamic>())];
        }
      }
    } catch (e) {
      debugPrint('SmartGenStore: $e');
    }
    notifyListeners();
  }

  Future<void> _save() async {
    notifyListeners();
    try {
      (await SharedPreferences.getInstance()).setString(_key, jsonEncode({for (final e in _lists.entries) e.key: [for (final c in e.value) c.toJson()]}));
    } catch (_) {}
  }

  SgCard add(String listName, String title) {
    final c = SgCard(id: DateTime.now().microsecondsSinceEpoch.toRadixString(36), title: title.trim());
    list(listName).add(c);
    _save();
    return c;
  }

  void update(SgCard c, {String? title, bool? done}) {
    if (title != null) c.title = title;
    if (done != null) c.done = done;
    _save();
  }

  void remove(SgCard c) {
    for (final l in _lists.values) {
      l.remove(c);
    }
    _save();
  }

  /// Moves [c] into [listName] at [index] (the end when null).
  void move(SgCard c, String listName, int? index) {
    String? from;
    int fromIndex = -1;
    for (final e in _lists.entries) {
      final i = e.value.indexOf(c);
      if (i >= 0) {
        from = e.key;
        fromIndex = i;
        e.value.removeAt(i);
        break;
      }
    }
    final to = list(listName);
    var at = index ?? to.length;
    if (from == listName && fromIndex >= 0 && fromIndex < at) at -= 1; // the gap it left
    to.insert(at.clamp(0, to.length), c);
    _save();
  }
}
