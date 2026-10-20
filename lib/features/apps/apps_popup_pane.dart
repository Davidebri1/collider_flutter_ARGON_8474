import 'dart:math' as math;
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import '../../core/vision/vision_kit.dart';
import '../../models/theme_def.dart';

/// REQ-01 App Grid (Vision OS Design System 2:6774, visionOS Home 97:34752):
/// circular app icons float directly over the environment in offset rows - no platter.
/// David, 4 Oct 2026: "consider only DOF blurring around the icons here. you dont need to take over full
/// attention ... keep the field of view clean." So the room goes out of focus only in a soft halo around each
/// icon, and stays sharp everywhere else. Escapes: a tap anywhere else, or the cross beside the icons.
///
/// Icons redrawn by Claude on 2026-10-04. They were seven copies of one glass circle with a thin glyph.
/// Each destination now has its own artwork, the way apps do on a home screen:
/// its own colour and its own picture, and the two wallpaper destinations show real wallpapers.
class AppsPopupPane extends StatelessWidget {
  final VoidCallback onClose;
  final VoidCallback onOpenSmartGen;
  final VoidCallback onOpenDiscoverMarket;
  final VoidCallback onOpenThemeGallery;
  final VoidCallback onOpenPremiumMarketplace;
  final VoidCallback onOpenFiles;
  final VoidCallback onOpenMusicPlayer;
  final VoidCallback onOpenBrowser;

  /// The wallpaper in use now; the Theme Gallery icon shows it.
  final String? themeArt;

  const AppsPopupPane({
    super.key,
    required this.onClose,
    required this.onOpenSmartGen,
    required this.onOpenDiscoverMarket,
    required this.onOpenThemeGallery,
    required this.onOpenPremiumMarketplace,
    required this.onOpenFiles,
    required this.onOpenMusicPlayer,
    required this.onOpenBrowser,
    this.themeArt,
  });

