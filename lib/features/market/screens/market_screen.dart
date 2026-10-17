import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../../core/vision/vision_kit.dart';
import '../../../core/vision/work_surface.dart';
import '../../../models/theme_def.dart';

/// Discover Market. Rebuilt by Claude (2026-10-17) from David's map:
///  - row 21 (Video Platforms on visionOS 203:5891): a feature across the top of the window with its title over the
///    picture and one action under it, a shelf of wide thumbnails under that, and the sections as a floating ornament.
///  - row 19 (417:8630, "video player: we can make it smaller for sure"): a video opens in a small player of its own.
/// Lines nobody gave (the old "Market & Media Studio" title, usage counts, model names, credit prices, the long
/// search hint and the Video Lab blurb) are gone.
class MarketScreen extends StatefulWidget {
  final VoidCallback onClose;
  final Function(String prompt) onUsePrompt;

  const MarketScreen({super.key, required this.onClose, required this.onUsePrompt});

  @override
  State<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends State<MarketScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _imagineCtrl = TextEditingController();
  String _q = '';
  int _tab = 0;
  WallpaperTheme? _playing;

  static const _tabs = ['Prompt Feed', 'Grok Imagine', 'Video Lab', 'My Gallery'];

  static const _prompts = [
    {
      'title': 'Family Financial Security & Term Life Plan',
      'prompt': 'Compare 20-year and 30-year level term insurance policies for two adults in their 30s with young children, detailing independent index investing strategies for the premium difference.',
      'art': 'assets/themes/free/cabin.jpg',
    },
    {
      'title': 'Home Energy Independence & Heat Pump Sizing',
      'prompt': 'Calculate annual kilowatt-hour reductions, tax incentives, and cold-climate heat pump sizing for a 2,200 sq ft home.',
      'art': 'assets/themes/free/garden.jpg',
    },
    {
      'title': 'Sunlit Scandinavian Living Room Concept',
      'prompt': 'Sunlit architectural living room with warm white oak floors, cream linen sofa, floor-to-ceiling panoramic glass facing pine forest, and soft morning ambient light.',
      'art': 'assets/themes/free/dunehall.jpg',
    },
    {
      'title': 'Family Heritage Oral History & Recipe Archive',
      'prompt': 'Step-by-step interview guide to preserve multi-generational family recipes, cultural traditions, and recorded stories into an archival book.',
      'art': 'assets/themes/free/observatory.jpg',
    },
  ];

  static const _gallery = [
    ('Aurora Drift', 'assets/themes/premium/aurora_drift.jpg'),
    ('Ember Fall', 'assets/themes/premium/ember_fall.jpg'),
    ('Nebula Bloom', 'assets/themes/premium/nebula_bloom.jpg'),
    ('Low Tide', 'assets/themes/premium/low_tide.jpg'),
  ];

  List<WallpaperTheme> get _videos => [
        for (final t in WallpaperCatalog.premiumThemes)
          if (t.videoPath != null && (_q.isEmpty || t.name.toLowerCase().contains(_q.toLowerCase()))) t,
      ];

  static String _name(WallpaperTheme t) => t.name.replaceAll(RegExp(r'\s*4K$'), '').trim();

  @override
  void dispose() {
    _searchCtrl.dispose();
    _imagineCtrl.dispose();
    super.dispose();
  }

