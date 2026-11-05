import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart' show kIsWeb, setEquals;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/audio/music_player.dart';
import '../../core/media/theme_catalog.dart';
import '../../core/theme/specular_border.dart';
import '../../core/vision/vision_kit.dart';
import '../../models/theme_def.dart';
import '../music/song_wheel.dart';
import 'premium_market_ambient.dart';
import 'theme_living_media.dart';
import 'live_cover_video.dart';
import 'theme_pack_store.dart';

/// Premium Theme Market, based on the Builder.io export
/// (briefs/figma-premium-theme-market/builder-export/src/app):
///   App.tsx               layout, label form
///   components/CoverFlow.tsx  geometry, transforms, ReflectionComponent
///   components/SimpleBackgroundVideo.tsx  background (premium_market_ambient.dart)
///   hooks/useResponsive.ts    albumSize (cover size) / isMobile
///
/// Changes on top of the export (David, 2026-09-29; DEVIATIONS.md):
///   1. image / video URLs = Collider theme posters / live wallpaper loops
///   2. the selected theme's name sits above the carousel; its songs (runtime
///      catalog) in the label block, each with a small play / pause
///   3. the Player, in-view search (the rail's query filters instead, map W6),
///      skip arrows and Buy / Apply circle are removed: the centred cover
///      applies, the label block's owned / price chip buys or applies, arrow
///      keys navigate, Enter applies
///   4. the app shell's bottom bar is shown; its height is reserved
///
/// Rendering: the strip is one conveyor — a single position `pos` (card
/// units) drives every card's pose, z-order and fade in the same frame, with
/// one parent Transform carrying the 1500px perspective; reflections and the
/// blurred card shadows are rasterised once per poster into images; the
/// ambient cross-fades between themes instead of restarting the video.
///
/// All numbers are CSS px from the export (Flutter logical px == CSS px).
class PremiumThemeMarketView extends StatefulWidget {
  final WallpaperTheme currentTheme;

  /// External query from the module rail's search actuator (map W6).
  final String searchQuery;
  final ValueChanged<WallpaperTheme> onApplyTheme;
  final ValueChanged<WallpaperTheme> onPreviewTheme;
  final VoidCallback onClose;

  const PremiumThemeMarketView({
    super.key,
    required this.currentTheme,
    this.searchQuery = '',
    required this.onApplyTheme,
    required this.onPreviewTheme,
    required this.onClose,
  });

  /// Height the market keeps free for the app shell's bottom bar.
  static double bottomBarReserve(BuildContext context) =>
      _kBarBottom + _kBarHeight + _kBarGap + MediaQuery.paddingOf(context).bottom;

  @override
  State<PremiumThemeMarketView> createState() => _PremiumThemeMarketViewState();
}

// ---------------------------------------------------------------------------
// Export constants
// ---------------------------------------------------------------------------

// hooks/useResponsive.ts
const double _kMobileBreakpoint = 768; // width < 768
const double _kCoverSizeMobile = 170;
const double _kCoverSizeDesktop = 200;

// CoverFlow.tsx getTransform()
const double _kSpacingMobile = 120;
const double _kSpacingDesktop = 160;
const double _kRotationDeg = 55;
const double _kCenterScale = 1.3;
const double _kSideZPerStep = -80;
const double _kSideScaleBase = 1.15;
const double _kSideScaleStep = 0.04;
const double _kSideScaleMin = 0.8;
// CoverFlow.tsx container: h-96, perspective 1500px, max-w-7xl
const double _kStageHeight = 384;
const double _kStageMaxWidth = 1280;
const double _kPerspective = 1500;
// transition: all 400ms cubic-bezier(0.23, 1, 0.32, 1)
const Duration _kCardTransition = Duration(milliseconds: 400);
const Cubic _kCardEase = Cubic(0.23, 1, 0.32, 1);
// Drag: offset / 100; threshold 50; velocity 0.5 / 2.0 px per ms
const double _kDragDivisor = 100;
const double _kDragThreshold = 50;
const double _kVelocityThreshold = 0.5;
const double _kHighVelocityThreshold = 2.0;

// Card chrome: rounded-lg = --radius .625rem
const double _kRadius = 10;
// border border-gray-800/30  (#1E2939 @ 30%)
const Color _kCoverBorder = Color.fromRGBO(30, 41, 57, 0.3);
// img boxShadow: 0 25px 50px -12px rgba(0,0,0,0.9), 0 8px 32px rgba(0,0,0,0.6), 0 0 0 1px rgba(255,255,255,0.1)
const List<_CssShadow> _kCoverShadows = [
  _CssShadow(0, 25, 50, -12, Color.fromRGBO(0, 0, 0, 0.9)),
  _CssShadow(0, 8, 32, 0, Color.fromRGBO(0, 0, 0, 0.6)),
  _CssShadow(0, 0, 0, 1, Color.fromRGBO(255, 255, 255, 0.1)),
];
// The two blurred layers (cached as one image) and the crisp 1px ring.
const List<_CssShadow> _kCoverShadowsBlurred = [
  _CssShadow(0, 25, 50, -12, Color.fromRGBO(0, 0, 0, 0.9)),
  _CssShadow(0, 8, 32, 0, Color.fromRGBO(0, 0, 0, 0.6)),
];
// center border overlay: border-white/30 shadow-2xl (0 25px 50px -12px #00000040)
const List<_CssShadow> _kShadow2xl = [
  _CssShadow(0, 25, 50, -12, Color.fromRGBO(0, 0, 0, 0.25)),
];

// ReflectionComponent
const double _kReflectionOpacityCenter = 0.9;
const double _kReflectionOpacitySide = 0.75;
const double _kReflectionBlur = 0.5; // blur(0.5px)
const double _kReflectionBrightness = 0.6;
const double _kReflectionContrast = 1.3;
// mask: linear-gradient(to top, rgba(255,255,255,0.75) 0%, 0.4 20%, 0.15 40%, transparent 60%)
const List<Color> _kReflectionMaskColors = [
  Color.fromRGBO(255, 255, 255, 0.75),
  Color.fromRGBO(255, 255, 255, 0.4),
  Color.fromRGBO(255, 255, 255, 0.15),
  Color.fromRGBO(255, 255, 255, 0),
];
const List<double> _kReflectionMaskStops = [0.0, 0.2, 0.4, 0.6];
// transition-all duration-500 (Tailwind default ease cubic-bezier(0.4,0,0.2,1))
const Cubic _kTwEase = Cubic(0.4, 0, 0.2, 1);

// Floor highlight: h-3, translateY(6px), opacity 0.6 / 0.35, duration-1000
const double _kFloorHeight = 12;
const double _kFloorOffset = 6;

// Tailwind v4 grays (oklch -> sRGB)
const Color _kGray400 = Color(0xFF99A1AF);

// App.tsx layout
const double _kMainPadX = 16; // px-4
const double _kLabelsMarginTop = 32; // mt-8

