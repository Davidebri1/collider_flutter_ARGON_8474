// Collider API client. Made by Claude.
// Talks only to the local Collider server (tools/collider_server.py), which holds the keys.
import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../models/model_def.dart';

enum AskMode { chat, internet, research, deep }

extension AskModeX on AskMode {
  String get wire => switch (this) {
        AskMode.chat => 'chat',
        AskMode.internet => 'internet',
        AskMode.research => 'research',
        AskMode.deep => 'deep',
      };
  String get label => switch (this) {
        AskMode.chat => 'Chat',
        AskMode.internet => 'Internet',
        AskMode.research => 'Research',
        AskMode.deep => 'Deep Research',
      };
  String get outcome => switch (this) {
        AskMode.chat => 'A direct answer',
        AskMode.internet => 'An answer from live web sources',
        AskMode.research => 'A research report with sources',
        AskMode.deep => 'An annotated research paper',
      };
  IconData get icon => switch (this) {
        AskMode.chat => Icons.chat_bubble_outline_rounded,
        AskMode.internet => Icons.public_rounded,
        AskMode.research => Icons.article_outlined,
        AskMode.deep => Icons.auto_stories_outlined,
      };
}

class ModelResult {
  final String status; // pending | done | error
  final String text;
  final String essence;
  final String? error;
  final String line; // the complete answer on one line that fits the ticker row
  const ModelResult(this.status, this.text, this.essence, this.error, [this.line = '']);
  factory ModelResult.fromJson(Map<String, dynamic> j) => ModelResult(
        j['status'] as String? ?? 'pending',
        j['text'] as String? ?? '',
        j['essence'] as String? ?? '',
        j['error'] as String?,
        j['line'] as String? ?? '',
      );
}

class ConsensusResult {
  final String status; // pending | done | unavailable
  final String summary;
  final String score;
  final List<String> dissent;
  final String need;
  final List<List<String>> groups;
  final Map<String, int> chains;
  final String tieBasis;
  final String line; // the winning group's line, word for word
  const ConsensusResult(this.status, this.summary, this.score, this.dissent, this.need,
      [this.groups = const [], this.chains = const {}, this.tieBasis = '', this.line = '']);
  factory ConsensusResult.fromJson(Map<String, dynamic>? j) => ConsensusResult(
        j?['status'] as String? ?? 'pending',
        j?['summary'] as String? ?? '',
        j?['score'] as String? ?? '',
        ((j?['dissent'] as List?) ?? const []).map((e) => '$e').toList(),
        j?['need'] as String? ?? '',
        [for (final g in (j?['groups'] as List?) ?? const []) [for (final m in g as List) '$m']],
        {for (final e in ((j?['chains'] as Map?) ?? const {}).entries) '${e.key}': (e.value as num).toInt()},
        j?['tie_basis'] as String? ?? '',
        j?['line'] as String? ?? '',
      );
}