  @override
  Widget build(BuildContext context) {
    final free = themeArt ?? WallpaperCatalog.freeThemes.first.assetPath;
    final themes = WallpaperCatalog.premiumThemes;
    final live = themes.isEmpty ? free : themes[themes.length ~/ 2].assetPath;
    final apps = [
      _App('Smart Gen', const [Color(0xFF8B6CFF), Color(0xFF3A1FA6)], (s) => _Cards(s), onOpenSmartGen),
      _App('Discover Market', const [Color(0xFFFF9A3D), Color(0xFFE2336B)], (s) => _Compass(s), onOpenDiscoverMarket),
      _App('Theme Gallery', const [Color(0xFF1F2937), Color(0xFF111827)], (s) => _Picture(free, s, framed: true), onOpenThemeGallery),
      _App('Premium Theme Market', const [Color(0xFF1F2937), Color(0xFF111827)], (s) => _Picture(live, s, playing: true), onOpenPremiumMarketplace),
      // These three were made with Raycast's icon maker (ray.so/icon), as David asked: its glyph, its glare and grain,
      // the gradient each icon had here, the background made round. Claude, 2026-10-17.
      _App('Files', const [Color(0xFF58B0FF), Color(0xFF1E5FD8)], (s) => _Made('assets/icons/claude_raycast_files.png'), onOpenFiles),
      _App('Music Player', const [Color(0xFFFF5F7E), Color(0xFFB0159B)], (s) => _Made('assets/icons/claude_raycast_music_player.png'), onOpenMusicPlayer),
      _App('Browser', const [Color(0xFF3FE0D0), Color(0xFF1B6FE8)], (s) => _Made('assets/icons/claude_raycast_browser.png'), onOpenBrowser),
    ];

    final width = MediaQuery.of(context).size.width;
    const perRow = 4;
    final iconSize = width < 480 ? 58.0 : 72.0;
    final cell = iconSize + 22;

    final rows = <List<_App>>[];
    for (int i = 0; i < apps.length; i += perRow) {
      rows.add(apps.sublist(i, (i + perRow).clamp(0, apps.length)));
    }

    final grid = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int r = 0; r < rows.length; r++) ...[
          if (r > 0) const SizedBox(height: VSpace.md),
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final a in rows[r])
                SizedBox(
                  width: cell,
                  child: _AppIcon(
                    index: apps.indexOf(a),
                    app: a,
                    size: iconSize,
                    onTap: () {
                      onClose();
                      a.onTap();
                    },
                  ),
                ),
            ],
          ),
        ],
      ],
    );

    // Depth of field only around each app: a soft halo behind every icon, nothing else on the screen touched.
    return Stack(
      fit: StackFit.expand,
      children: [
        VScrim(onTap: onClose, soft: true),
        Center(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Padding(padding: const EdgeInsets.all(12), child: grid),
              Positioned(
                top: -6,
                right: -6,
                child: VCircleButton(icon: Icons.close_rounded, size: 26, tooltip: 'Close', floating: true, onTap: onClose),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _App {
  final String label;
  final List<Color> colors;
  final Widget Function(double size) art;
  final VoidCallback onTap;
  const _App(this.label, this.colors, this.art, this.onTap);
}

class _AppIcon extends StatelessWidget {
  final _App app;
  final double size;
  final int index;
  final VoidCallback onTap;
  const _AppIcon({required this.app, required this.size, required this.onTap, this.index = 0});

  @override
  Widget build(BuildContext context) {
    // Icons rise into place one after another when the overlay is summoned.
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 360 + index * 45),
      curve: Curves.easeOutBack,
      builder: (_, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.translate(offset: Offset(0, (1 - t) * 18), child: Transform.scale(scale: 0.85 + 0.15 * t, child: child)),
      ),
      child: VPress(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                // the halos lie outside the icon and take no room
                for (final (grow, sigma) in const [(28.0, 2.0), (20.0, 4.0), (12.0, 7.0), (5.0, 10.0)])
                  Positioned(left: -grow / 2, top: -grow / 2, child: _Halo(size + grow, sigma)),
                Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: app.colors),
                boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 14, offset: Offset(0, 7))],
              ),
              child: ClipOval(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    app.art(size),
                    // light from above, as on every app icon (the made icons carry their own)
                    if (app.art(size) is! _Made)
                    Align(
                      alignment: Alignment.topCenter,
                      child: Container(
                        height: size * 0.5,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x40FFFFFF), Color(0x00FFFFFF)]),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
              ],
            ),
            const SizedBox(height: VSpace.xs - 2),
            // Every label gets two lines of room. One long name then cannot make its row taller
            // than the rest and push the grid out of rhythm.
            SizedBox(
              height: 29,
              child: Text(
                app.label,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: VType.caption(color: VColors.textPrimary, weight: FontWeight.w500).copyWith(shadows: const [Shadow(color: Color(0xB3000000), blurRadius: 8)]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The room out of focus in a circle of [d] around an icon.
class _Halo extends StatelessWidget {
  final double d;
  final double sigma;
  const _Halo(this.d, this.sigma);
  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: SizedBox(
          width: d,
          height: d,
          child: ClipOval(child: BackdropFilter(filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma), child: const SizedBox.expand())),
        ),
      );
}

const _ink = Colors.white;
const _lift = [BoxShadow(color: Color(0x40000000), blurRadius: 5, offset: Offset(0, 2))];

/// Smart Gen: a hand of cards.
class _Cards extends StatelessWidget {
  final double s;
  const _Cards(this.s);

  Widget _card(double angle, double dx, Color c, {bool lines = false}) => Transform.translate(
        offset: Offset(dx, 0),
        child: Transform.rotate(
          angle: angle,
          child: Container(
            width: s * 0.34,
            height: s * 0.46,
            padding: EdgeInsets.all(s * 0.05),
            decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(s * 0.07), boxShadow: _lift),
            child: lines
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(height: s * 0.045, width: s * 0.2, decoration: BoxDecoration(color: const Color(0xFF6D4CF0), borderRadius: BorderRadius.circular(9))),
                      SizedBox(height: s * 0.04),
                      Container(height: s * 0.035, width: s * 0.14, decoration: BoxDecoration(color: const Color(0x666D4CF0), borderRadius: BorderRadius.circular(9))),
                    ],
                  )
                : null,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            _card(-0.34, -s * 0.13, const Color(0x73FFFFFF)),
            _card(0.30, s * 0.13, const Color(0xA6FFFFFF)),
            _card(0, 0, _ink, lines: true),
          ],
        ),
      );
}

