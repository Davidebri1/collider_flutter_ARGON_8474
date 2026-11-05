// Files. Made by Claude.
// Layout and styling from Figma: Nimo Spatial OS Design System, node 2012-218019 (file browser).
// Files holds four sources: what was uploaded, generated, purchased and downloaded.
// The tiles at the top are those four places. The side menu sorts the same files another way, by kind
// (David, 4 Oct 2026: "the side nav bar is just duplicating your top area ... how about filetype").
// Purchased holds the songs that came with the live wallpapers that were bought; the wallpapers themselves
// live in the app (David: "the live wallpapers are for in app use only ... here, you can put music").
// A song plays in the music bar.
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/api/collider_api.dart';
import '../../../core/audio/music_player.dart';
import '../../../core/platform/open_url.dart';
import '../../../core/vision/vision_kit.dart';
import '../../../models/theme_def.dart';
import '../../theme/theme_pack_store.dart';

/// Colours taken from the Figma frame.
class _N {
  static const titleBar = Color(0xFFFFFFFF);
  static const body = Color(0xFFE1E8EB);
  static const card = Color(0xFFF2F5F7);
  static const chip = Color(0xFFEFEFF2);
  static const chipOn = Color(0xFF363940);
  static const title = Color(0xFF464652);
  static const label = Color(0xFF373A44);
  static const count = Color(0xFFB3B3B3);
  static const hint = Color(0xFF7F7F7F);

  static TextStyle text(double size, FontWeight w, Color c, {double? height}) =>
      GoogleFonts.inter(fontSize: size, fontWeight: w, color: c, height: height, decoration: TextDecoration.none);
}

class _Source {
  final String key;
  final String label;
  final IconData icon;
  final List<Color> colors;
  const _Source(this.key, this.label, this.icon, this.colors);
}

const _home = _Source('home', 'Home', Icons.home_rounded, [Color(0xFF5CA194), Color(0xFF5BC7B1)]);
const _sources = [
  _Source('uploaded', 'Uploaded', Icons.upload_rounded, [Color(0xFF338C97), Color(0xFF4AC3DA)]),
  _Source('generated', 'Generated', Icons.article_rounded, [Color(0xFF2E5FC1), Color(0xFF6489DF)]),
  _Source('purchased', 'Purchased', Icons.shopping_bag_rounded, [Color(0xFF7C56C7), Color(0xFFAF83DF)]),
  _Source('downloaded', 'Downloaded', Icons.download_rounded, [Color(0xFF2C9472), Color(0xFF2EC68E)]),
];

/// The kinds of file, for the side menu. Glyphs and colours are the frame's.
const _kinds = [
  _Source('documents', 'Documents', Icons.insert_drive_file_rounded, [Color(0xFF338C97), Color(0xFF4AC3DA)]),
  _Source('images', 'Images', Icons.image_rounded, [Color(0xFF2E5FC1), Color(0xFF6489DF)]),
  _Source('music', 'Music', Icons.music_note_rounded, [Color(0xFFD65983), Color(0xFFD8789F)]),
  _Source('videos', 'Videos', Icons.videocam_rounded, [Color(0xFF7C56C7), Color(0xFFAF83DF)]),
];
_Source _sourceOf(String key) => [..._sources, ..._kinds].firstWhere((s) => s.key == key, orElse: () => _home);

bool _isKind(String place, ColliderFile f) => switch (place) {
      'images' => f.kind == 'image',
      'music' => f.kind == 'audio',
      'videos' => f.kind == 'video',
      'documents' => f.kind != 'image' && f.kind != 'audio' && f.kind != 'video',
      _ => true,
    };

/// One place in the browser: Home, a source, or an opened file.
class _View {
  final String source;
  final ColliderFile? file;
  const _View(this.source, [this.file]);
}

class FilesScreen extends StatefulWidget {
  final VoidCallback onClose;