class JobState {
  final String id;
  final String prompt;
  final String mode;
  final String stage;
  final bool done;
  final Map<String, ModelResult> results;
  final ConsensusResult consensus;
  final List<Map<String, dynamic>> sources;
  final DateTime created;
  const JobState(this.id, this.prompt, this.mode, this.stage, this.done, this.results, this.consensus, this.sources, this.created);
  factory JobState.fromJson(Map<String, dynamic> j) => JobState(
        j['id'] as String,
        j['prompt'] as String? ?? '',
        j['mode'] as String? ?? 'chat',
        j['stage'] as String? ?? '',
        (j['status'] ?? 'done') == 'done',
        ((j['results'] as Map?) ?? {}).map((k, v) => MapEntry('$k', ModelResult.fromJson(Map<String, dynamic>.from(v as Map)))),
        ConsensusResult.fromJson(j['consensus'] == null ? null : Map<String, dynamic>.from(j['consensus'] as Map)),
        ((j['sources'] as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList(),
        DateTime.fromMillisecondsSinceEpoch((((j['created'] as num?) ?? 0) * 1000).toInt()),
      );
}

/// One entry in Files. Sources: uploaded, generated, purchased, downloaded.
class ColliderFile {
  final String name;
  final String source;
  final int size; // bytes; 0 when unknown (bundled purchases)
  final DateTime modified;
  final String kind; // image | audio | video | pdf | text | file
  final String url; // server path, or a bundled asset path when [asset] is true
  final bool asset;
  const ColliderFile(this.name, this.source, this.size, this.modified, this.kind, this.url, {this.asset = false});
  factory ColliderFile.fromJson(Map<String, dynamic> j) => ColliderFile(
        j['name'] as String,
        j['source'] as String,
        (j['size'] as num?)?.toInt() ?? 0,
        DateTime.fromMillisecondsSinceEpoch((((j['modified'] as num?) ?? 0) * 1000).toInt()),
        j['kind'] as String? ?? 'file',
        j['url'] as String,
      );
}

class ColliderApi {
  ColliderApi._();
  static final ColliderApi instance = ColliderApi._();
  final Dio _dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 8), receiveTimeout: const Duration(seconds: 180)));

  String get _base => Uri.base.origin;
  bool online = false;
  bool webSearch = false;
  int nvidiaKeys = 0;

  static Color _hex(String h) => Color(int.parse('FF${h.replaceAll('#', '')}', radix: 16));

  /// Loads the live roster from the server into [ModelRoster]. Returns true when connected.
  Future<bool> loadRoster() async {
    try {
      final r = await _dio.get('$_base/api/models');
      final list = (r.data['models'] as List).cast<Map>();
      webSearch = r.data['search'] == true;
      nvidiaKeys = (r.data['keys'] as num?)?.toInt() ?? 0;
      ModelRoster.setLive([
        for (final m in list)
          ModelDef(
            id: m['id'] as String,
            label: m['label'] as String,
            short: m['short'] as String,
            desc: m['provider'] as String,
            tier: ModelTier.free,
            categories: const [ModelCategory.general],
            providerColor: _hex(m['color'] as String),
          ),
      ]);
      online = true;
    } catch (_) {
      online = false;
    }
    return online;
  }

  /// Files the server holds: uploaded, generated, downloaded (purchases are bundled with the app).
  Future<Map<String, List<ColliderFile>>> files() async {
    try {
      final r = await _dio.get('$_base/api/files');
      return {
        for (final e in (r.data as Map).entries)
          '${e.key}': [for (final f in e.value as List) ColliderFile.fromJson(Map<String, dynamic>.from(f as Map))],
      };
    } catch (_) {
      return const {};
    }
  }

  /// Full address of a file for viewing.
  String fileUrl(ColliderFile f) => f.asset ? '$_base/assets/${f.url}' : '$_base${f.url}';

  Future<String> fileText(ColliderFile f) async {
    final r = await _dio.get<String>(fileUrl(f), options: Options(responseType: ResponseType.plain));
    return r.data ?? '';
  }

  /// Stores an upload in Files and returns the name it was saved under.
  Future<String?> uploadFile(String name, List<int> bytes) async {
    try {
      final r = await _dio.post('$_base/api/files/upload', data: {'name': name, 'b64': base64Encode(bytes)});
      return r.data['name'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// Saves model output as a file in Files > Generated.
  Future<String?> saveGenerated(String name, String text) async {
    try {
      final r = await _dio.post('$_base/api/files/generated', data: {'name': name, 'text': text});
      return r.data['name'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// Saves whatever is at [url] in Files > Downloaded.
  Future<String?> download(String url) async {
    try {
      final r = await _dio.post('$_base/api/files/download', data: {'url': url});
      return r.data['name'] as String?;
    } catch (_) {
      return null;
    }
  }

  Future<String> ask({required String prompt, required List<String> models, required AskMode mode, required bool autosave, required bool incognito, List<String> attachments = const [], int line = 28}) async {
    final r = await _dio.post('$_base/api/ask', data: {
      'line': line,
      'prompt': prompt,
      'attachments': attachments,
      'models': models,
      'mode': mode.wire,
      'autosave': autosave,
      'incognito': incognito,
    });
    return r.data['id'] as String;
  }

  /// Polls a job until done, emitting each state.
  Stream<JobState> watch(String id) async* {
    while (true) {
      final r = await _dio.get('$_base/api/job/$id');
      final s = JobState.fromJson(Map<String, dynamic>.from(r.data as Map));
      yield s;
      if (s.done) return;
      await Future.delayed(const Duration(milliseconds: 1200));
    }
  }

  Future<({String text, String line})> reply({required String model, required List<Map<String, String>> messages, required AskMode mode, List<String> attachments = const [], int line = 28}) async {
    final r = await _dio.post('$_base/api/reply', data: {'model': model, 'messages': messages, 'mode': mode.wire, 'attachments': attachments, 'line': line});
    return (text: r.data['text'] as String, line: r.data['line'] as String? ?? '');
  }

  /// One-line forms for a saved conversation that has none, or has them for a wider row.
  Future<JobState?> lines(String id, int line) async {
    try {
      final r = await _dio.post('$_base/api/lines', data: {'id': id, 'line': line});
      final m = Map<String, dynamic>.from(r.data as Map);
      if (m['error'] != null) return null;
      return JobState.fromJson({...m, 'status': 'done'});
    } catch (_) {
      return null;
    }
  }

  Future<List<JobState>> history() async {
    try {
      final r = await _dio.get('$_base/api/history');
      return [
        for (final s in (r.data['sessions'] as List)) JobState.fromJson({...Map<String, dynamic>.from(s as Map), 'status': 'done'}),
      ];
    } catch (_) {
      return const [];
    }
  }
}
