// Unified DetailView (Message Zoom, Picture Viewer, File Preview):
// Centered hologram projection with vertical edge fades and pure elevated floating action words directly underneath.
import 'dart:ui';

import 'package:material_ui/material_ui.dart';

import 'vision_tokens.dart';
import 'vision_kit.dart' show VMotion, VPress;

class DetailAction {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? tint;
  const DetailAction(this.icon, this.label, this.onTap, {this.tint});
}

class DetailView extends StatefulWidget {
  final Widget child;
  final List<DetailAction> actions;
  final VoidCallback? onSend;
  final VoidCallback? onOpen;
  final VoidCallback onClose;
  final bool media;

  static double zoneWidth(BuildContext context, {bool media = false}) {
    final phone = MediaQuery.sizeOf(context).width < 768;
    return phone ? (media ? 356 : 310) : (media ? 760 : 480);
  }

  static double zoneHeight(BuildContext context) {
    final m = MediaQuery.of(context);
    return (m.size.height - m.padding.top - m.padding.bottom - 180).clamp(220.0, 520.0);
  }

  const DetailView({
    super.key,
    required this.child,
    required this.onClose,
    this.actions = const [],
    this.onSend,
    this.onOpen,
    this.media = false,
  });

  @override
  State<DetailView> createState() => _DetailViewState();
}

class _DetailViewState extends State<DetailView> with SingleTickerProviderStateMixin {
  late final AnimationController _in = AnimationController(vsync: this, duration: const Duration(milliseconds: 520))..forward();

  @override
  void dispose() {
    _in.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = CurvedAnimation(parent: _in, curve: Curves.easeOutCubic);
    final all = [
      ...widget.actions,
      if (widget.onSend != null) DetailAction(Icons.ios_share_rounded, 'Share', widget.onSend),
      if (widget.onOpen != null) DetailAction(Icons.open_in_new_rounded, 'Open', widget.onOpen),
      DetailAction(Icons.close_rounded, 'Close', widget.onClose),
    ];
    return AnimatedBuilder(
      animation: t,
      builder: (context, _) {
        final v = t.value;
        return Stack(fit: StackFit.expand, children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onClose,
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 24 * v, sigmaY: 24 * v),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color.fromRGBO(6, 8, 14, 0.68 * v),
                        Color.fromRGBO(6, 8, 14, 0.42 * v),
                        Color.fromRGBO(6, 8, 14, 0.42 * v),
                        Color.fromRGBO(6, 8, 14, 0.74 * v),
                      ],
                      stops: const [0, 0.28, 0.68, 1],
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Centered hologram projection with elevated floating words directly underneath (no UI boxes or circles).
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(VSpace.md, VSpace.md, VSpace.md, 76),
              child: Center(
                child: SizedBox(
                  width: DetailView.zoneWidth(context, media: widget.media),
                  child: Opacity(
                    opacity: v,
                    child: Transform.translate(
                      offset: Offset(0, 18 * (1 - v)),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Transform.scale(
                              scale: 0.94 + 0.06 * v,
                              child: widget.child,
                            ),
                          ),
                          const SizedBox(height: 18),
                          // Pure elevated floating words — no pill boxes, no circle icons.
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              for (int i = 0; i < all.length; i++) ...[
                                if (i > 0) const SizedBox(width: 24),
                                _ElevatedActionWord(all[i]),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ]);
      },
    );
  }
}

class _ElevatedActionWord extends StatefulWidget {
  final DetailAction a;
  const _ElevatedActionWord(this.a);

  @override
  State<_ElevatedActionWord> createState() => _ElevatedActionWordState();
}

class _ElevatedActionWordState extends State<_ElevatedActionWord> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.a.label,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: VPress(
          onTap: widget.a.onTap,
          child: AnimatedDefaultTextStyle(
            duration: VMotion.fast,
            style: VType.callout(
              color: _hover ? VColors.textPrimary : VColors.textSecondary,
              weight: _hover ? FontWeight.w600 : FontWeight.w500,
            ).copyWith(
              letterSpacing: 0.9,
              shadows: [
                Shadow(
                  color: _hover ? const Color(0x88FFFFFF) : const Color(0xCC000000),
                  blurRadius: _hover ? 14 : 18,
                  offset: const Offset(0, 4),
                ),
                const Shadow(
                  color: Color(0x99000000),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Text(widget.a.label),
            ),
          ),
        ),
      ),
    );
  }
}

class DetailRaised extends StatelessWidget {
  final Widget child;
  final double radius;
  const DetailRaised({super.key, required this.child, this.radius = 16});

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          boxShadow: const [BoxShadow(color: Color(0x8C000000), blurRadius: 48, offset: Offset(0, 22))],
        ),
        child: ClipRRect(borderRadius: BorderRadius.circular(radius), child: child),
      );
}