  /// Where it opens: 'home', or 'music' when the Music Player is asked for.
  final String initialPlace;
  const FilesScreen({super.key, required this.onClose, this.initialPlace = 'home'});

  @override
  State<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends State<FilesScreen> {
  final _api = ColliderApi.instance;
  final _search = TextEditingController();
  Map<String, List<ColliderFile>> _files = {for (final s in _sources) s.key: const []};
  late final List<_View> _history = [_View(widget.initialPlace)];

  /// Purchased songs: which theme each belongs to and where it stands in that theme's list.
  final Map<ColliderFile, (WallpaperTheme, int)> _songs = {};
  int _at = 0;
  bool _grid = true;
  bool _byName = false;
  String _q = '';
  bool _uploading = false;

  /// The frame's unit on this screen: every space, size and radius below is the frame's number times this.
  double _u = 0.6;

  _View get _view => _history[_at];

  /// Music and Purchased hold songs: a song list is rows of titles, whatever the grid button says elsewhere.
  bool get _songsOnly => _view.file == null && (_view.source == 'music' || _view.source == 'purchased');

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final server = await _api.files();
    await ThemePackStore.instance.init();
    final owned = ThemePackStore.instance.unlocked;
    final never = DateTime.fromMillisecondsSinceEpoch(0);
    final purchased = <ColliderFile>[];
    _songs.clear();
    for (final t in WallpaperCatalog.premiumThemes) {
      // Bought, or free (the bucket's live wallpapers carry no price).
      if (!owned.contains(t.id) && t.priceLabel != null) continue;
      final songs = MusicPlayer.forTheme(t);
      for (int i = 0; i < songs.length; i++) {
        // A song goes by its title; it is not a file the user named.
        final f = ColliderFile(songs[i].title, 'purchased', 0, never, 'audio', songs[i].file, asset: true);
        purchased.add(f);
        _songs[f] = (t, i);
      }
    }
    if (!mounted) return;
    setState(() => _files = {
          'uploaded': server['uploaded'] ?? const [],
          'generated': server['generated'] ?? const [],
          'purchased': purchased,
          'downloaded': server['downloaded'] ?? const [],
        });
  }

  void _go(_View v) {
    // A purchased song plays in the music bar; it does not open as a page.
    final song = v.file == null ? null : _songs[v.file!];
    if (song != null) {
      MusicPlayer.instance.play(song.$2, list: MusicPlayer.forTheme(song.$1), id: song.$1.id);
      return;
    }
    setState(() {
      _history.removeRange(_at + 1, _history.length);
      _history.add(v);
      _at++;
    });
  }

