// Made by Claude (2026-10-23). The one detail view of the app: a message, a conversation, a file or a picture opened large.
// David, 23 Oct: "the same for all": the room behind blurred and dimmed, edge fades, action buttons with icon and
// text label, no tray holding them, the content raised off the room, cinematic. Each kind brings its own actions;
// every kind has Send, Open and Close.
import 'dart:ui';

import 'package:material_ui/material_ui.dart';

import 'vision_tokens.dart';
import 'vision_kit.dart' show VPress;

class DetailAction {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? tint; // an action that is on (a kept picture)
  const DetailAction(this.icon, this.label, this.onTap, {this.tint});
}

class DetailView extends StatefulWidget {
  /// What is opened. It sizes itself inside the room it is given and scrolls itself when it is long.
  final Widget child;

  /// This kind's own actions; Send, Open and Close follow them.
  final List<DetailAction> actions;
  final VoidCallback? onSend;
  final VoidCallback? onOpen;
  final VoidCallback onClose;

  /// How wide the content may be.
  final double maxWidth;

  const DetailView({
    super.key,
    required this.child,
    required this.onClose,
    this.actions = const [],
    this.onSend,
    this.onOpen,
    this.maxWidth = 560,
  });

  @override
  State<DetailView> createState() => _DetailViewState();
}

class _DetailViewState extends State<DetailView> with SingleTickerProviderStateMixin {
  // summoned: the room goes out of focus as the content rises toward the viewer
  late final AnimationController _in = AnimationController(vsync: this, duration: const Duration(milliseconds: 360))..forward();

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
      if (widget.onSend != null) DetailAction(Icons.ios_share_rounded, 'Send', widget.onSend),
      if (widget.onOpen != null) DetailAction(Icons.open_in_new_rounded, 'Open', widget.onOpen),
      DetailAction(Icons.close_rounded, 'Close', widget.onClose),
    ];
    return AnimatedBuilder(
      animation: t,
      builder: (context, _) {
        final v = t.value;
        return Stack(fit: StackFit.expand, children: [
          // The room: out of focus, and darker toward the top and bottom edges than behind the content, so the eye
          // settles in the middle.
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
                        Color.fromRGBO(0, 0, 0, 0.72 * v),
                        Color.fromRGBO(0, 0, 0, 0.42 * v),
                        Color.fromRGBO(0, 0, 0, 0.42 * v),
                        Color.fromRGBO(0, 0, 0, 0.80 * v),
                      ],
                      stops: const [0, 0.3, 0.62, 1],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              // the actions end just above the dock, within the thumb's reach
              padding: const EdgeInsets.fromLTRB(VSpace.md, VSpace.md, VSpace.md, 92),
              child: Column(children: [
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: widget.maxWidth),
                      child: Opacity(
                        opacity: v,
                        child: Transform.translate(
                          offset: Offset(0, 14 * (1 - v)),
                          child: Transform.scale(scale: 0.94 + 0.06 * v, child: widget.child),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: VSpace.sm),
                Opacity(
                  opacity: v,
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 6,
                    runSpacing: 6,
                    children: [for (final a in all) _ActionButton(a)],
                  ),
                ),
              ]),
            ),
          ),
        ]);
      },
    );
  }
}

/// An action: its glyph on a glass disc and its name under it. No tray behind the row.
class _ActionButton extends StatelessWidget {
  final DetailAction a;
  const _ActionButton(this.a);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: a.label,
      child: VPress(
        onTap: a.onTap,
        child: SizedBox(
          width: 60,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ClipOval(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0x33FFFFFF)),
                  child: Icon(a.icon, size: 20, color: a.tint ?? VColors.textPrimary),
                ),
              ),
            ),
            const SizedBox(height: 5),
            Text(a.label,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.fade,
                style: VType.caption(color: const Color(0xE6FFFFFF), weight: FontWeight.w500)
                    .copyWith(shadows: const [Shadow(color: Color(0x99000000), blurRadius: 8)])),
          ]),
        ),
      ),
    );
  }
}

/// Raised content: a soft shadow under it, as if lifted toward the viewer.
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
