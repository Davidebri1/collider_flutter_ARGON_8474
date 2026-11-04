import 'package:material_ui/material_ui.dart';
import '../../core/vision/vision_kit.dart';

/// REQ-01 App Grid (Vision OS Design System 2:6774, visionOS Home 97:34752):
/// circular app icons float directly over a spatial depth-of-field backdrop.
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
    // R13 & D4: Seven apps on the platter (Smart Gen, Discover Market, Theme Gallery, Premium Theme Marketplace, Files, Music Player, Browser).
    final apps = [
      _App('Smart Gen', 'smart_gen', onOpenSmartGen),
      _App('Discover Market', 'discover', onOpenDiscoverMarket),
      _App('Theme Gallery', 'theme_gallery', onOpenThemeGallery),
      _App('Premium Market', 'premium_market', onOpenPremiumMarketplace),
      _App('Files', 'files', onOpenFiles),
      _App('Music Player', 'music', onOpenMusicPlayer),
      _App('Browser', 'browser', onOpenBrowser),
    ];

    final size = MediaQuery.of(context).size;
    const perRow = 4;
    final iconSize = size.width < 480 ? 38.0 : 44.0;
    final cell = iconSize + 18;

    final rows = <List<_App>>[];
    for (int i = 0; i < apps.length; i += perRow) {
      rows.add(apps.sublist(i, (i + perRow).clamp(0, apps.length)));
    }

    final grid = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int r = 0; r < rows.length; r++) ...[
          if (r > 0) const SizedBox(height: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
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

    return Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: onClose,
          child: const SizedBox.expand(),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 68,
          child: Center(
            child: GestureDetector(
              onTap: () {},
              child: VGlass(
                material: VMaterial.modal,
                radius: VRadius.lg,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                child: grid,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _App {
  final String label;
  final String art;
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
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 320 + widget.index * 40),
      curve: Curves.easeOutBack,
      builder: (_, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 16),
          child: Transform.scale(scale: 0.86 + 0.14 * t, child: child),
        ),
      ),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: VPress(
          onTap: widget.onTap,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedScale(
                scale: _hover ? 1.07 : 1.0,
                duration: VMotion.fast,
                curve: Curves.easeOutCubic,
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _hover ? const Color(0x66FFFFFF) : const Color(0x28FFFFFF),
                      width: _hover ? 1.2 : 0.7,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0x73000000),
                        blurRadius: _hover ? 22 : 14,
                        offset: Offset(0, _hover ? 10 : 7),
                      ),
                      if (_hover)
                        const BoxShadow(
                          color: Color(0x33FFFFFF),
                          blurRadius: 16,
                          spreadRadius: 1,
                        ),
                    ],
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/icons/apps/claude_app_${widget.app.art}.png',
                      width: size,
                      height: size,
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: VSpace.xs - 1),
              SizedBox(
                height: 30,
                child: Text(
                  widget.app.label,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: VType.caption(
                    color: _hover ? Colors.white : VColors.textPrimary,
                    weight: _hover ? FontWeight.w600 : FontWeight.w500,
                  ).copyWith(shadows: const [Shadow(color: Color(0xCC000000), blurRadius: 8)]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