// App shell bottom bar (PermanentNavBar, main.dart PLANE 4): bottom 12,
// 44px buttons + 2 * 6 padding = 56. The market centres its content in the
// space above it (+16 gap) so the bar never overlaps or shifts the content.
const double _kBarBottom = 12;
const double _kBarHeight = 56;
const double _kBarGap = 16;
/// PermanentNavBar width: 3 x 44 circles + 2 x 12 gaps + 2 x 6 padding.
const double _kBarWidth = 3 * 44 + 2 * 12 + 2 * 6.0;
/// VMaterial.elevated blur (S-C11 app glass as used by the bar's VOrnament).
const double _kGlassSigma = 28;

// Label form, fixed height so the stage never moves between themes / states:
// p-2 8 + creator 24 + 4 + collection 20 + 12 + chip 44 + 8 + song carousel
// (3 slots x 44) + p-2 8. Rows are 44 px: each carries its own play button.
const double _kSongRowExtent = 44;
const int _kSongSlots = 3;
const double _kSongsBlockHeight = _kSongSlots * _kSongRowExtent;
const double _kChipHeight = 44;
const double _kLabelsBlockHeight =
    8 + 24 + 4 + 20 + 12 + _kChipHeight + 8 + _kSongsBlockHeight + 8;

// Not-owned dim on covers (DEVIATIONS.md D5): black 45% over the face, the
// reflection multiplied by the same 0.55.
const double _kUnownedCardDim = 0.45;

/// One ambient video layer in the cross-fade stack: [target] drops to 0 when
/// the layer is superseded; it unmounts when its fade-out ends.
class _AmbientLayer {
  _AmbientLayer(this.theme);
  final WallpaperTheme theme;
  double target = 1;
}

class _PremiumThemeMarketViewState extends State<PremiumThemeMarketView> {
  // App.tsx state
  List<WallpaperTheme> _themes = const [];
  WallpaperTheme? _selected;
  String _searchQuery = '';

  // CoverFlow.tsx state
  int _currentIndex = 0;

  final ThemePackStore _store = ThemePackStore.instance;
  final FocusNode _keyFocus = FocusNode();

  /// Ambient layers, bottom .. top; the newest theme's layer fades in over
  /// the previous one, which keeps playing until its fade-out ends.
  final List<_AmbientLayer> _ambientLayers = [];

  /// Every theme in the runtime ThemeCatalog (hosted themes.json), live
  /// themes first, then the stills: no names, counts or gate in the code.
  List<WallpaperTheme> get _catalog => [
        ...WallpaperCatalog.premiumThemes,
        ...WallpaperCatalog.freeThemes,
      ];

  /// A still (not premium) is free: it applies straight away.
  bool _owned(WallpaperTheme t) => !t.isPremium || _store.isUnlocked(t.id);

  void _onCatalogChanged() {
    if (!mounted) return;
    _fetchThemes(_searchQuery, keepId: _selected?.id);
  }

  @override
  void initState() {
    super.initState();
    ThemeCatalog.instance.addListener(_onCatalogChanged);
    _store.addListener(_onCatalogChanged);
    _store.init();
    _fetchThemes('');
  }

  @override
  void didUpdateWidget(covariant PremiumThemeMarketView old) {
    super.didUpdateWidget(old);
    // Rail search (map W6) drives the same filter the old in-view search used.
    if (old.searchQuery != widget.searchQuery) {
      _fetchThemes(widget.searchQuery, keepId: _selected?.id);
    }
  }

  @override
  void dispose() {
    // Not during finalizeTree: listeners rebuild.
    ThemeCatalog.instance.removeListener(_onCatalogChanged);
    _store.removeListener(_onCatalogChanged);
    _keyFocus.dispose();
    super.dispose();
  }

