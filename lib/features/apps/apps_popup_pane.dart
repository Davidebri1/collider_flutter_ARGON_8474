import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import '../../core/vision/vision_kit.dart';

/// REQ-01 App Grid (Vision OS Design System 2:6774, visionOS Home 97:34752):
/// circular app icons float directly over the environment in offset rows - no platter.
/// David, 4 Oct 2026: "consider only DOF blurring around the icons here. you dont need to take over full
/// attention ... keep the field of view clean." So the room goes out of focus only in a soft halo around each
/// icon, and stays sharp everywhere else. Escapes: a tap anywhere else, or the cross beside the icons.
///
/// Icons redrawn by Claude on 2026-10-20 after Apple's visionOS app icon guidance (dev/make_icons.py):
/// each app its own colour (Apple's system colours) and a background layer under two filled foreground layers,
/// the rear one translucent, with shadows between them for depth. The same colour marks the app everywhere else.
class AppsPopupPane extends StatelessWidget {
  final VoidCallback onClose;
  final VoidCallback onOpenSmartGen;
  final VoidCallback onOpenDiscoverMarket;
  final VoidCallback onOpenThemeGallery;
  final VoidCallback onOpenPremiumMarketplace;
  final VoidCallback onOpenFiles;
  final VoidCallback onOpenMusicPlayer;
  final VoidCallback onOpenBrowser;
  final VoidCallback onOpenDocuments;

  /// Kept for callers; the icons no longer show a wallpaper.
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
    required this.onOpenDocuments,
    this.themeArt,
  });

  @override
  Widget build(BuildContext context) {
    final apps = [
      _App('Smart Gen', 'smart_gen', onOpenSmartGen),
      _App('Discover Market', 'discover', onOpenDiscoverMarket),
      _App('Documents', 'documents', onOpenDocuments),
      _App('Files', 'files', onOpenFiles),
      _App('Theme Gallery', 'theme_gallery', onOpenThemeGallery),
      _App('Premium Theme Market', 'premium_market', onOpenPremiumMarketplace),
      _App('Music Player', 'music', onOpenMusicPlayer),
      _App('Browser', 'browser', onOpenBrowser),
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
  final String art; // assets/icons/apps/claude_app_<art>.png
  final VoidCallback onTap;
  const _App(this.label, this.art, this.onTap);
}

class _AppIcon extends StatefulWidget {
  final _App app;
  final double size;
  final int index;
  final VoidCallback onTap;
  const _AppIcon({required this.app, required this.size, required this.onTap, this.index = 0});

  @override
  State<_AppIcon> createState() => _AppIconState();
}

class _AppIconState extends State<_AppIcon> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    // Icons rise into place one after another when the overlay is summoned; one looked at swells a little,
    // as a visionOS icon does under the eyes.
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 360 + widget.index * 45),
      curve: Curves.easeOutBack,
      builder: (_, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.translate(offset: Offset(0, (1 - t) * 18), child: Transform.scale(scale: 0.85 + 0.15 * t, child: child)),
      ),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: VPress(
          onTap: widget.onTap,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  // the halos lie outside the icon and take no room
                  for (final (grow, sigma) in const [(28.0, 2.0), (20.0, 4.0), (12.0, 7.0), (5.0, 10.0)])
                    Positioned(left: -grow / 2, top: -grow / 2, child: _Halo(size + grow, sigma)),
                  AnimatedScale(
                    scale: _hover ? 1.06 : 1.0,
                    duration: VMotion.fast,
                    curve: Curves.easeOutCubic,
                    child: Container(
                      width: size,
                      height: size,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: const Color(0x66000000), blurRadius: _hover ? 20 : 14, offset: Offset(0, _hover ? 10 : 7))],
                      ),
                      child: ClipOval(
                        child: Image.asset('assets/icons/apps/claude_app_${widget.app.art}.png',
                            width: size, height: size, fit: BoxFit.cover, filterQuality: FilterQuality.high),
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
                  widget.app.label,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: VType.caption(color: VColors.textPrimary, weight: FontWeight.w500).copyWith(shadows: const [Shadow(color: Color(0xB3000000), blurRadius: 8)]),
                ),
              ),
            ],
          ),
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