  Future<void> _upload() async {
    try {
      final res = await FilePicker.platform.pickFiles(allowMultiple: true, withData: true);
      if (res == null) return;
      setState(() => _uploading = true);
      for (final f in res.files) {
        if (f.bytes != null) await _api.uploadFile(f.name, f.bytes!);
      }
      await _load();
    } catch (_) {
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  List<ColliderFile> _shown() {
    final v = _view;
    final all = [for (final s in _sources) ...?_files[s.key]];
    var list = v.source == 'home'
        ? all
        : (_kinds.any((k) => k.key == v.source) ? all.where((f) => _isKind(v.source, f)).toList() : [...?_files[v.source]]);
    if (_q.isNotEmpty) list = list.where((f) => f.name.toLowerCase().contains(_q)).toList();
    if (_byName) {
      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    } else {
      // newest first; files with no date (the songs) keep the order they came in
      final order = {for (int i = 0; i < list.length; i++) list[i]: i};
      list.sort((a, b) {
        final c = b.modified.compareTo(a.modified);
        return c != 0 ? c : order[a]!.compareTo(order[b]!);
      });
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final compact = size.width < 768;
    return LayoutBuilder(builder: (context, box) {
      // Frame: the side menu is 66 wide and lies 4 over the window's left edge; the window starts 15.2% down
      // the screen and is 54.6% of its height. u is the frame's unit on this screen.
      const rail = 44.0;
      final overlap = compact ? 4 * (box.maxWidth - 8 - rail - 10) / 576 : 6.0;
      final winW = compact ? box.maxWidth - 24 - (rail - overlap) - 24 : (box.maxWidth - 120).clamp(420.0, 880.0);
      _u = compact ? winW / 576 : 0.62;
      final winH = compact ? size.height * 919 / 1684 : (box.maxHeight * 0.74).clamp(380.0, 614.0);
      final railH = 2 * 20 * _u + (_kinds.length + 1) * 30 + _kinds.length * 16 * _u;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onClose,
        child: Align(
          alignment: compact ? Alignment.topLeft : Alignment.center,
          child: Padding(
            padding: EdgeInsets.only(left: compact ? 24 : 0, top: compact ? size.height * 256 / 1684 : 0),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              builder: (_, t, child) => Opacity(opacity: t, child: Transform.scale(scale: 0.96 + 0.04 * t, child: child)),
              child: GestureDetector(
                onTap: () {},
                child: SizedBox(
                  width: winW + rail - overlap,
                  height: winH,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(left: rail - overlap, top: 0, right: 0, bottom: 0, child: _window(compact)),
                      Positioned(left: 0, top: (winH - railH) / 2, child: _sideMenu()),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _window(bool compact) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Color(0x4D000000), blurRadius: 30, offset: Offset(0, 14))],
      ),
      child: Column(
        children: [
          _titleBar(compact),
          Expanded(
            child: Container(
              width: double.infinity,
              color: _N.body,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: KeyedSubtree(
                  key: ValueKey('${_view.source}|${_view.file?.url}|${_grid && !_songsOnly}'),
                  child: _view.file != null ? _preview(_view.file!) : _browse(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- title bar ----------------
  Widget _titleBar(bool compact) {
    final title = _view.file?.name ?? _sourceOf(_view.source).label;
    final nav = Row(mainAxisSize: MainAxisSize.min, children: [
      _RoundButton(icon: Icons.chevron_left_rounded, enabled: _at > 0, tooltip: 'Back', onTap: () => setState(() => _at--)),
      const SizedBox(width: 6),
      _RoundButton(icon: Icons.chevron_right_rounded, enabled: _at < _history.length - 1, tooltip: 'Forward', onTap: () => setState(() => _at++)),
    ]);
    final actions = Row(mainAxisSize: MainAxisSize.min, children: [
      if (!_songsOnly) ...[
        _SquareButton(icon: _grid ? Icons.grid_view_rounded : Icons.view_list_rounded, on: true, tooltip: _grid ? 'Grid' : 'List', onTap: () => setState(() => _grid = !_grid)),
        const SizedBox(width: 6),
      ],
      _SquareButton(icon: Icons.swap_vert_rounded, on: _byName, tooltip: _byName ? 'By name' : 'Newest first', onTap: () => setState(() => _byName = !_byName)),
      const SizedBox(width: 6),
      _SquareButton(icon: _uploading ? Icons.more_horiz_rounded : Icons.upload_rounded, tooltip: 'Upload', onTap: _uploading ? null : _upload),
      const SizedBox(width: 6),
      _SquareButton(icon: Icons.close_rounded, tooltip: 'Close', onTap: widget.onClose),
    ]);
    final search = Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(color: const Color(0x0F000000), borderRadius: BorderRadius.circular(16)),
      child: Row(children: [
        const Icon(Icons.search_rounded, size: 17, color: _N.hint),
        const SizedBox(width: 6),
        Expanded(
          child: TextField(
            controller: _search,
            onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
            cursorColor: _N.title,
            style: _N.text(13, FontWeight.w400, _N.title),
            decoration: InputDecoration(
              hintText: 'Search',
              hintStyle: _N.text(13, FontWeight.w400, _N.hint.withValues(alpha: 0.6)),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
      ]),
    );
    final name = Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: _N.text(17, FontWeight.w600, _N.title));
    return Container(
      color: _N.titleBar,
      padding: EdgeInsets.all(20 * _u),
      child: compact
          ? Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [nav, SizedBox(width: 15 * _u), Expanded(child: name), SizedBox(width: 15 * _u), actions]),
              SizedBox(height: 20 * _u),
              search,
            ])
          : Row(children: [
              Expanded(child: Row(children: [nav, const SizedBox(width: 12), Flexible(child: name)])),
              SizedBox(width: 240, child: search),
              Expanded(child: Align(alignment: Alignment.centerRight, child: actions)),
            ]),
    );
  }

  // ---------------- browse: source cards, then the files ----------------
  Widget _browse() {
    final home = _view.source == 'home';
    final list = _shown();
    return ShaderMask(
      // the list fades out at the bottom edge, as in the Figma frame
      blendMode: BlendMode.dstIn,
      shaderCallback: (r) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.white, Colors.white, Colors.transparent],
        stops: [0, 0.9, 1],
      ).createShader(r),
      child: ListView(
        padding: EdgeInsets.fromLTRB(20 * _u, 20 * _u, 20 * _u, 28),
        physics: const BouncingScrollPhysics(),
        children: [
          if (home) ...[
            Row(children: [
              for (int i = 0; i < _sources.length; i++) ...[
                if (i > 0) SizedBox(width: 20 * _u),
                Expanded(child: _SourceCard(u: _u, source: _sources[i], onTap: () => _go(_View(_sources[i].key)))),
              ],
            ]),
            SizedBox(height: 30 * _u),
            // The frame's line and heading stand over a list; with nothing to list they are left out.
            if (list.isNotEmpty) ...[
              Container(height: 1, color: Colors.white),
              SizedBox(height: 30 * _u),
              Text('Recents', style: _N.text(17, FontWeight.w600, _N.title)),
              SizedBox(height: 30 * _u),
            ],
          ],
          if (_grid && !_songsOnly)
            LayoutBuilder(builder: (context, c) {
              // frame: cells 68 wide, 50 apart; here the cell follows the type (68 x 0.79) and the gap takes the rest
              final cols = ((c.maxWidth + 50 * _u) / (54 + 50 * _u)).floor().clamp(3, 12);
              final w = c.maxWidth / cols;
              return Wrap(
                runSpacing: 30 * _u,
                children: [for (final f in list) SizedBox(width: w, child: _FileCell(file: f, api: _api, onTap: () => _go(_View(_view.source, f))))],
              );
            })
          else
            Column(children: [
              for (final f in list)
                if (_songs[f] case final song?)
                  _SongRow(title: f.name, theme: song.$1, index: song.$2, onTap: () => _go(_View(_view.source, f)))
                else
                  _FileRow(file: f, api: _api, onTap: () => _go(_View(_view.source, f))),
            ]),
        ],
      ),
    );
  }

  // ---------------- an opened file ----------------
  Widget _preview(ColliderFile f) {
    if (f.kind == 'image') {
      return Padding(
        padding: const EdgeInsets.all(14),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: f.asset ? Image.asset(f.url, fit: BoxFit.contain) : Image.network(_api.fileUrl(f), fit: BoxFit.contain),
        ),
      );
    }
    if (f.kind == 'text') {
      return FutureBuilder<String>(
        future: _api.fileText(f),
        builder: (_, snap) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          physics: const BouncingScrollPhysics(),
          child: SelectableText(snap.data ?? '', style: _N.text(13, FontWeight.w400, _N.label, height: 1.5)),
        ),
      );
    }
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        _Thumb(file: f, api: _api, width: 96),
        const SizedBox(height: 14),
        VPress(
          onTap: () => openUrl(_api.fileUrl(f)),
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(color: _N.chipOn, borderRadius: BorderRadius.circular(12)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.open_in_new_rounded, size: 16, color: Colors.white),
              const SizedBox(width: 8),
              Text('Open', style: _N.text(13, FontWeight.w600, Colors.white)),
            ]),
          ),
        ),
      ]),
    );
  }

  // ---------------- side menu: Home and the kinds of file ----------------
  Widget _sideMenu() {
    final active = _view.source;
    return Container(
      width: 44,
      padding: EdgeInsets.symmetric(vertical: 20 * _u),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [BoxShadow(color: Color(0x4D000000), blurRadius: 14, offset: Offset(0, 8))],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        for (final s in [_home, ..._kinds]) ...[
          if (s.key != 'home') SizedBox(height: 16 * _u),
          VPress(
            tooltip: s.label,
            onTap: () {
              if (_view.source != s.key || _view.file != null) _go(_View(s.key));
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 30,
              height: 30,
              decoration: BoxDecoration(color: active == s.key ? _N.chip : Colors.transparent, shape: BoxShape.circle),
              child: Center(child: _GradientIcon(s.icon, s.colors, 19)),
            ),
          ),
        ],
      ]),
    );
  }
}