  // App.tsx fetchSongs(): list, then centre on Math.floor(length / 2)
  void _fetchThemes(String query, {String? keepId}) {
    final q = query.trim().toLowerCase();
    final catalog = _catalog;
    final results = q.isEmpty
        ? catalog
        : catalog.where((t) {
            return t.name.toLowerCase().contains(q) ||
                t.collection.toLowerCase().contains(q) ||
                t.creator.toLowerCase().contains(q) ||
                t.tier.toLowerCase().contains(q) ||
                t.id.toLowerCase().contains(q);
          }).toList();
    final prevId = _selected?.id;
    setState(() {
      _searchQuery = query;
      _themes = results;
      final kept = keepId == null ? -1 : results.indexWhere((t) => t.id == keepId);
      _currentIndex =
          results.isEmpty ? 0 : (kept >= 0 ? kept : results.length ~/ 2);
      _selected = results.isEmpty ? null : results[_currentIndex];
      _setAmbientTheme(_selected);
    });
    final s = _selected;
    if (s != null && s.id != prevId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onPreviewTheme(s);
      });
    }
  }

  // Cross-fade (no ambient restart): the new theme's layer fades in over the
  // previous one, which keeps playing until its fade-out ends.
  void _setAmbientTheme(WallpaperTheme? next) {
    final current = _ambientLayers.isEmpty ? null : _ambientLayers.last.theme;
    if (next == null) {
      for (final l in _ambientLayers) {
        l.target = 0;
      }
      return;
    }
    if (current != null && current.id == next.id) return;
    for (final l in _ambientLayers) {
      l.target = 0;
    }
    _ambientLayers.add(_AmbientLayer(next));
    while (_ambientLayers.length > 3) {
      _ambientLayers.removeAt(0);
    }
  }

  // App.tsx handleSongSelect + CoverFlow setCurrentIndex. The CoverFlow
  // loops (map row 4): indexes wrap at both ends.
  void _select(int index) {
    if (_themes.isEmpty) return;
    index %= _themes.length;
    if (index < 0) index += _themes.length;
    final changed = index != _currentIndex;
    if (!changed) return;
    setState(() {
      _currentIndex = index;
      _selected = _themes[index];
      _setAmbientTheme(_selected);
    });
    if (changed) widget.onPreviewTheme(_themes[index]);
  }

  // The centred cover applies; a not-owned premium one opens the buy flow.
  void _activate(WallpaperTheme t) {
    if (_owned(t)) {
      widget.onApplyTheme(t);
      return;
    }
    _confirmBuy(t, _store.priceLabelFor(t.id, catalogPrice: t.priceLabel));
  }

  void _onTapCover(int i) {
    if (_themes.isEmpty) return;
    if (i == _currentIndex) {
      _activate(_themes[i]);
    } else {
      _select(i);
    }
  }

  // Keyboard navigation (ArrowLeft / ArrowRight / Enter / Escape)
  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent || _themes.isEmpty) return KeyEventResult.ignored;
    if (e.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _select(_currentIndex - 1);
      return KeyEventResult.handled;
    }
    if (e.logicalKey == LogicalKeyboardKey.arrowRight) {
      _select(_currentIndex + 1);
      return KeyEventResult.handled;
    }
    if (e.logicalKey == LogicalKeyboardKey.enter ||
        e.logicalKey == LogicalKeyboardKey.numpadEnter) {
      final s = _selected;
      if (s != null) _activate(s);
      return KeyEventResult.handled;
    }
    if (e.logicalKey == LogicalKeyboardKey.escape) {
      widget.onClose();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final barReserve = PremiumThemeMarketView.bottomBarReserve(context);
    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth;
      final h = constraints.maxHeight;
      final isMobile = w < _kMobileBreakpoint;
      final selected = _selected;

      // The content (stage + label form, fixed height) sits in the space
      // above the app shell's bottom bar.
      final mainHeight = math.max(0.0, h - barReserve);
      const contentHeight =
          _kStageHeight + _kLabelsMarginTop + _kLabelsBlockHeight;
      // v8.4: Figma 1:3 places the stage at a fixed y (Container 1:9 at
      // 174 + placeholder 6.85), not centred; fall back to centring only when
      // the screen is too short for the frame.
      final contentTop = h >= 800
          ? 174 + 6.85
          : math.max(0.0, (mainHeight - contentHeight) / 2);
      final stageTop = contentTop;
      final labelsTop = stageTop + _kStageHeight + _kLabelsMarginTop;
      final contentWidth = w - _kMainPadX * 2;

      // The app shell's bottom bar (PermanentNavBar: VOrnament, elevated
      // glass, 3 x 44 circles) and the owned / price chip: same material
      // blur, applied to the video behind them.
      final glass = <AmbientGlass>[
        AmbientGlass(
            Rect.fromLTWH((w - _kBarWidth) / 2,
                h - _kBarBottom - MediaQuery.paddingOf(context).bottom - _kBarHeight,
                _kBarWidth, _kBarHeight),
            _kBarHeight / 2,
            _kGlassSigma),
        if (_capsuleRect != null)
          AmbientGlass(_capsuleRect!, _capsuleRect!.height / 2, _kGlassSigma),
      ];
      WidgetsBinding.instance.addPostFrameCallback((_) => _syncCapsuleRect());

      return Focus(
        focusNode: _keyFocus,
        autofocus: true,
        onKeyEvent: _onKey,
        child: Stack(
            fit: StackFit.expand,
            children: [
              // App root: background linear-gradient(to bottom, #000000 0%, #111111 100%)
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF000000), Color(0xFF111111)],
                  ),
                ),
              ),
              // Floor: bottom half, linear-gradient(to top, rgba(255,255,255,0.02), transparent),
              // perspective(1000px) rotateX(60deg), transform-origin bottom
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: h / 2,
                child: IgnorePointer(
                  child: Transform(
                    alignment: Alignment.bottomCenter,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, -1 / 1000)
                      ..multiply(Matrix4.rotationX(60 * math.pi / 180)),
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Color.fromRGBO(255, 255, 255, 0.02),
                            Color.fromRGBO(255, 255, 255, 0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // SimpleBackgroundVideo: fixed 100vw x 100vh, overflow hidden;
              // the media is 200vw x 200vh centred. Always on (autoplay).
              // The newest layer fades in over the previous one, which keeps
              // playing until its fade-out ends.
              for (final l in _ambientLayers)
                Positioned.fill(
                  key: ValueKey('ambient-${l.theme.id}'),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: l.target),
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOutCubic,
                    onEnd: () {
                      if (l.target == 0 && mounted) {
                        setState(() => _ambientLayers.remove(l));
                      }
                    },
                    builder: (context, v, child) =>
                        Opacity(opacity: v, child: child),
                    child: SimpleBackgroundVideoAmbient(
                      theme: l.theme,
                      owned: kOwnedBrighterState && _owned(l.theme),
                      glass: kIsWeb ? glass : const [],
                    ),
                  ),
                ),

              // No search results: an empty stage, no copy (v8.3, D45).
              if (_themes.isNotEmpty && selected != null) ...[
                // Label form (z 250) sits under the CoverFlow wrapper (z 300)
                Positioned(
                  left: 0,
                  right: 0,
                  top: labelsTop,
                  height: _kLabelsBlockHeight,
                  // Top-aligned: with songs the column fills the block exactly
                  // (as before); without songs it ends under the chip.
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: _buildLabels(selected, contentWidth),
                  ),
                ),
                // CoverFlow wrapper
                Positioned(
                  left: _kMainPadX,
                  right: _kMainPadX,
                  top: stageTop,
                  height: _kStageHeight,
                  child: Center(
                    child: SizedBox(
                      width: math.min(contentWidth, _kStageMaxWidth),
                      height: _kStageHeight,
                      child: _CoverFlow(
                        themes: _themes,
                        currentIndex: _currentIndex,
                        isMobile: isMobile,
                        ownedIds: {
                          for (final t in _themes)
                            if (_owned(t)) t.id,
                        },
                        onSelect: _select,
                        onTapCover: _onTapCover,
                      ),
                    ),
                  ),
                ),
                // The selected theme's name above the carousel; FittedBox
                // shrinks long names so nothing ever truncates.
                Positioned(
                  left: 16,
                  right: 16,
                  top: math.max(0.0, stageTop - 56),
                  height: 48,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _displayName(selected),
                        textAlign: TextAlign.center,
                        style: _inter(TextStyle(
                          fontSize: 28,
                          height: 1.2,
                          fontWeight: FontWeight.w300,
                          color: const Color(0xFFFFFFFF),
                          shadows: [
                            _cssDropShadow(0, 4, 4, const Color(0x26000000))
                          ],
                        )),
                      ),
                    ),
                  ),
                ),
              ],

            ],
          ),
      );
    });
  }

  // ---------------- Label form (App.tsx) -----------------------------------
  String _displayName(WallpaperTheme t) =>
      t.name.replaceAll(RegExp(r'\s*4K$'), '').trim();

  // App.tsx:80 label form. The theme's name sits above the carousel; this
  // block carries the metadata, the owned / price chip (the buy / apply
  // affordance) and the theme's real songs from the runtime catalog
  // (SongWheel, v8.2, DEVIATIONS.md D11, D37): the selected song centred, a
  // play / pause button in a fixed column on every row, titles fading with
  // distance; it fades in on each theme change.
  Widget _buildLabels(WallpaperTheme t, double maxWidth) {
    final tracks = MusicPlayer.themeTracks(t.id);
    final wheelWidth = math.min(maxWidth - 16, 340.0);
    final owned = _owned(t);
    final price = _store.priceLabelFor(t.id, catalogPrice: t.priceLabel);
    return SizedBox(
      width: 256, // Figma 1:11, 255.96 wide
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Paragraph 1:16 (16 / 24): the theme's creator.
            SizedBox(
              height: 24,
              child: Text(t.creator, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
                  style: _inter(const TextStyle(fontSize: 16, height: 1.5, fontWeight: FontWeight.w400, color: Color(0xFFD1D5DC)))),
            ),
            const SizedBox(height: 4),
            // Paragraph 1:19 (14 / 20): the theme's collection.
            SizedBox(
              height: 20,
              child: Text(t.collection.isEmpty ? '' : 'from ${t.collection}',
                  maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
                  style: _inter(const TextStyle(fontSize: 14, height: 20 / 14, fontWeight: FontWeight.w300, color: _kGray400))),
            ),
            const SizedBox(height: 12),
            // Owned / price chip: buy / apply stays reachable without the old
            // centre circle; 44 px hit target.
            Row(mainAxisSize: MainAxisSize.min, children: [
              _GlassCapsule(
                key: _capsuleKey,
                height: _kChipHeight,
                label: owned ? 'Owned' : price,
                onTap: () => owned ? widget.onApplyTheme(t) : _confirmBuy(t, price),
              ),
              // DEBUG PREVIEW (map W3): applies the theme free of charge,
              // bypassing the price gate. Compiled out for production.
              if (!owned && kThemePreviewButton) ...[
                const SizedBox(width: 8),
                _GlassCapsule(
                  height: _kChipHeight,
                  label: 'Preview',
                  onTap: () {
                    ThemePackStore.instance.previewUnlock(t.id);
                    widget.onApplyTheme(t);
                  },
                ),
              ],
            ]),
            if (tracks.isNotEmpty) ...[
              const SizedBox(height: 8),
              TweenAnimationBuilder<double>(
                key: ValueKey('songs-fade-${t.id}'),
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOutCubic,
                builder: (context, v, child) => Opacity(opacity: v, child: child),
                child: SongWheel(
                  key: ValueKey('songs-${t.id}-${tracks.length}'),
                  tracks: tracks,
                  queueId: 'theme:${t.id}',
                  width: wheelWidth,
                  itemExtent: _kSongRowExtent,
                  maxVisible: _kSongSlots,
                  centerStyle: _inter(const TextStyle(fontSize: 16, height: 24 / 16, fontWeight: FontWeight.w400, color: Color(0xFFFFFFFF))),
                  sideStyle: _inter(const TextStyle(fontSize: 14, height: 20 / 14, fontWeight: FontWeight.w300, color: _kGray400)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Map row 22: purchases go through the centred alert. There is no store
  // backend yet, so the line says where the unlock lives (D49).
  Future<void> _confirmBuy(WallpaperTheme t, String price) async {
    final i = await showVAlert(
      context,
      icon: Icons.diamond_outlined,
      title: _displayName(t),
      // Alert 130:75006 has a description line under the title; the
      // theme's creator and collection fill it.
      message: [t.creator, t.collection].where((s) => s.isNotEmpty).join(' · '),
      actions: [VAlertChoice('Buy · $price'), const VAlertChoice('Cancel')],
    );
    if (i != 0 || !mounted) return;
    // No store on this link: the purchase fails honestly instead of granting
    // a paid theme for nothing (D66).
    if (!ThemePackStore.purchasesAvailable) {
      await showVAlert(
        context,
        icon: Icons.diamond_outlined,
        title: "Purchases aren't available on this link",
        actions: const [VAlertChoice('OK')],
      );
      return;
    }
    await _store.buyPack(t.id);
  }

  /// Web: the capsule's backdrop blur is a CSS element in the ambient (the
  /// video is DOM content under Flutter), so track the capsule's rect.
  final GlobalKey _capsuleKey = GlobalKey();
  Rect? _capsuleRect;

  void _syncCapsuleRect() {
    if (!mounted) return;
    final box = _capsuleKey.currentContext?.findRenderObject() as RenderBox?;
    final root = context.findRenderObject() as RenderBox?;
    Rect? r;
    if (box != null && root != null && box.hasSize && box.attached) {
      r = box.localToGlobal(Offset.zero, ancestor: root) & box.size;
    }
    if (kIsWeb && r != _capsuleRect) setState(() => _capsuleRect = r);
  }
}

// ---------------------------------------------------------------------------
// CoverFlow.tsx
// ---------------------------------------------------------------------------

/// Drag state (handleDragStart / Move / End). Only the CoverFlow reads it, so
/// a drag re-poses the cards without rebuilding the rest of the market.
class _DragModel {
  bool dragging = false;
  double start = 0;
  double startPos = 0; // conveyor pos when the drag began
  double offset = 0;
  double velocity = 0; // px per ms
  int lastTime = 0;

  void begin(double x, double pos) {
    dragging = true;
    start = x;
    startPos = pos;
    offset = 0;
    velocity = 0;
    lastTime = DateTime.now().millisecondsSinceEpoch;
  }

  void move(double x) {
    if (!dragging) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final deltaTime = now - lastTime;
    final newOffset = x - start;
    velocity = (newOffset - offset) / math.max(deltaTime, 1);
    offset = newOffset;
    lastTime = now;
  }

  void reset() {
    dragging = false;
    offset = 0;
    velocity = 0;
  }
}

class _CoverFlow extends StatefulWidget {
  final List<WallpaperTheme> themes;
  final int currentIndex;
  final bool isMobile;
  final Set<String> ownedIds;
  final ValueChanged<int> onSelect;
  final ValueChanged<int> onTapCover;

  const _CoverFlow({
    required this.themes,
    required this.currentIndex,
    required this.isMobile,
    required this.ownedIds,
    required this.onSelect,
    required this.onTapCover,
  });

  @override
  State<_CoverFlow> createState() => _CoverFlowState();
}

class _CoverFlowState extends State<_CoverFlow>
    with SingleTickerProviderStateMixin {
  final _DragModel _drag = _DragModel();

  /// Card subtrees reused across drag frames (same instance => Flutter skips
  /// rebuilding them); invalidated when what they show changes.
  final Map<String, Widget> _cards = {};

  // One conveyor position (card units) drives every card's pose, z-order and
  // fade in the same frame: d = i - pos.
  late double _pos = widget.currentIndex.toDouble();
  double _posFrom = 0;
  double _posTo = 0;
  late final AnimationController _posCtl =
      AnimationController(vsync: this, duration: _kCardTransition);
  late final Animation<double> _posAnim =
      CurvedAnimation(parent: _posCtl, curve: _kCardEase);

  @override
  void initState() {
    super.initState();
    _posAnim.addListener(() {
      setState(() => _pos = _posFrom + (_posTo - _posFrom) * _posAnim.value);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _prewarm());
  }

  @override
  void didUpdateWidget(covariant _CoverFlow old) {
    super.didUpdateWidget(old);
    if (old.currentIndex != widget.currentIndex ||
        old.isMobile != widget.isMobile ||
        !setEquals(old.ownedIds, widget.ownedIds) ||
        !identical(old.themes, widget.themes)) {
      _cards.clear();
    }
    if (old.currentIndex != widget.currentIndex) {
      _goTo(widget.currentIndex.toDouble());
    }
    if (!identical(old.themes, widget.themes) || old.isMobile != widget.isMobile) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _prewarm());
    }
  }

  @override
  void dispose() {
    _prewarmGen++;
    _posCtl.dispose();
    super.dispose();
  }

  int _prewarmGen = 0;

  /// Animates the conveyor to [target] with the card transition's ease. The
  /// start hops whole loops first: card distance only depends on pos modulo
  /// the theme count, so the hop changes nothing visually and the tween never
  /// crosses the loop seam.
  void _goTo(double target) {
    var from = _pos;
    final n = widget.themes.length;
    if (n > 1) from += n * ((target - from) / n).roundToDouble();
    _pos = from;
    _posFrom = from;
    _posTo = target;
    if ((target - from).abs() < 0.0001) {
      _posCtl.stop();
      return;
    }
    _posCtl.forward(from: 0);
  }

  /// Rasterises every card's cover + reflection one at a time between frames
  /// (nearest to the current card first), so the work is done before the
  /// user swipes instead of on the frames where a card enters the screen.
  Future<void> _prewarm() async {
    final gen = ++_prewarmGen;
    final themes = widget.themes;
    final order = List<int>.generate(themes.length, (i) => i)
      ..sort((a, b) => _rel(a).abs().compareTo(_rel(b).abs()));
    final size = widget.isMobile ? _kCoverSizeMobile : _kCoverSizeDesktop;
    for (final i in order) {
      if (!mounted || gen != _prewarmGen) return;
      final scale = _rasterScale(context);
      final t = themes[i];
      final done = Completer<void>();
      var pending = 2;
      void step() {
        if (--pending == 0 && !done.isCompleted) done.complete();
      }
      if (_RasterCache.cover(context, t, size - 2, scale, step) != null) step();
      if (_RasterCache.reflection(context, t, size, scale, step) != null) step();
      await done.future.timeout(const Duration(seconds: 8), onTimeout: () {});
      // Never do this work while a finger is down; one card per idle gap.
      while (mounted && gen == _prewarmGen && _drag.dragging) {
        await Future<void>.delayed(const Duration(milliseconds: 120));
      }
      await Future<void>.delayed(const Duration(milliseconds: 60));
    }
  }

  void _dragEnd() {
    final d = _drag;
    if (!d.dragging) return;
    var targetIndex = widget.currentIndex;
    final dragDistance = d.offset.abs();
    final dragVelocity = d.velocity.abs();
    if (dragDistance > _kDragThreshold || dragVelocity > _kVelocityThreshold) {
      var jumpCount = 1;
      if (dragVelocity > _kHighVelocityThreshold) {
        jumpCount = math.min(2, (dragVelocity / 1.5).ceil());
      }
      if (dragDistance > _kDragThreshold * 2) {
        jumpCount =
            math.max(jumpCount, (dragDistance / (_kDragThreshold * 1.5)).floor());
      }
      // Loops (map row 4): no stop at the first or last theme.
      final n = widget.themes.length;
      if (d.offset < 0 || d.velocity < -_kVelocityThreshold) {
        targetIndex = (widget.currentIndex + jumpCount) % n;
      } else if (d.offset > 0 || d.velocity > _kVelocityThreshold) {
        targetIndex = ((widget.currentIndex - jumpCount) % n + n) % n;
      }
    }
    d.reset();
    if (targetIndex == widget.currentIndex) {
      _goTo(targetIndex.toDouble());
    } else {
      widget.onSelect(targetIndex);
    }
    setState(() {});
  }

  /// Position relative to the centre cover on the loop: -n/2 .. n/2.
  int _rel(int index) {
    final n = widget.themes.length;
    if (n == 0) return 0;
    var d = (index - widget.currentIndex) % n;
    if (d < 0) d += n;
    if (d > n ~/ 2) d -= n;
    return d;
  }

  /// Conveyor distance of card [i] from the strip's position, the loop's
  /// shortest way around.
  double _distance(int i) {
    final n = widget.themes.length;
    if (n == 0) return 0;
    var d = (i - _pos) % n;
    if (d > n / 2) d -= n;
    return d;
  }

  // Pose as a pure function of d: integer d keeps the export's exact values
  // (centre 1.3, sides turned 55 deg), in between is the conveyor glide.
  _CardPose _poseFor(int i) {
    final d = _distance(i);
    final a = d.abs();
    final spacing = widget.isMobile ? _kSpacingMobile : _kSpacingDesktop;
    final sign = d < 0 ? -1.0 : 1.0;
    final sideScale =
        math.max(_kSideScaleMin, _kSideScaleBase - a * _kSideScaleStep);
    final s = a < 1 ? _kCenterScale + (sideScale - _kCenterScale) * a : sideScale;
    final tx = sign * spacing * a;
    final tz = _kSideZPerStep * a;
    final ry = -sign * _kRotationDeg * math.min(a, 1);
    return _CardPose(tx, tz, ry, s, _opacityFor(a));
  }

  // Fades out toward the |d| = 6 cull edge so culling never pops.
  double _opacityFor(double a) {
    if (a <= 2) return 1;
    if (a <= 3) return 0.95;
    if (a <= 4) return 0.9;
    if (a <= 5) return math.max(0.8, 0.9 - ((a - 4) * 0.05));
    return math.max(0.0, 0.8 * (1 - (a - 5)));
  }

  // Conveyor z: the card crossing the centre has the smaller |d| and paints
  // over the outgoing one, every frame.
  double _zFor(int i) => 1000 - _distance(i).abs() * 120;

  Widget _card(int i, double size) {
    final t = widget.themes[i];
    final isCurrent = i == widget.currentIndex;
    // Not-owned dim only behind kOwnedBrighterState (D5, off): covers are
    // fully lit (map row 4).
    final dimmed = kOwnedBrighterState && !widget.ownedIds.contains(t.id);
    // The centre cover and its two neighbours play their live wallpaper;
    // the rest show the poster until they come near the centre.
    final live = t.isLive && _rel(i).abs() <= 1;
    return _cards.putIfAbsent(
      '${t.id}|$isCurrent|$dimmed|$size|$live',
      () => RepaintBoundary(
        child: GestureDetector(
          onTap: () {
            if (!_drag.dragging) widget.onTapCover(i);
          },
          child: _CoverCard(
            theme: t,
            isCurrent: isCurrent,
            dimmed: dimmed,
            live: live,
            size: size,
          ),
        ),
      ),
    );
  }

  Widget _cardSlot(int i, double left, double top, double coverSize) {
    final pose = _poseFor(i);
    return Positioned(
      key: ValueKey('card-${widget.themes[i].id}'),
      left: left,
      top: top,
      width: coverSize,
      height: coverSize * 2, // cover + ReflectionComponent (top-full, h-full)
      child: Opacity(
        opacity: pose.opacity,
        child: Transform(
          // transform-origin: centre of the cover box
          alignment: const Alignment(0, -0.5),
          transform: pose.matrix(),
          child: _card(i, coverSize),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final coverSize = widget.isMobile ? _kCoverSizeMobile : _kCoverSizeDesktop;
    final themes = widget.themes;
    // Paint order = conveyor z, back to front; ties in card order.
    final visible = <int>[
      for (int i = 0; i < themes.length; i++)
        if (_distance(i).abs() <= 6) i,
    ]..sort((a, b) {
        final za = _zFor(a), zb = _zFor(b);
        if (za != zb) return za.compareTo(zb);
        return a.compareTo(b);
      });

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: (d) {
        _posCtl.stop();
        _drag.begin(d.globalPosition.dx, _pos);
        setState(() {});
      },
      onHorizontalDragUpdate: (d) {
        _drag.move(d.globalPosition.dx);
        setState(() => _pos = _drag.startPos - _drag.offset / _kDragDivisor);
      },
      onHorizontalDragEnd: (_) => _dragEnd(),
      onHorizontalDragCancel: _dragEnd,
      child: LayoutBuilder(builder: (context, c) {
        final left = (c.maxWidth - coverSize) / 2;
        final top = (c.maxHeight - coverSize) / 2;
        return MouseRegion(
          cursor: _drag.dragging
              ? SystemMouseCursors.grabbing
              : SystemMouseCursors.grab,
          child: Transform(
            // One shared perspective (container perspective: 1500px) for the
            // whole strip, like the export's 3D container.
            alignment: Alignment.center,
            transform: Matrix4.identity()..setEntry(3, 2, -1 / _kPerspective),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                for (final i in visible) _cardSlot(i, left, top, coverSize),
              ],
            ),
          ),
        );
      }),
    );
  }
}

/// One CoverFlow card: <img> + glass reflection + ReflectionComponent + floor
/// highlight (+ centre border / top glow). The blurred box-shadows, the
/// reflection (blur / brightness / contrast / mask) and the top glow are
/// rasterised once into images (_RasterCache) with the same geometry and
/// filters, then drawn as plain images every frame.
class _CoverCard extends StatelessWidget {
  final WallpaperTheme theme;
  final bool isCurrent;
  final bool dimmed;
  final bool live;
  final double size;

  const _CoverCard({
    required this.theme,
    required this.isCurrent,
    required this.dimmed,
    required this.size,
    this.live = false,
  });

  static const double _shadowPad = 100;
  static const double _glowPad = 24;

  @override
  Widget build(BuildContext context) {
    // ReflectionComponent opacity: index === currentIndex ? 0.9 : 0.75
    final reflectionOpacity =
        isCurrent ? _kReflectionOpacityCenter : _kReflectionOpacitySide;
    return SizedBox(
      width: size,
      height: size * 2,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // img boxShadow (two blurred layers, cached) + the 1px white ring
          Positioned(
            left: -_shadowPad,
            top: -_shadowPad,
            width: size + _shadowPad * 2,
            height: size + _shadowPad * 2,
            child: _CachedPaint(
              cacheKey: 'cover-shadow|$size',
              size: Size(size + _shadowPad * 2, size + _shadowPad * 2),
              painter: _OffsetPainter(
                const Offset(_shadowPad, _shadowPad),
                Size(size, size),
                const _CssShadowPainter(_kCoverShadowsBlurred, _kRadius),
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            width: size,
            height: size,
            child: CustomPaint(painter: _RingPainter(_kRadius, 1, _kCoverShadows[2].color)),
          ),
          // <img> object-cover rounded-lg border border-gray-800/30
          Positioned(
            left: 0,
            top: 0,
            width: size,
            height: size,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Padding(
                  padding: const EdgeInsets.all(1),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(_kRadius - 1),
                    child: live
                        ? Stack(fit: StackFit.expand, children: [
                            _CoverPoster(theme: theme, inner: size - 2),
                            LiveCoverVideo(key: ValueKey('live-${theme.id}'), url: theme.videoUrl!),
                          ])
                        : _CoverPoster(theme: theme, inner: size - 2),
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(_kRadius),
                    border: Border.all(color: _kCoverBorder, width: 1),
                  ),
                ),
              ],
            ),
          ),
          // Glass reflection: linear-gradient(135deg, rgba(255,255,255,0.12) 0%,
          // rgba(255,255,255,0.04) 25%, transparent 50%, rgba(0,0,0,0.02) 75%, rgba(0,0,0,0.08) 100%)
          Positioned(
            left: 0,
            top: 0,
            width: size,
            height: size,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(_kRadius),
                gradient: _cssLinearGradient(
                  135,
                  Size(size, size),
                  const [
                    Color.fromRGBO(255, 255, 255, 0.12),
                    Color.fromRGBO(255, 255, 255, 0.04),
                    Color.fromRGBO(255, 255, 255, 0),
                    Color.fromRGBO(0, 0, 0, 0),
                    Color.fromRGBO(0, 0, 0, 0.02),
                    Color.fromRGBO(0, 0, 0, 0.08),
                  ],
                  const [0.0, 0.25, 0.5, 0.5, 0.75, 1.0],
                ),
              ),
            ),
          ),
          // Not-owned dim (DEVIATIONS.md D5)
          Positioned(
            left: 0,
            top: 0,
            width: size,
            height: size,
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(end: dimmed ? _kUnownedCardDim : 0),
              duration: const Duration(milliseconds: 600),
              curve: _kTwEase,
              builder: (context, a, _) => a <= 0.001
                  ? const SizedBox.shrink()
                  : DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(_kRadius),
                        color: Color.fromRGBO(0, 0, 0, a),
                      ),
                    ),
            ),
          ),
          // Builder ReflectionComponent: absolute top-full, w-full h-full, rounded-lg,
          // background cover, scaleY(-1), opacity 0.9/0.75 (duration-500), mask
          // to-top, filter blur(0.5px) brightness(0.6) contrast(1.3) — cached image.
          Positioned(
            left: 0,
            top: size,
            width: size,
            height: size,
            child: _Reflection(
              theme: theme,
              size: size,
              opacity: reflectionOpacity,
              dim: dimmed ? _kUnownedCardDim : 0,
            ),
          ),
          // Floor highlight: top-full h-3 rounded-lg translateY(6px), opacity 0.6 / 0.35 (duration-1000)
          // linear-gradient(to bottom, rgba(255,255,255,0.06) 0%, 0.12 40%, transparent 100%)
          Positioned(
            left: 0,
            top: size + _kFloorOffset,
            width: size,
            height: _kFloorHeight,
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(end: isCurrent ? 0.6 : 0.35),
              duration: const Duration(milliseconds: 1000),
              curve: _kTwEase,
              builder: (context, o, _) => CustomPaint(painter: _FloorPainter(o)),
            ),
          ),
          if (isCurrent) ...[
            // absolute inset-0 rounded-lg border border-white/30 shadow-2xl
            Positioned(
              left: -_shadowPad,
              top: -_shadowPad,
              width: size + _shadowPad * 2,
              height: size + _shadowPad * 2,
              child: _CachedPaint(
                cacheKey: 'center-shadow|$size',
                size: Size(size + _shadowPad * 2, size + _shadowPad * 2),
                painter: _OffsetPainter(
                  const Offset(_shadowPad, _shadowPad),
                  Size(size, size),
                  const _CssShadowPainter(_kShadow2xl, _kRadius),
                ),
              ),
            ),
            Positioned(
              left: 0,
              top: 0,
              width: size,
              height: size,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(_kRadius),
                  border: Border.all(
                      color: const Color.fromRGBO(255, 255, 255, 0.3), width: 1),
                ),
              ),
            ),
            // top-0 left-1/4 right-1/4 h-1 bg-white/20 rounded-full blur-sm (8px)
            Positioned(
              top: -_glowPad,
              left: size / 4 - _glowPad,
              width: size / 2 + _glowPad * 2,
              height: 4 + _glowPad * 2,
              child: _CachedPaint(
                cacheKey: 'center-glow|$size',
                size: Size(size / 2 + _glowPad * 2, 4 + _glowPad * 2),
                painter: _GlowPainter(_glowPad, Size(size / 2, 4)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Rasterised paint results, shared by all cards (key + device pixel ratio).
class _RasterCache {
  _RasterCache._();
  static final Map<String, ui.Image> _images = {};
  static final Map<String, List<VoidCallback>> _waiting = {};

  static ui.Image record(String key, Size logical, double scale,
      void Function(Canvas canvas) paint) {
    final hit = _images[key];
    if (hit != null) return hit;
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec);
    canvas.scale(scale);
    paint(canvas);
    final pic = rec.endRecording();
    final img = pic.toImageSync(
      math.max(1, (logical.width * scale).ceil()),
      math.max(1, (logical.height * scale).ceil()),
    );
    pic.dispose();
    _images[key] = img;
    return img;
  }

  /// Reflection image for [theme]'s poster; null until the poster is decoded.
  static ui.Image? reflection(BuildContext context, WallpaperTheme theme,
          double size, double scale, VoidCallback onReady) =>
      _fromPoster(context, 'refl|${theme.posterUrl}|$size|$scale', theme,
          Size(size, size), scale, (c, img) => _paintReflection(c, img, size), onReady);

  /// The cover's poster pixels (object-cover into the card's inner box,
  /// FilterQuality.medium), rasterised once. On web the decoded <img> poster
  /// is a lazy texture that CanvasKit re-uploads (720x1280) whenever a card
  /// re-enters the screen; this pixel image is uploaded once and stays cached.
  static ui.Image? cover(BuildContext context, WallpaperTheme theme,
          double inner, double scale, VoidCallback onReady) =>
      _fromPoster(context, 'cover|${theme.posterUrl}|$inner|$scale', theme,
          Size(inner, inner), scale, (c, img) => paintImage(
                canvas: c,
                rect: Offset.zero & Size(inner, inner),
                image: img,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.medium,
              ), onReady);

  static ui.Image? _fromPoster(BuildContext context, String key, WallpaperTheme theme,
      Size logical, double scale, void Function(Canvas c, ui.Image poster) paint,
      VoidCallback onReady) {
    final hit = _images[key];
    if (hit != null) return hit;
    final waiting = _waiting[key];
    if (waiting != null) {
      waiting.add(onReady);
      return null;
    }
    _waiting[key] = [onReady];
    final stream = ThemeMedia.provider(theme.posterUrl)
        .resolve(createLocalImageConfiguration(context));
    late final ImageStreamListener l;
    l = ImageStreamListener((info, _) {
      stream.removeListener(l);
      record(key, logical, scale, (c) => paint(c, info.image));
      for (final cb in _waiting.remove(key) ?? const <VoidCallback>[]) {
        cb();
      }
    }, onError: (_, __) {
      stream.removeListener(l);
      _waiting.remove(key);
    });
    stream.addListener(l);
    return null;
  }

  // Same operations as the widget version: ClipRRect(poster, cover) ->
  // ImageFiltered blur(0.5px) -> ColorFiltered brightness(0.6) contrast(1.3)
  // -> ClipRect -> ShaderMask(dstIn, to-top mask) -> scaleY(-1).
  static void _paintReflection(Canvas canvas, ui.Image poster, double size) {
    final rect = Offset.zero & Size(size, size);
    // brightness(0.6) then contrast(1.3): 1.3 * 0.6x + (0.5 - 0.65) = 0.78x - 0.15
    const s = _kReflectionContrast * _kReflectionBrightness;
    const t = (0.5 - 0.5 * _kReflectionContrast) * 255.0;
    const reflectionFilter = ColorFilter.matrix(<double>[
      s, 0, 0, 0, t,
      0, s, 0, 0, t,
      0, 0, s, 0, t,
      0, 0, 0, 1, 0,
    ]);
    canvas.save();
    canvas.translate(0, size);
    canvas.scale(1, -1); // scaleY(-1) about the centre
    canvas.clipRect(rect);
    canvas.saveLayer(rect, Paint()); // ShaderMask layer
    canvas.saveLayer(rect, Paint()..colorFilter = reflectionFilter);
    canvas.saveLayer(
        rect,
        Paint()
          ..imageFilter = ImageFilter.blur(
              sigmaX: _kReflectionBlur,
              sigmaY: _kReflectionBlur,
              tileMode: TileMode.decal));
    canvas.clipRRect(RRect.fromRectAndRadius(rect, const Radius.circular(_kRadius)));
    paintImage(
      canvas: canvas,
      rect: rect,
      image: poster,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.medium,
    );
    canvas.restore();
    canvas.restore();
    canvas.drawRect(
      rect,
      Paint()
        ..blendMode = BlendMode.dstIn
        ..shader = const LinearGradient(
          begin: Alignment.bottomCenter, // "to top": 0% at bottom
          end: Alignment.topCenter,
          colors: _kReflectionMaskColors,
          stops: _kReflectionMaskStops,
        ).createShader(rect),
    );
    canvas.restore();
    canvas.restore();
  }
}

double _rasterScale(BuildContext context) =>
    MediaQuery.devicePixelRatioOf(context).clamp(1.0, 3.0);

/// Draws [painter] once into a cached image at the device pixel ratio.
class _CachedPaint extends StatelessWidget {
  final String cacheKey;
  final Size size;
  final CustomPainter painter;
  const _CachedPaint({required this.cacheKey, required this.size, required this.painter});

  @override
  Widget build(BuildContext context) {
    final scale = _rasterScale(context);
    final img = _RasterCache.record('$cacheKey|$scale', size, scale,
        (c) => painter.paint(c, size));
    return RawImage(
      image: img,
      width: size.width,
      height: size.height,
      fit: BoxFit.fill,
      filterQuality: FilterQuality.medium,
    );
  }
}

/// The cover poster from [_RasterCache.cover]; the regular poster widget
/// is shown until the raster copy exists (same pixels, no visual change).
class _CoverPoster extends StatefulWidget {
  final WallpaperTheme theme;
  final double inner;
  const _CoverPoster({required this.theme, required this.inner});

  @override
  State<_CoverPoster> createState() => _CoverPosterState();
}

class _CoverPosterState extends State<_CoverPoster> {
  @override
  Widget build(BuildContext context) {
    final img = _RasterCache.cover(context, widget.theme, widget.inner,
        _rasterScale(context), () {
      if (mounted) setState(() {});
    });
    if (img == null) {
      return ThemePosterImage(
        theme: widget.theme,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
      );
    }
    return RawImage(
      image: img,
      width: widget.inner,
      height: widget.inner,
      fit: BoxFit.fill,
      filterQuality: FilterQuality.medium,
    );
  }
}

class _Reflection extends StatefulWidget {
  final WallpaperTheme theme;
  final double size;
  final double opacity;
  final double dim;
  const _Reflection({required this.theme, required this.size, required this.opacity, required this.dim});

  @override
  State<_Reflection> createState() => _ReflectionState();
}

class _ReflectionState extends State<_Reflection> {
  @override
  Widget build(BuildContext context) {
    final img = _RasterCache.reflection(context, widget.theme, widget.size,
        _rasterScale(context), () {
      if (mounted) setState(() {});
    });
    if (img == null) return const SizedBox.shrink();
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: widget.opacity),
      duration: const Duration(milliseconds: 500),
      curve: _kTwEase,
      builder: (context, o, _) => TweenAnimationBuilder<double>(
        tween: Tween<double>(end: widget.dim),
        duration: const Duration(milliseconds: 600),
        curve: _kTwEase,
        builder: (context, d, _) {
          final k = (255 * (1 - d)).round();
          return RawImage(
            image: img,
            width: widget.size,
            height: widget.size,
            fit: BoxFit.fill,
            filterQuality: FilterQuality.medium,
            opacity: AlwaysStoppedAnimation<double>(o),
            color: d > 0 ? Color.fromARGB(255, k, k, k) : null,
            colorBlendMode: d > 0 ? BlendMode.modulate : null,
          );
        },
      ),
    );
  }
}

