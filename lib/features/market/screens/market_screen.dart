import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api/collider_api.dart';
import '../../../core/drafts.dart';
import '../../../core/media/video_window.dart';
import '../../../core/vision/vision_kit.dart';
import '../../media/generations_pane.dart' show BreathingTile;
import '../../media/picture_viewer.dart';

/// Discover Market — Media Generation & Discovery feed (PRD §5.2, Surfaces Row 5, R25–R28, R54–R56):
/// Top row of featured pictures/videos, a row of Title-Cased Labeled Looks, and the 2-column Imagine feed below.
/// Strictly separated from live wallpapers. No internal EdgeFade inside the physical VGlass window.
class MarketScreen extends StatefulWidget {
  final VoidCallback onClose;
  final String view; // 'discover' or 'gallery'
  final ValueChanged<String> onCreate;
  final ValueChanged<String> onRemix;

  const MarketScreen({
    super.key,
    required this.onClose,
    required this.onCreate,
    required this.onRemix,
    this.view = 'discover',
  });

  @override
  State<MarketScreen> createState() => _MarketScreenState();
}

class _Item {
  final String id;
  final String title;
  final String look;
  final String model;
  final String url;
  final String? videoUrl;
  final double aspect;
  final String? fileRef;
  final bool featured;
  const _Item({
    required this.id,
    required this.title,
    required this.look,
    required this.model,
    required this.url,
    this.videoUrl,
    required this.aspect,
    this.fileRef,
    this.featured = false,
  });
}

const List<String> _labeledLooks = [
  'All Looks',
  'Cinematic',
  'Architectural',
  'Iridescent Glass',
  'Bioluminescent',
  'Editorial Art',
];

/// Curated editorial photography & community renders for Discover Market (R27, D2: Images only).
const List<_Item> _curatedShowcase = [
  _Item(
    id: 'dm_01',
    title: 'Architectural Glass Pavilion at Dusk',
    look: 'Architectural',
    model: 'FLUX.2 Pro',
    url: 'https://images.unsplash.com/photo-1513694203232-719a280e022f?auto=format&fit=crop&w=900&q=80',
    aspect: 3 / 4,
    featured: true,
  ),
  _Item(
    id: 'dm_02',
    title: 'Iridescent Fluid Refraction Study',
    look: 'Iridescent Glass',
    model: 'FLUX.2 Dev',
    url: 'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?auto=format&fit=crop&w=900&q=80',
    aspect: 3 / 4,
    featured: true,
  ),
  _Item(
    id: 'dm_04',
    title: 'Bioluminescent Deep Sea Jellyfish',
    look: 'Bioluminescent',
    model: 'Seedream 5.0',
    url: 'https://images.unsplash.com/photo-1544551763-46a013bb70d5?auto=format&fit=crop&w=900&q=80',
    aspect: 3 / 4,
    featured: true,
  ),
  _Item(
    id: 'dm_03',
    title: 'Minimalist Ceramic Vessel Composition',
    look: 'Editorial Art',
    model: 'Seedream 5.0',
    url: 'https://images.unsplash.com/photo-1578749556568-bc2c40e68b61?auto=format&fit=crop&w=900&q=80',
    aspect: 3 / 4,
    featured: true,
  ),
  _Item(
    id: 'dm_06',
    title: 'Prismatic Light Dispersion on Obsidian',
    look: 'Iridescent Glass',
    model: 'FLUX.2 Dev',
    url: 'https://images.unsplash.com/photo-1550684848-fac1c5b4e853?auto=format&fit=crop&w=900&q=80',
    aspect: 3 / 4,
  ),
  _Item(
    id: 'dm_07',
    title: 'Macro Crystalline Mineral Formation',
    look: 'Cinematic',
    model: 'FLUX.2 Pro',
    url: 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?auto=format&fit=crop&w=900&q=80',
    aspect: 3 / 4,
  ),
  _Item(
    id: 'dm_08',
    title: 'Kinetic Light Sculpture in Dark Studio',
    look: 'Cinematic',
    model: 'FLUX.2 Pro',
    url: 'https://images.unsplash.com/photo-1508739773434-c26b3d09e071?auto=format&fit=crop&w=900&q=80',
    aspect: 3 / 4,
  ),
  _Item(
    id: 'dm_09',
    title: 'Aerial Glacial River Delta Patterns',
    look: 'Cinematic',
    model: 'Seedream 5.0',
    url: 'https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?auto=format&fit=crop&w=900&q=80',
    aspect: 3 / 4,
  ),
  _Item(
    id: 'dm_10',
    title: 'Anodized Titanium Industrial Concept',
    look: 'Architectural',
    model: 'FLUX.2 Pro',
    url: 'https://images.unsplash.com/photo-1526374965328-7f61d4dc18c5?auto=format&fit=crop&w=900&q=80',
    aspect: 3 / 4,
  ),
  _Item(
    id: 'dm_11',
    title: 'Sculpted Marble Portico Shadows',
    look: 'Architectural',
    model: 'Seedream 5.0',
    url: 'https://images.unsplash.com/photo-1513519245088-0e12902e5a38?auto=format&fit=crop&w=900&q=80',
    aspect: 3 / 4,
  ),
  _Item(
    id: 'dm_12',
    title: 'Chromatic Glass Sphere Caustics',
    look: 'Iridescent Glass',
    model: 'FLUX.2 Dev',
    url: 'https://images.unsplash.com/photo-1509198397868-475647b2a1e5?auto=format&fit=crop&w=900&q=80',
    aspect: 3 / 4,
  ),
];