/// Icon filled with the source's gradient, top to bottom, as the Figma icons are.
class _GradientIcon extends StatelessWidget {
  final IconData icon;
  final List<Color> colors;
  final double size;
  const _GradientIcon(this.icon, this.colors, this.size);

  @override
  Widget build(BuildContext context) => ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (r) => LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: colors).createShader(r),
        child: Icon(icon, size: size, color: Colors.white),
      );
}

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final String tooltip;
  final VoidCallback onTap;
  const _RoundButton({required this.icon, required this.enabled, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) => VPress(
        tooltip: tooltip,
        onTap: enabled ? onTap : null,
        child: Container(
          width: 30,
          height: 30,
          decoration: const BoxDecoration(color: _N.chip, shape: BoxShape.circle),
          child: Icon(icon, size: 20, color: enabled ? _N.title : _N.count),
        ),
      );
}

class _SquareButton extends StatelessWidget {
  final IconData icon;
  final bool on;
  final String tooltip;
  final VoidCallback? onTap;
  const _SquareButton({required this.icon, required this.tooltip, required this.onTap, this.on = false});

  @override
  Widget build(BuildContext context) => VPress(
        tooltip: tooltip,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 30,
          height: 30,
          decoration: BoxDecoration(color: on ? _N.chipOn : _N.chip, borderRadius: BorderRadius.circular(11)),
          child: Icon(icon, size: 17, color: on ? Colors.white : _N.title),
        ),
      );
}