/// Paints [inner] at [offset] with [innerSize] (for padded cache images).
class _OffsetPainter extends CustomPainter {
  final Offset offset;
  final Size innerSize;
  final CustomPainter inner;
  const _OffsetPainter(this.offset, this.innerSize, this.inner);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    inner.paint(canvas, innerSize);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// box-shadow `0 0 0 <spread>px <color>`: a crisp ring outside the border box.
class _RingPainter extends CustomPainter {
  final double radius;
  final double spread;
  final Color color;
  const _RingPainter(this.radius, this.spread, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final inner = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius));
    final outer = RRect.fromRectAndRadius(
        (Offset.zero & size).inflate(spread), Radius.circular(radius + spread));
    canvas.drawDRRect(outer, inner, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.radius != radius || old.spread != spread || old.color != color;
}

/// blur-sm (8px) white/20 pill, padded by [pad].
class _GlowPainter extends CustomPainter {
  final double pad;
  final Size pill;
  const _GlowPainter(this.pad, this.pill);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.saveLayer(
        Offset.zero & size,
        Paint()
          ..imageFilter =
              ImageFilter.blur(sigmaX: 8, sigmaY: 8, tileMode: TileMode.decal));
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset(pad, pad) & pill, const Radius.circular(9999)),
      Paint()..color = const Color.fromRGBO(255, 255, 255, 0.2),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _GlowPainter old) => false;
}

