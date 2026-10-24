// Smart Gen's cards, kept on this device and synced with Collider's consensus synthesis sessions.
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/api/collider_api.dart';

class SgCard {
  final String id;
  String title;
  String subtitle;
  String tag;
  String coverAsset;
  String dueDate;
  bool done;

  SgCard({
    required this.id,
    required this.title,
    this.subtitle = '',
    this.tag = 'Task',
    this.coverAsset = 'assets/wallpapers/1.webp',
    this.dueDate = 'Oct 24',
    this.done = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        if (subtitle.isNotEmpty) 'subtitle': subtitle,
        'tag': tag,
        'coverAsset': coverAsset,
        'dueDate': dueDate,
        if (done) 'done': true,
      };

  factory SgCard.fromJson(Map<String, dynamic> j) => SgCard(
        id: j['id'] as String,
        title: (j['title'] as String?) ?? '',
        subtitle: (j['subtitle'] as String?) ?? '',
        tag: (j['tag'] as String?) ?? _inferTag((j['title'] as String?) ?? ''),
        coverAsset: (j['coverAsset'] as String?) ?? _inferCover((j['id'] as String?) ?? ''),
        dueDate: (j['dueDate'] as String?) ?? 'Oct 25',
        done: j['done'] == true,
      );

  static String _inferTag(String title) {
    final t = title.toLowerCase();
    if (t.contains('theme') || t.contains('audio') || t.contains('wallpaper')) return 'Theme Studio';
    if (t.contains('model') || t.contains('consensus') || t.contains('prompt')) return 'AI Engine';
    if (t.contains('market') || t.contains('imagine') || t.contains('remix')) return 'Discover';
    if (t.contains('ui') || t.contains('glass') || t.contains('ticker') || t.contains('mobile')) return 'Spatial UI';
    return 'Workspace';
  }

  static String _inferCover(String seed) {
    const covers = [
      'assets/wallpapers/1.webp',
      'assets/wallpapers/2.webp',
      'assets/wallpapers/3.webp',
      'assets/wallpapers/4.webp',
      'assets/wallpapers/5.webp',
      'assets/wallpapers/6.webp',
      'assets/wallpapers/7.webp',
      'assets/wallpapers/8.webp',
    ];
    final idx = seed.codeUnits.fold<int>(0, (a, b) => a + b) % covers.length;
    return covers[idx];
  }
}

class SmartGenStore extends ChangeNotifier {
  SmartGenStore._();
  static final SmartGenStore instance = SmartGenStore._();

  static const _key = 'smartgen_board_v3';
  static const _dismissedKey = 'smartgen_dismissed_v3';
  final Map<String, List<SgCard>> _lists = {};
  final Set<String> _dismissedIds = {};
  bool _loaded = false;

  static bool _isTrivialCard(String title) {
    final t = title.trim().toLowerCase();
    return t.isEmpty ||
        t.length < 5 ||
        t == 'ok then' ||
        t == 'four' ||
        t == '4' ||
        t == 'hi' ||
        t == 'hello' ||
        t == 'test' ||
        t.startsWith('i am glm') ||
        t.startsWith('nemotron 3 super by') ||
        t.startsWith('i am nemotron') ||
        t.contains('what model are you') ||
        t.contains('who are you') ||
        t.contains('2+2');
  }

  List<SgCard> list(String name) => _lists.putIfAbsent(name, () => []);

  void _ensureSeeded() {
    if (list('High').isEmpty && list('Medium').isEmpty && list('Low').isEmpty) {
      _lists['High'] = [
        SgCard(
          id: 'seed_todo_1',
          title: 'Spatial Audio & 5-Track Playlist',
          subtitle: 'Verify per-track toggles and ambient crossfade across rooms.',
          tag: 'Theme Studio',
          coverAsset: 'assets/wallpapers/1.webp',
          dueDate: 'Today',
        ),
        SgCard(
          id: 'seed_todo_2',
          title: 'Multi-Model Consensus Synthesis',
          subtitle: 'Compare GLM 5.3, Nemotron Ultra & Gemma 4 agreement.',
          tag: 'AI Engine',
          coverAsset: 'assets/wallpapers/4.webp',
          dueDate: 'Oct 25',
        ),
      ];
      _lists['Medium'] = [
        SgCard(
          id: 'seed_doing_1',
          title: 'Bottom-Pinned 9:16 Ticker',
          subtitle: 'Keep upper 60% of the living wallpaper room open.',
          tag: 'Spatial UI',
          coverAsset: 'assets/wallpapers/2.webp',
          dueDate: 'In Review',
        ),
        SgCard(
          id: 'seed_doing_2',
          title: 'Imagine Discover Remix Flow',
          subtitle: 'One-tap remix attaches style reference into Image mode.',
          tag: 'Discover',
          coverAsset: 'assets/wallpapers/6.webp',
          dueDate: 'Oct 26',
        ),
      ];
      _lists['Low'] = [
        SgCard(
          id: 'seed_done_1',
          title: 'Hologram Account Persistence',
          subtitle: 'Sync active models, theme, and boards across launches.',
          tag: 'Workspace',
          coverAsset: 'assets/wallpapers/8.webp',
          dueDate: 'Done',
          done: true,
        ),
      ];
    }
    if (list('Projects').isEmpty) {
      _lists['Projects'] = [
        SgCard(
          id: 'seed_proj_1',
          title: 'Collider Mobile 9:16 Launch',
          subtitle: 'End-to-end VisionOS optical glass & spatial surfaces.',
          tag: 'Spatial UI',
          coverAsset: 'assets/wallpapers/3.webp',
          dueDate: 'Q4 Launch',
        ),
        SgCard(
          id: 'seed_proj_2',
          title: 'Premium Living Wallpaper Pack',
          subtitle: 'Curate 4K portrait video scenes with 5 ambient tracks.',
          tag: 'Theme Studio',
          coverAsset: 'assets/wallpapers/5.webp',
          dueDate: 'Active',
        ),
      ];
    }
    if (list('Reminders').isEmpty) {
      _lists['Reminders'] = [
        SgCard(
          id: 'seed_rem_1',
          title: 'Review PRD 4 Changelog & Flags',
          subtitle: 'Confirm all 14 technical directives are flagged in sheet.',
          tag: 'Workspace',
          coverAsset: 'assets/wallpapers/7.webp',
          dueDate: 'Today',
        ),
      ];
    }
  }