/// Source card: gradient icon top left, name at the bottom. The frame's count line is not carried
/// (David: "no counting").
class _SourceCard extends StatelessWidget {
  final double u;
  final _Source source;
  final VoidCallback onTap;
  const _SourceCard({required this.u, required this.source, required this.onTap});

  @override
  Widget build(BuildContext context) => VPress(
        onTap: onTap,
        child: Container(
          height: 146 * u,
          padding: EdgeInsets.all(12 * u),
          decoration: BoxDecoration(
            color: _N.card,
            borderRadius: BorderRadius.circular(20 * u),
            boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 10, offset: Offset(0, 7))],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _GradientIcon(source.icon, source.colors, 38 * u),
            const Spacer(),
            Text(source.label, maxLines: 1, softWrap: false, overflow: TextOverflow.visible, style: _N.text(9.5, FontWeight.w600, _N.label)),
          ]),
        ),
      );
}

/// Thumbnail: the picture itself for images, otherwise the kind's icon on a tile.
class _Thumb extends StatelessWidget {
  final ColliderFile file;
  final ColliderApi api;
  final double width;
  const _Thumb({required this.file, required this.api, required this.width});

  static const _icons = {
    'audio': (Icons.music_note_rounded, [Color(0xFFD65983), Color(0xFFD8789F)]),
    'video': (Icons.videocam_rounded, [Color(0xFF7C56C7), Color(0xFFAF83DF)]),
    'pdf': (Icons.picture_as_pdf_rounded, [Color(0xFF338C97), Color(0xFF4AC3DA)]),
    'text': (Icons.description_rounded, [Color(0xFF338C97), Color(0xFF4AC3DA)]),
    'file': (Icons.insert_drive_file_rounded, [Color(0xFF90942F), Color(0xFFC7D148)]),
  };