/// Floor highlight gradient at [opacity] (no saveLayer).
class _FloorPainter extends CustomPainter {
  final double opacity;
  const _FloorPainter(this.opacity);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(_kRadius)),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.fromRGBO(255, 255, 255, 0.06 * opacity),
            Color.fromRGBO(255, 255, 255, 0.12 * opacity),
            const Color.fromRGBO(255, 255, 255, 0),
          ],
          stops: const [0.0, 0.4, 1.0],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant _FloorPainter old) => old.opacity != opacity;
}

TextStyle _actionTextStyle(Color color, FontWeight weight) => _inter(TextStyle(
      fontSize: 14,
      height: 20 / 14,
      fontWeight: weight,
      letterSpacing: 14 * 0.025,
      color: color,
    ));

/// Tappable capsule in the app's glass (VMaterial.elevated, the bottom bar's
/// VOrnament material): fill, 0.5px rim, specular rim, VPress physics. Native
/// blurs with a BackdropFilter; web gets the blur from the ambient's CSS
/// element at the same rect (the video is DOM content under Flutter).
class _GlassCapsule extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final double height;
  const _GlassCapsule({
    super.key,
    required this.label,
    required this.onTap,
    this.height = _kChipHeight,
  });

  @override
  Widget build(BuildContext context) {
    final h = height;
    final r = BorderRadius.circular(h / 2);
    const material = VMaterial.elevated;
    Widget body = CustomPaint(
      foregroundPainter: SpecularRimPainter(borderRadius: h / 2, strokeWidth: 0.6),
      child: Container(
        height: h,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: material.fill,
          borderRadius: r,
          border: Border.all(color: material.rim, width: 0.5),
        ),
        // widthFactor 1: the capsule hugs its label instead of filling the row.
        child: Align(
          widthFactor: 1,
          child: Text(
            label,
            maxLines: 1,
            style: _actionTextStyle(const Color(0xFFFFFFFF), FontWeight.w500),
          ),
        ),
      ),
    );
    body = ClipRRect(
      borderRadius: r,
      child: kIsWeb
          ? body
          : BackdropFilter(
              filter: ImageFilter.blur(sigmaX: material.blur, sigmaY: material.blur),
              child: body,
            ),
    );
    return Semantics(
      button: true,
      label: label,
      child: VPress(
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(borderRadius: r, boxShadow: material.shadow),
          child: body,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// CSS transform list minus the container perspective (it lives on the strip's
/// parent Transform now): translateX(tx) translateZ(tz) rotateY(ry) scale(s).
/// CSS z points at the viewer, so the parent's -1/d term (w = 1 - z/d)
/// foreshortens from the stage centre, matching CSS numerically.
class _CardPose {
  final double tx, tz, ryDeg, scale, opacity;
  const _CardPose(this.tx, this.tz, this.ryDeg, this.scale, this.opacity);

  Matrix4 matrix() {
    final m = Matrix4.identity();
    m.multiply(Matrix4.translationValues(tx, 0, tz));
    m.multiply(Matrix4.rotationY(ryDeg * math.pi / 180));
    m.multiply(Matrix4.diagonal3Values(scale, scale, 1));
    return m;
  }

  @override
  bool operator ==(Object other) =>
      other is _CardPose &&
      other.tx == tx &&
      other.tz == tz &&
      other.ryDeg == ryDeg &&
      other.scale == scale &&
      other.opacity == opacity;

  @override
  int get hashCode => Object.hash(tx, tz, ryDeg, scale, opacity);
}

class _CssShadow {
  final double dx, dy, blur, spread;
  final Color color;
  const _CssShadow(this.dx, this.dy, this.blur, this.spread, this.color);
}

/// CSS box-shadow: outer shadows only (clipped out of the border box),
/// Gaussian sigma = blur / 2.
class _CssShadowPainter extends CustomPainter {
  final List<_CssShadow> shadows;
  final double radius;
  const _CssShadowPainter(this.shadows, this.radius);

  @override
  void paint(Canvas canvas, Size size) {
    final box = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius));
    canvas.save();
    canvas.clipPath(Path()
      ..fillType = PathFillType.evenOdd
      ..addRect((Offset.zero & size).inflate(400))
      ..addRRect(box));
    for (final s in shadows.reversed) {
      final rect = (Offset(s.dx, s.dy) & size).inflate(s.spread);
      final r = math.max(0.0, radius + s.spread);
      final paint = Paint()..color = s.color;
      if (s.blur > 0) {
        paint.maskFilter = MaskFilter.blur(BlurStyle.normal, s.blur / 2);
      }
      canvas.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(r)), paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CssShadowPainter old) =>
      old.shadows != shadows || old.radius != radius;
}

/// CSS `linear-gradient(<angle>deg, ...)` mapped to Flutter begin/end for [size].
LinearGradient _cssLinearGradient(
    double angleDeg, Size size, List<Color> colors, List<double> stops) {
  final a = angleDeg * math.pi / 180;
  final dx = math.sin(a), dy = -math.cos(a);
  final len = (size.width * dx.abs() + size.height * dy.abs()) / 2;
  final hx = size.width / 2, hy = size.height / 2;
  return LinearGradient(
    begin: Alignment(-dx * len / hx, -dy * len / hy),
    end: Alignment(dx * len / hx, dy * len / hy),
    colors: colors,
    stops: stops,
  );
}

/// Export font is `ui-sans-serif, system-ui, sans-serif`; the platform
/// substitute on web/Android/Windows is Inter (AUTHORITY S-C13).
TextStyle _inter(TextStyle s) => GoogleFonts.inter(textStyle: s);

/// CSS drop-shadow(x y blur color): sigma = blur / 2.
Shadow _cssDropShadow(double x, double y, double blur, Color color) {
  final r = math.max(0.0, (blur / 2 - 0.5) / 0.57735);
  return Shadow(offset: Offset(x, y), blurRadius: r, color: color);
}