  void _use(String prompt) {
    if (prompt.trim().isEmpty) return;
    widget.onUsePrompt(prompt);
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        VWorkSurface(
          title: 'Discover Market',
          onClose: widget.onClose,
          search: VSearchField(controller: _searchCtrl, hint: 'Search', onChanged: (v) => setState(() => _q = v.trim())),
          tabs: _tabs,
          activeTab: _tab,
          onTab: (i) => setState(() => _tab = i),
          child: AnimatedSwitcher(
            duration: VMotion.base,
            child: KeyedSubtree(
              key: ValueKey(_tab),
              child: switch (_tab) {
                0 => _feed(),
                1 => _imagine(),
                2 => _videoLab(),
                _ => _galleryGrid(),
              },
            ),
          ),
        ),
        if (_playing != null) Positioned.fill(child: _VideoPlayerPane(theme: _playing!, title: _name(_playing!), onClose: () => setState(() => _playing = null))),
      ],
    );
  }

  // ---------------------------------------------------------------- Prompt Feed (row 21)

  Widget _feed() {
    final q = _q.toLowerCase();
    final items = _prompts.where((p) => q.isEmpty || p['title']!.toLowerCase().contains(q) || p['prompt']!.toLowerCase().contains(q)).toList();
    if (items.isEmpty) return const SizedBox.shrink();
    final hero = items.first;
    final shelf = items.skip(1).toList();
    return VFadeScroll(
      padding: const EdgeInsets.fromLTRB(VSpace.sm, VSpace.xxs, VSpace.sm, VSpace.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _hero(hero),
          if (shelf.isNotEmpty) ...[
            const SizedBox(height: VSpace.sm),
            SizedBox(
              height: 118,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: shelf.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, i) => _shelfCard(shelf[i]),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Row 21's feature: the picture, its title over the lower part, one action under the title.
  Widget _hero(Map<String, String> p) => ClipRRect(
        borderRadius: BorderRadius.circular(VRadius.lg),
        // Row 21's feature takes the top of the window, not all of it: the shelf stays in view under it.
        child: SizedBox(
          height: 180,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(p['art']!, fit: BoxFit.cover),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x00000000), Color(0x8C000000)],
                    stops: [0.4, 1],
                  ),
                ),
              ),
              Positioned(
                left: 14,
                right: 14,
                bottom: 12,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Text(p['title']!, maxLines: 2, overflow: TextOverflow.ellipsis, style: VType.callout(weight: FontWeight.w700).copyWith(fontSize: 15, height: 19 / 15)),
                    ),
                    const SizedBox(width: 10),
                    VPress(
                      onTap: () => _use(p['prompt']!),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0x40FFFFFF)),
                        child: const Icon(Icons.play_arrow_rounded, size: 18, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

  Widget _shelfCard(Map<String, String> p) => VPress(
        onTap: () => _use(p['prompt']!),
        child: SizedBox(
          width: 128,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(VRadius.sm),
                child: Image.asset(p['art']!, width: 128, height: 72, fit: BoxFit.cover),
              ),
              const SizedBox(height: 6),
              Text(p['title']!, maxLines: 2, overflow: TextOverflow.ellipsis, style: VType.caption(color: VColors.textPrimary, weight: FontWeight.w500).copyWith(fontSize: 11.5, height: 15 / 11.5)),
            ],
          ),
        ),
      );

  // ---------------------------------------------------------------- Grok Imagine

  Widget _imagine() => Padding(
        padding: const EdgeInsets.fromLTRB(VSpace.sm, VSpace.xxs, VSpace.sm, VSpace.sm),
        child: Align(
          alignment: Alignment.topCenter,
          child: VRecessed(
            radius: 17,
            padding: const EdgeInsets.fromLTRB(14, 0, 4, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.5),
                    child: TextField(
                      controller: _imagineCtrl,
                      minLines: 1,
                      maxLines: 6,
                      cursorColor: VColors.textPrimary,
                      style: VType.callout(weight: FontWeight.w500).copyWith(fontSize: 13, height: 17 / 13),
                      decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
                      onSubmitted: _use,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: VPress(
                    onTap: () => _use(_imagineCtrl.text),
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: VColors.fillActive),
                      child: const Icon(Icons.arrow_upward_rounded, size: 15, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  // ---------------------------------------------------------------- Video Lab (row 19)

  Widget _videoLab() {
    final vids = _videos;
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth < 420 ? 2 : 3;
      return GridView.builder(
        padding: const EdgeInsets.fromLTRB(VSpace.sm, VSpace.xxs, VSpace.sm, VSpace.sm),
        physics: const BouncingScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: cols, mainAxisSpacing: 4, crossAxisSpacing: 4, childAspectRatio: 1.15),
        itemCount: vids.length,
        itemBuilder: (_, i) => VTile(
          aspect: 16 / 10,
          media: Image.asset(vids[i].assetPath, fit: BoxFit.cover),
          title: _name(vids[i]),
          onTap: () => setState(() => _playing = vids[i]),
        ),
      );
    });
  }

  // ---------------------------------------------------------------- My Gallery

  Widget _galleryGrid() {
    final q = _q.toLowerCase();
    final items = _gallery.where((g) => q.isEmpty || g.$1.toLowerCase().contains(q)).toList();
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth < 420 ? 2 : (c.maxWidth < 760 ? 3 : 5);
      return GridView.builder(
        padding: const EdgeInsets.fromLTRB(VSpace.sm, VSpace.xxs, VSpace.sm, VSpace.sm),
        physics: const BouncingScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: cols, childAspectRatio: 0.82),
        itemCount: items.length,
        itemBuilder: (_, i) => VTile(media: Image.asset(items[i].$2, fit: BoxFit.cover), title: items[i].$1),
      );
    });
  }
}