  @override
  Widget build(BuildContext context) {
    final h = width * 48 / 68;
    Widget tile() {
      final (icon, colors) = _icons[file.kind] ?? _icons['file']!;
      return Container(color: _N.card, child: Center(child: _GradientIcon(icon, colors, h * 0.52)));
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: width,
        height: h,
        child: file.kind == 'image'
            ? (file.asset
                ? Image.asset(file.url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => tile())
                : Image.network(api.fileUrl(file), fit: BoxFit.cover, errorBuilder: (_, __, ___) => tile()))
            : tile(),
      ),
    );
  }
}

class _FileCell extends StatelessWidget {
  final ColliderFile file;
  final ColliderApi api;
  final VoidCallback onTap;
  const _FileCell({required this.file, required this.api, required this.onTap});

  /// The name on one line and its ending on the next, so a name never breaks inside a word.
  List<Widget> _name() {
    final dot = file.name.lastIndexOf('.');
    final hasEnding = dot > 0 && file.name.length - dot <= 6;
    final style = _N.text(11, FontWeight.w400, Colors.black, height: 1.27);
    return [
      Text(hasEnding ? file.name.substring(0, dot) : file.name,
          maxLines: hasEnding ? 1 : 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: style),
      if (hasEnding) Text(file.name.substring(dot), maxLines: 1, style: style),
    ];
  }

  @override
  Widget build(BuildContext context) => VPress(
        onTap: onTap,
        tooltip: file.name,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _Thumb(file: file, api: api, width: 54),
            const SizedBox(height: 10),
            ..._name(),
          ]),
        ),
      );
}

/// A song row, as in David's map row 20 (417-6219): the theme's art as the cover, the title, and the theme it comes
/// with under it. The song playing is drawn in the music colour. Made by Claude (2026-10-17).
class _SongRow extends StatelessWidget {
  final String title;
  final WallpaperTheme theme;
  final int index;
  final VoidCallback onTap;
  const _SongRow({required this.title, required this.theme, required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = MusicPlayer.instance;
    return AnimatedBuilder(
      animation: p,
      builder: (_, __) {
        final on = p.queueId == theme.id && p.index == index && p.playing;
        return VPress(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.asset(theme.assetPath, width: 40, height: 40, fit: BoxFit.cover, filterQuality: FilterQuality.medium),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: _N.text(12, FontWeight.w600, on ? const Color(0xFFD65983) : _N.label)),
                  const SizedBox(height: 2),
                  Text(theme.name.replaceAll(RegExp(r'\s*4K$'), '').trim(), maxLines: 1, overflow: TextOverflow.ellipsis, style: _N.text(10, FontWeight.w500, _N.hint)),
                ]),
              ),
            ]),
          ),
        );
      },
    );
  }
}

class _FileRow extends StatelessWidget {
  final ColliderFile file;
  final ColliderApi api;
  final VoidCallback onTap;
  const _FileRow({required this.file, required this.api, required this.onTap});

  static String _size(int b) {
    if (b <= 0) return '';
    if (b < 1024) return '$b B';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
    return '${(b / 1024 / 1024).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final when = file.modified.millisecondsSinceEpoch == 0 ? '' : DateFormat('d MMM, HH:mm').format(file.modified);
    final meta = [_size(file.size), when].where((s) => s.isNotEmpty).join('  ·  ');
    return VPress(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          _Thumb(file: file, api: api, width: 44),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(file.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: _N.text(12, FontWeight.w600, _N.label)),
              if (meta.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(meta, style: _N.text(10, FontWeight.w500, _N.hint)),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}