  Future<void> load() async {
    if (_loaded) {
      unawaited(syncAutonomousCards());
      return;
    }
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw != null) {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        for (final e in j.entries) {
          _lists[e.key] = [
            for (final c in (e.value as List))
              if (!_isTrivialCard('${(c as Map)['title'] ?? ''}'))
                SgCard.fromJson(c.cast<String, dynamic>()),
          ];
        }
      }
      final dis = prefs.getStringList(_dismissedKey);
      if (dis != null) _dismissedIds.addAll(dis);
    } catch (e) {
      debugPrint('SmartGenStore: $e');
    }
    _ensureSeeded();
    notifyListeners();
    await syncAutonomousCards();
  }

  /// Syncs autonomous cards extracted from real Collider conversation history (/api/smartgen).
  Future<void> syncAutonomousCards() async {
    try {
      final remote = await ColliderApi.instance.smartgenCards();
      if (remote.isEmpty) return;
      final existingIds = <String>{
        ..._dismissedIds,
        for (final l in _lists.values)
          for (final c in l) c.id,
      };
      final existingTitles = <String>{
        for (final l in _lists.values)
          for (final c in l) c.title.toLowerCase().trim(),
      };
      var added = false;
      for (final item in remote) {
        final id = '${item['id'] ?? ''}'.trim();
        final listName = '${item['list'] ?? 'Medium'}'.trim();
        final title = '${item['title'] ?? ''}'.trim();
        final content = '${item['content'] ?? ''}'.trim();
        if (id.isEmpty || title.isEmpty || _isTrivialCard(title)) continue;
        if (existingIds.contains(id)) {
          for (final l in _lists.values) {
            for (final c in l) {
              if (c.id == id && (c.title != title || c.subtitle != content)) {
                c.title = title;
                c.subtitle = content;
                added = true;
              }
            }
          }
          continue;
        }
        if (existingTitles.contains(title.toLowerCase())) continue;
        list(listName).add(SgCard(
          id: id,
          title: title,
          subtitle: content,
          tag: SgCard._inferTag(title),
          coverAsset: SgCard._inferCover(id),
          dueDate: 'Synced',
          done: item['done'] == true,
        ));
        existingIds.add(id);
        existingTitles.add(title.toLowerCase());
        added = true;
      }
      if (added) await _save();
    } catch (_) {}
  }

  Future<void> _save() async {
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode({for (final e in _lists.entries) e.key: [for (final c in e.value) c.toJson()]}));
      await prefs.setStringList(_dismissedKey, _dismissedIds.toList());
    } catch (_) {}
  }

  SgCard add(String listName, String title, {String? subtitle, String? tag}) {
    final id = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final c = SgCard(
      id: id,
      title: title.trim(),
      subtitle: subtitle ?? 'Tap card to edit details or drag between columns.',
      tag: tag ?? SgCard._inferTag(title),
      coverAsset: SgCard._inferCover(id),
      dueDate: 'Today',
    );
    list(listName).insert(0, c);
    _save();
    return c;
  }

  void update(SgCard c, {String? title, String? subtitle, bool? done}) {
    if (title != null) c.title = title;
    if (subtitle != null) c.subtitle = subtitle;
    if (done != null) c.done = done;
    _save();
  }

  void remove(SgCard c) {
    _dismissedIds.add(c.id);
    for (final l in _lists.values) {
      l.remove(c);
    }
    _save();
  }

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
    if (from == listName && fromIndex >= 0 && fromIndex < at) at -= 1;
    to.insert(at.clamp(0, to.length), c);
    if (listName == 'Low') c.done = true;
    _save();
  }
}

void unawaited(Future<void> f) {}