/// Row 19's player, made small: the video, then one bar under it with play / pause, the position line (drag to seek)
/// and close. Tapping outside closes it, like every overlay. Made by Claude (2026-10-17).
class _VideoPlayerPane extends StatefulWidget {
  final WallpaperTheme theme;
  final String title;
  final VoidCallback onClose;
  const _VideoPlayerPane({required this.theme, required this.title, required this.onClose});

  @override
  State<_VideoPlayerPane> createState() => _VideoPlayerPaneState();
}

class _VideoPlayerPaneState extends State<_VideoPlayerPane> {
  late final VideoPlayerController _c = VideoPlayerController.asset(widget.theme.videoPath!);

  @override
  void initState() {
    super.initState();
    _c.addListener(() {
      if (mounted) setState(() {});
    });
    _c.initialize().then((_) async {
      await _c.setLooping(true);
      await _c.setVolume(0);
      await _c.play();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _seek(double dx, double w) {
    final d = _c.value.duration;
    if (d == Duration.zero || w <= 0) return;
    _c.seekTo(d * (dx / w).clamp(0.0, 1.0));
  }

  @override
  Widget build(BuildContext context) {
    // Small, as row 19 asks: the picture is held to under half the screen's height whatever its shape, and the bar
    // is never narrower than its three parts need.
    final size = MediaQuery.sizeOf(context);
    final rail = size.width < 768 ? 56.0 : 0.0;
    final v = _c.value;
    final ar = v.isInitialized && v.aspectRatio > 0 ? v.aspectRatio : 16 / 9;
    final maxW = (size.width - rail - 48).clamp(200.0, 420.0);
    final picW = (size.height * 0.45 * ar).clamp(120.0, maxW);
    final w = picW < 240 ? 240.0 : picW;
    final d = v.duration.inMilliseconds;
    final f = d == 0 ? 0.0 : (v.position.inMilliseconds / d).clamp(0.0, 1.0);
    return Stack(
      children: [
        VScrim(onTap: widget.onClose, soft: true),
        Padding(
          padding: EdgeInsets.only(left: rail),
          child: Center(
          child: GestureDetector(
            onTap: () {},
            child: SizedBox(
              width: w,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(VRadius.lg),
                    child: SizedBox(
                      width: picW,
                      child: AspectRatio(
                      aspectRatio: ar,
                      child: v.isInitialized ? VideoPlayer(_c) : Image.asset(widget.theme.assetPath, fit: BoxFit.cover),
                    ),
                    ),
                  ),
                  const SizedBox(height: VSpace.xs),
                  VGlass(
                    material: VMaterial.elevated,
                    radius: VRadius.full,
                    padding: const EdgeInsets.fromLTRB(5, 5, 5, 5),
                    child: Row(
                      children: [
                        VPress(
                          onTap: () => v.isPlaying ? _c.pause() : _c.play(),
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: const BoxDecoration(shape: BoxShape.circle, color: VColors.fillCell),
                            child: Icon(v.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 17, color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: LayoutBuilder(
                            builder: (_, c) => GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTapDown: (e) => _seek(e.localPosition.dx, c.maxWidth),
                              onHorizontalDragUpdate: (e) => _seek(e.localPosition.dx, c.maxWidth),
                              child: SizedBox(
                                height: 28,
                                child: Center(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(VRadius.full),
                                    child: LinearProgressIndicator(
                                      value: f,
                                      minHeight: 4,
                                      backgroundColor: VColors.fillCell,
                                      valueColor: const AlwaysStoppedAnimation(Colors.white),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        VPress(
                          onTap: widget.onClose,
                          tooltip: 'Close',
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: const BoxDecoration(shape: BoxShape.circle, color: VColors.fillCell),
                            child: const Icon(Icons.close_rounded, size: 15, color: VColors.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        ),
      ],
    );
  }
}
