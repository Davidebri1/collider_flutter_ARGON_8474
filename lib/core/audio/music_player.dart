// Music player state. Made by Claude.
import 'package:flutter/foundation.dart';
import '../../models/theme_def.dart';
import 'audio_engine_stub.dart' if (dart.library.js_interop) 'audio_engine_web.dart';

class MusicTrack {
  final String title;
  final String art;
  final String file;

  /// The theme this song belongs to, cleaned of the "4K" suffix the catalog
  /// carries. Ingest wrote the SOURCE FILENAME into tracks[].title for
  /// single-clip themes ("0319bbf2-..._1080_hd"), so [title] is an id the user
  /// never sees. This is the real name.
  final String themeName;

  const MusicTrack(this.title, this.art, this.file, {this.themeName = ''});

  /// True when [title] is really an ingest artefact rather than a name: it
  /// carries underscores, a uuid or a media extension. "0_Gold_Glitter_Sparkles"
  /// and "0319bbf2-..._1080_hd" are ids; "Waves at Sunset" is a title.
  static final _uuid = RegExp(r'[0-9a-f]{8}-[0-9a-f]{4}', caseSensitive: false);
  static final _mediaExt = RegExp(r'\.(mp4|mov|webm|m4a|mp3|wav)$', caseSensitive: false);
  static bool looksLikeFilename(String s) => s.contains('_') || _uuid.hasMatch(s) || _mediaExt.hasMatch(s);

  /// The label a row should lead with: the theme's name when the track title
  /// is only a filename, otherwise the track title.
  String get displayTitle =>
      (themeName.isNotEmpty && looksLikeFilename(title)) ? themeName : title;
}

class MusicPlayer extends ChangeNotifier {
  MusicPlayer._() {
    _engine.onEnded = next;
    _engine.onBlocked = () {
      playing = false;
      notifyListeners();
    };
    _engine.onTime = (p, d) {
      position = p;
      duration = d;
      notifyListeners();
    };
  }
  static final MusicPlayer instance = MusicPlayer._();

  /// A theme's songs (WallpaperCatalog.tracksFor), with the theme's picture as the cover. Every song is a recording
  /// in the Cloudflare bucket; the app ships none.
  static List<MusicTrack> forTheme(WallpaperTheme t) => [
        for (final a in WallpaperCatalog.tracksFor(t))
          if (a.audioUrl != null)
            MusicTrack(a.title, t.assetPath, a.audioUrl!,
                themeName: t.name.replaceAll(RegExp(r'\s*4K$'), '').trim()),
      ];

  final AudioEngine _engine = AudioEngine();

  /// What Next and Previous move through, and whose songs they are (a theme id).
  List<MusicTrack> queue = const [];
  String queueId = '';

  /// Individual tracks turned off by the user (PRD R31 / HIG-MC-18: "A track can be turned off on its own. Turning a track off stops that track").
  final Set<String> disabledFiles = {};

  int? index; // null = nothing loaded, widget hidden
  bool playing = false;
  bool muted = false;
  double position = 0; // seconds
  double duration = 0; // seconds, 0 until known

  MusicTrack? get current => index == null ? null : queue[index!];
  double get progress => duration > 0 ? (position / duration).clamp(0.0, 1.0) : 0;

  bool isTrackEnabled(MusicTrack t) => !disabledFiles.contains(t.file);

  /// Turns an individual track on or off. Turning an active track off stops that track immediately.
  void toggleTrack(MusicTrack t) {
    if (disabledFiles.contains(t.file)) {
      disabledFiles.remove(t.file);
    } else {
      disabledFiles.add(t.file);
      if (current?.file == t.file && playing) {
        _engine.stop();
        playing = false;
        position = 0;
      }
    }
    notifyListeners();
  }

  /// Plays track [i] of [list]; with no list, of the current queue.
  void play(int i, {List<MusicTrack>? list, String? id}) {
    if (list != null) {
      queue = list;
      queueId = id ?? '';
    }
    if (queue.isEmpty) return;
    final clamped = i.clamp(0, queue.length - 1);
    final same = index == clamped && list == null;
    index = clamped;
    disabledFiles.remove(queue[index!].file);
    if (!same) position = 0;
    // Flutter web serves bundled assets under /assets/<asset path>; songs from the bucket play from their address.
    final f = queue[index!].file;
    _engine.play(f.startsWith('http') ? f : 'assets/$f');
    playing = true;
    notifyListeners();
  }

  void toggle() {
    if (queue.isEmpty) return;
    if (index == null) return play(0);
    if (playing) {
      _engine.pause();
      playing = false;
      notifyListeners();
    } else {
      play(index!);
    }
  }

  void toggleMute() {
    muted = !muted;
    _engine.setMuted(muted);
    notifyListeners();
  }

  void next() {
    if (queue.isEmpty) return;
    final start = index ?? -1;
    for (int step = 1; step <= queue.length; step++) {
      final candidate = (start + step) % queue.length;
      if (!disabledFiles.contains(queue[candidate].file)) {
        play(candidate);
        return;
      }
    }
    _engine.stop();
    playing = false;
    notifyListeners();
  }

  void previous() {
    if (queue.isEmpty) return;
    final start = index ?? 1;
    for (int step = 1; step <= queue.length; step++) {
      final candidate = (start - step + queue.length) % queue.length;
      if (!disabledFiles.contains(queue[candidate].file)) {
        play(candidate);
        return;
      }
    }
    _engine.stop();
    playing = false;
    notifyListeners();
  }

  /// Moves to a point in the track, 0 to 1.
  void seek(double fraction) {
    if (duration <= 0) return;
    position = duration * fraction.clamp(0.0, 1.0);
    _engine.seek(position);
    notifyListeners();
  }

  void close() {
    _engine.stop();
    index = null;
    playing = false;
    position = 0;
    duration = 0;
    notifyListeners();
  }
}

/// Seconds as m:ss.
String musicTime(double s) => '${s ~/ 60}:${(s.toInt() % 60).toString().padLeft(2, '0')}';
