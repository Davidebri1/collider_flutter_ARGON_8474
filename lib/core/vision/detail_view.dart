// Unified DetailView (Message Zoom, Picture Viewer, File Preview):
// Centered hologram projection with vertical edge fades and action context paired directly underneath.
import 'dart:ui';

import 'package:material_ui/material_ui.dart';

import 'vision_tokens.dart';
import 'vision_kit.dart' show VGlass, VMaterial, VPress, VShadow, vHueFor;

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
  late final AnimationController _in = AnimationController(vsync: this, duration: const Duration(milliseconds: 320))..forward();

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
                filter: ImageFilter.blur(sigmaX: 22 * v, sigmaY: 22 * v),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color.fromRGBO(6, 8, 14, 0.72 * v),
                        Color.fromRGBO(6, 8, 14, 0.46 * v),
                        Color.fromRGBO(6, 8, 14, 0.46 * v),
                        Color.fromRGBO(6, 8, 14, 0.78 * v),
                      ],
                      stops: const [0, 0.28, 0.68, 1],
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Centered hologram projection with paired action capsule directly underneath.
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(VSpace.md, VSpace.md, VSpace.md, 76),
              child: Center(
                child: SizedBox(
                  width: DetailView.zoneWidth(context, media: widget.media),
                  child: Opacity(
                    opacity: v,
                    child: Transform.translate(
                      offset: Offset(0, 12 * (1 - v)),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Transform.scale(
                              scale: 0.95 + 0.05 * v,
                              child: widget.child,
                            ),
                          ),
                          const SizedBox(height: 10),
                          // Paired directly beneath the zoomed content, centered as a cohesive ornament.
                          VGlass(
                            material: VMaterial.elevated,
                            radius: VRadius.full,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                for (int i = 0; i < all.length; i++) ...[
                                  if (i > 0) const SizedBox(width: 8),
                                  _ActionButton(all[i]),
                                ],
                              ],
                            ),
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

class _ActionButton extends StatelessWidget {
  final DetailAction a;
  const _ActionButton(this.a);

  @override
  Widget build(BuildContext context) {
    final hue = a.tint ?? vHueFor(a.icon) ?? VColors.textPrimary;
    return Semantics(
      button: true,
      label: a.label,
      child: VPress(
        onTap: a.onTap,
        tooltip: a.label,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(VRadius.full),
            color: VColors.fillCell,
            border: Border.all(color: VColors.borderSubtle, width: 0.6),
            boxShadow: a.tint != null ? VShadow.emissive(a.tint!, intensity: 0.4, radius: 10) : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(a.icon, size: 15, color: hue),
              const SizedBox(width: 4),
              Text(
                a.label,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: VType.caption(color: VColors.textPrimary, weight: FontWeight.w600),
              ),
            ],
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