class _MarketScreenState extends State<MarketScreen> {
  static const _savedKey = 'market_saved_v1';
  static final Set<String> _savedCache = {'dm_01', 'dm_02'};
  static bool _savedLoaded = false;
  final Set<String> _saved = {..._savedCache};
  List<Creation> _made = const [];
  Timer? _poll;
  final _text = Drafts.text('discover');
  String _selectedLook = 'All Looks';
  String? _activeVideoUrl;

  @override
  void initState() {
    super.initState();
    _refresh();
    if (!_savedLoaded) {
      SharedPreferences.getInstance().then((p) {
        final stored = p.getStringList(_savedKey);
        if (stored != null && stored.isNotEmpty) {
          _savedCache
            ..clear()
            ..addAll(stored);
        }
        _savedLoaded = true;
        if (mounted) {
          setState(() => _saved
            ..clear()
            ..addAll(_savedCache));
        }
      });
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    final list = await ColliderApi.instance.creations();
    if (!mounted) return;
    setState(() => _made = list);
    _poll?.cancel();
    if (list.any((c) => c.making)) _poll = Timer(const Duration(seconds: 3), _refresh);
  }

  List<_Item> get _items {
    final api = ColliderApi.instance;
    final out = <_Item>[
      for (final c in _made)
        if (c.kind == 'image' && c.status == 'done')
          for (final m in c.media)
            if (m['kind'] != 'video')
              _Item(
                id: 'c:${m['name']}',
                title: c.text.isNotEmpty ? c.text : '${m['name']}',
                look: 'Cinematic',
                model: c.label.isNotEmpty ? c.label : 'FLUX.2',
                url: api.fileUrl(ColliderFile('${m['name']}', 'generated', 0, DateTime.now(), 'image', '${m['url']}')),
                aspect: (m['width'] is num && m['height'] is num && (m['height'] as num) > 0)
                    ? (m['width'] as num) / (m['height'] as num)
                    : 3 / 4,
                fileRef: 'generated/${m['name']}',
                featured: true,
              ),
      ..._curatedShowcase,
    ];
    final byView = widget.view == 'gallery' ? [for (final i in out) if (_saved.contains(i.id)) i] : out;
    if (_selectedLook == 'All Looks') return byView;
    return [for (final i in byView) if (i.look == _selectedLook) i];
  }

  Future<void> _toggleSaveId(String id) async {
    setState(() {
      if (_saved.contains(id)) {
        _saved.remove(id);
        _savedCache.remove(id);
      } else {
        _saved.add(id);
        _savedCache.add(id);
      }
    });
    (await SharedPreferences.getInstance()).setStringList(_savedKey, _saved.toList()..sort());
  }

  Future<void> _save(ViewedPicture p) => _toggleSaveId(p.id);

  Future<String?> _ref(ViewedPicture p) async {
    if (p.fileRef != null) return p.fileRef;
    final name = await ColliderApi.instance.download(p.url);
    return name == null ? null : 'downloaded/$name';
  }

  void _open(List<_Item> items, int i) {
    final clicked = items[i];
    if (clicked.videoUrl != null) {
      setState(() => _activeVideoUrl = clicked.videoUrl);
      return;
    }
    final pics = [
      for (final it in items)
        ViewedPicture(
          id: it.id,
          url: it.url,
          aspect: it.aspect,
          fileRef: it.fileRef,
        ),
    ];
    showGeneralDialog(
      context: context,
      barrierColor: Colors.transparent,
      pageBuilder: (ctx, _, __) => PictureViewer(
        pictures: pics,
        start: i,
        saved: _saved,
        onSave: _save,
        onFiles: (p) async {
          if (p.fileRef == null) await ColliderApi.instance.download(p.url);
        },
        onRemix: (p) async {
          final ref = await _ref(p);
          if (ref == null) return;
          if (ctx.mounted) Navigator.of(ctx).pop();
          widget.onRemix(ref);
        },
        onClose: () => Navigator.of(ctx).pop(),
      ),
    );
  }

  void _send() {
    final t = _text.text.trim();
    if (t.isEmpty) return;
    Drafts.sent('discover');
    widget.onCreate(t);
  }

  Widget _buildFeaturedRow(List<_Item> featured) {
    if (featured.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 112,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: VSpace.sm),
        itemCount: featured.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final it = featured[i];
          return VPress(
            onTap: () => _open(featured, i),
            child: SizedBox(
              width: 156,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      it.url,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const ColoredBox(color: Color(0x22FFFFFF)),
                    ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.72)],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 8,
                      right: 8,
                      bottom: 7,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(it.model, maxLines: 1, style: VType.caption(color: VColors.accentCyan, weight: FontWeight.w600).copyWith(fontSize: 9.5)),
                          Text(it.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: VType.body(color: Colors.white, weight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLabeledLooksRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 6),
      child: SizedBox(
        height: 30,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: VSpace.sm),
          itemCount: _labeledLooks.length,
          separatorBuilder: (_, __) => const SizedBox(width: 6),
          itemBuilder: (_, i) {
            final look = _labeledLooks[i];
            final active = _selectedLook == look;
            return VChip(
              label: look,
              selected: active,
              onTap: () => setState(() => _selectedLook = look),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFeed(List<_Item> items, double width) {
    final featured = _curatedShowcase.where((i) => i.featured).toList();
    const cols = 2; // R27 & D2: "a row of pictures, a row of labeled looks, then a two-column feed of made images."
    const gap = 8.0;
    final colW = (width - 24 - gap * (cols - 1)) / cols;
    final px = (colW * MediaQuery.devicePixelRatioOf(context)).round().clamp(240, 720);

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        if (widget.view == 'discover')
          SliverToBoxAdapter(
            child: _buildFeaturedRow(featured),
          ),
        SliverToBoxAdapter(
          child: _buildLabeledLooksRow(),
        ),
        if (items.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Text(
                'No media items in this look yet.',
                textAlign: TextAlign.center,
                style: VType.body(color: VColors.textTertiary),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(VSpace.sm, 4, VSpace.sm, VSpace.sm),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                mainAxisSpacing: gap,
                crossAxisSpacing: gap,
                childAspectRatio: 3 / 4,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final it = items[index];
                  final isSaved = _saved.contains(it.id);
                  return VPress(
                    onTap: () => _open(items, index),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(VRadius.row),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.network(
                            it.url,
                            fit: BoxFit.cover,
                            filterQuality: FilterQuality.medium,
                            gaplessPlayback: true,
                            cacheWidth: px,
                            frameBuilder: (_, child, frame, sync) => frame == null && !sync ? const BreathingTile() : child,
                            errorBuilder: (_, __, ___) => const ColoredBox(color: Color(0x22FFFFFF)),
                          ),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                stops: const [0.55, 1.0],
                                colors: [Colors.transparent, Colors.black.withValues(alpha: 0.72)],
                              ),
                            ),
                          ),
                          if (it.videoUrl != null)
                            const Center(
                              child: Icon(Icons.play_circle_fill_rounded, size: 34, color: Colors.white70),
                            ),
                          // Top-right 1-tap Save to My Gallery heart
                          Positioned(
                            top: 6,
                            right: 6,
                            child: GestureDetector(
                              onTap: () => _toggleSaveId(it.id),
                              child: Container(
                                width: 26,
                                height: 26,
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.45),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isSaved ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                  size: 14,
                                  color: isSaved ? const Color(0xFFFF375F) : Colors.white,
                                ),
                              ),
                            ),
                          ),
                          // Bottom caption + 1-tap Remix pill
                          Positioned(
                            left: 8,
                            right: 8,
                            bottom: 7,
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(it.look, maxLines: 1, style: VType.caption(color: VColors.textSecondary).copyWith(fontSize: 9.0)),
                                      Text(it.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: VType.body(color: Colors.white, weight: FontWeight.w500)),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 4),
                                GestureDetector(
                                  onTap: () => widget.onCreate('Remix: ${it.title} (${it.look})'),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: VColors.fillActive,
                                      borderRadius: BorderRadius.circular(VRadius.full),
                                      border: Border.all(color: Colors.white38, width: 0.5),
                                    ),
                                    child: Text('Remix', style: VType.caption(color: Colors.white, weight: FontWeight.w600).copyWith(fontSize: 9.5)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
                childCount: items.length,
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final phone = size.width < 768;
    final w = phone ? (size.width - 68).clamp(260.0, 520.0) : (size.width * 0.62).clamp(560.0, 860.0);
    final h = (size.height * 0.66).clamp(360.0, 640.0);
    final items = _items;

    if (_activeVideoUrl != null) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 76),
          child: VideoWindow(
            url: _activeVideoUrl!,
            onClose: () => setState(() => _activeVideoUrl = null),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, box) {
        final availH = (box.maxHeight - 58).clamp(200.0, 640.0);
        return Padding(
          padding: EdgeInsets.fromLTRB(phone ? 52 : 0, 4, 0, 4),
          child: Center(
            child: SizedBox(
              width: w,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: availH,
                    child: VGlass(
                      material: VMaterial.work,
                      radius: VRadius.card,
                      padding: const EdgeInsets.only(top: VSpace.sm),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(VSpace.md, 0, VSpace.sm, VSpace.xs),
                            child: SizedBox(
                              height: 32,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Positioned.fill(
                                    left: 36,
                                    right: 36,
                                    child: Center(
                                      child: Text(
                                        widget.view == 'gallery' ? 'My Gallery (${items.length})' : 'Discover Market',
                                        textAlign: TextAlign.center,
                                        style: VType.headline(),
                                      ),
                                    ),
                                  ),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: VCircleButton(icon: Icons.close_rounded, size: 30, tooltip: 'Close', onTap: widget.onClose),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Expanded(
                            child: LayoutBuilder(
                              builder: (context, innerBox) => _buildFeed(items, innerBox.maxWidth),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: VSpace.xs),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: phone ? 300.0 : 480.0),
                    child: VGlass(
                      material: VMaterial.elevated,
                      radius: 26,
                      padding: const EdgeInsets.fromLTRB(14, 4, 6, 4),
                      child: Row(
                        children: [
                          const Icon(Icons.auto_awesome_rounded, size: 16, color: VColors.textSecondary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _text,
                              minLines: 1,
                              maxLines: 3,
                              cursorColor: VColors.textPrimary,
                              textInputAction: TextInputAction.send,
                              onSubmitted: (_) => _send(),
                              style: VType.body(weight: FontWeight.w500),
                              decoration: InputDecoration(
                                hintText: 'Create or remix media...',
                                hintStyle: VType.body(color: const Color(0x99FFFFFF), weight: FontWeight.w400),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          VCircleButton(icon: Icons.arrow_upward_rounded, size: 32, selected: true, onTap: _send),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