/// Discover Market: a compass.
class _Compass extends StatelessWidget {
  final double s;
  const _Compass(this.s);
  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          width: s * 0.62,
          height: s * 0.62,
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: _ink, width: s * 0.045)),
          alignment: Alignment.center,
          child: Transform.rotate(angle: math.pi / 4, child: Icon(Icons.navigation_rounded, size: s * 0.36, color: _ink)),
        ),
      );
}

/// The two wallpaper destinations show wallpapers: a still for the gallery, one that plays for the live ones.
class _Picture extends StatelessWidget {
  final String asset;
  final double s;
  final bool framed;
  final bool playing;
  const _Picture(this.asset, this.s, {this.framed = false, this.playing = false});
  @override
  Widget build(BuildContext context) => Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(asset, fit: BoxFit.cover, filterQuality: FilterQuality.medium),
          if (framed)
            Center(
              child: Container(
                width: s * 0.5,
                height: s * 0.38,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(s * 0.06),
                  border: Border.all(color: _ink, width: s * 0.04),
                  boxShadow: _lift,
                ),
              ),
            ),
          if (playing) ...[
            const DecoratedBox(decoration: BoxDecoration(color: Color(0x33000000))),
            Center(child: Icon(Icons.play_arrow_rounded, size: s * 0.56, color: _ink, shadows: const [Shadow(color: Color(0x80000000), blurRadius: 8)])),
          ],
        ],
      );
}

/// Files: a folder.
class _Folder extends StatelessWidget {
  final double s;
  const _Folder(this.s);
  @override
  Widget build(BuildContext context) => Center(
        child: SizedBox(
          width: s * 0.56,
          height: s * 0.44,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                top: 0,
                child: Container(
                  width: s * 0.26,
                  height: s * 0.14,
                  decoration: BoxDecoration(color: const Color(0xD9FFFFFF), borderRadius: BorderRadius.circular(s * 0.05)),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: s * 0.07,
                bottom: 0,
                child: Container(decoration: BoxDecoration(color: _ink, borderRadius: BorderRadius.circular(s * 0.07), boxShadow: _lift)),
              ),
            ],
          ),
        ),
      );
}

/// Music Player: sound, as bars.
class _Bars extends StatelessWidget {
  final double s;
  const _Bars(this.s);
  @override
  Widget build(BuildContext context) => Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            for (final h in const [0.20, 0.42, 0.56, 0.30, 0.46, 0.18]) ...[
              Container(
                width: s * 0.06,
                height: s * h,
                margin: EdgeInsets.symmetric(horizontal: s * 0.022),
                decoration: BoxDecoration(color: _ink, borderRadius: BorderRadius.circular(9), boxShadow: _lift),
              ),
            ],
          ],
        ),
      );
}

/// Browser: the world.
class _Globe extends StatelessWidget {
  final double s;
  const _Globe(this.s);
  @override
  Widget build(BuildContext context) => Center(child: Icon(Icons.language_rounded, size: s * 0.66, color: _ink));
}

/// An icon made outside the app, drawn as it was made.
class _Made extends StatelessWidget {
  final String asset;
  const _Made(this.asset);
  @override
  Widget build(BuildContext context) => Image.asset(asset, fit: BoxFit.cover, filterQuality: FilterQuality.medium);
}
