// E.D. — Collider — Signed: Gemini 4 Argon (2026-10-27)
import 'package:material_ui/material_ui.dart';
import '../../../models/ticker_item.dart';
import '../../../core/vision/vision_kit.dart';

/// One model's row in the ticker.
/// Active models sit pinned at the top with emissive provider light bloom; unselected models remain in place
/// below (dimmed) while retaining their 2-line 11pt summary. Tap an unselected model to activate it;
/// swipe horizontally L/R on an active model to deactivate it (R08).
class ModelPill extends StatefulWidget {
  final TickerItem item;

  /// This model's conversation is expanded inline inside the ticker column.
  final bool isExpanded;
  final VoidCallback onToggleExpand;
  final VoidCallback? onDeactivate;
  final double elevation;
  final bool compact;

  /// Selected: questions go to this model.
  final bool isActive;

  /// Inline expanded conversation widget rendered smoothly inside this pill.
  final Widget? expandedChild;

  const ModelPill({
    super.key,
    required this.item,
    required this.isExpanded,
    required this.onToggleExpand,
    this.onDeactivate,
    this.elevation = 0,
    this.compact = false,
    this.isActive = true,
    this.expandedChild,
  });

  /// The lit row's corners: the window's corner (28) less the window's inner margin (12) = 16 (concentric).
  static const double radius = VRadius.row;

  @override
  State<ModelPill> createState() => _ModelPillState();
}

class _ModelPillState extends State<ModelPill> {
  String get _liveText {
    final conv = widget.item.conversation;
    for (var i = conv.length - 1; i >= 0; i--) {
      if (conv[i].sender != 'user') return conv[i].text;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final active = widget.isActive;
    final waiting = active && item.isStreaming;
    final hue = item.modelDef.providerColor;
    final name = VType.callout(
      color: active ? VColors.textPrimary : VColors.textSecondary,
      weight: active ? FontWeight.w600 : FontWeight.w500,
    );
    final time = VType.caption(color: VColors.textTertiary, weight: FontWeight.w500);
    final live = _liveText;
    // Both active and unselected models retain their 2-line summary in place (R08), or stream live tokens.
    final hasSummary = item.summary.isNotEmpty || waiting || live.isNotEmpty;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragEnd: active && widget.onDeactivate != null
          ? (d) {
              if ((d.primaryVelocity ?? 0).abs() > 140) {
                widget.onDeactivate!();
              }
            }
          : null,
      child: AnimatedOpacity(
        duration: VMotion.base,
        opacity: active ? 1.0 : 0.76,
        child: VPress(
          onTap: widget.onToggleExpand,
          child: AnimatedContainer(
            duration: VMotion.base,
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: widget.isExpanded
                  ? const Color(0x2E0B0F19)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(ModelPill.radius),
              border: widget.isExpanded
                  ? Border.all(color: const Color(0x33FFFFFF), width: 0.6)
                  : null,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  VAmbientPulse(
                    active: waiting,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: active ? hue : hue.withValues(alpha: 0.45),
                        boxShadow: active ? VShadow.emissive(hue, intensity: 0.9) : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.modelDef.label,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      style: name,
                    ),
                  ),
                  if (active && !waiting && !widget.compact && item.relativeTime.isNotEmpty)
                    Text(item.relativeTime, style: time)
                  else if (!active)
                    Text('Tap to enable', style: VType.caption(color: VColors.textTertiary).copyWith(fontSize: 9.5)),
                ]),
                if (hasSummary && !widget.isExpanded) ...[
                  const SizedBox(height: 3),
                  // Standardized 2-line takeaway summary, or live streaming ticker while tokens arrive.
                  AnimatedSize(
                    duration: VMotion.base,
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.topCenter,
                    child: SizedBox(
                      width: double.infinity,
                      child: waiting
                          ? (live.isNotEmpty ? _LiveTicker(text: live) : const _SkeletonLines())
                          : Text(
                              item.summary.isNotEmpty ? item.summary : live,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: VType.summary(
                                color: active ? VColors.textSecondary : VColors.textTertiary,
                              ),
                            ),
                    ),
                  ),
                ],
                if (active && item.mediaUrls != null && item.mediaUrls!.isNotEmpty) ...[
                  const SizedBox(height: VSpace.xs),
                  SizedBox(
                    height: 54,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: item.mediaUrls!.length,
                      separatorBuilder: (_, __) => const SizedBox(width: VSpace.xs),
                      itemBuilder: (_, i) => ClipRRect(
                        borderRadius: BorderRadius.circular(VRadius.sm),
                        child: Image.network(
                          item.mediaUrls![i],
                          width: 54,
                          height: 54,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const SizedBox(width: 54, height: 54),
                        ),
                      ),
                    ),
                  ),
                ],
                AnimatedSize(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: widget.isExpanded && widget.expandedChild != null
                      ? Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 270),
                            child: widget.expandedChild!,
                          ),
                        )
                      : const SizedBox(width: double.infinity, height: 0),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Two soft lines, breathing, until the summary arrives.
class _SkeletonLines extends StatefulWidget {
  const _SkeletonLines();
  @override
  State<_SkeletonLines> createState() => _SkeletonLinesState();
}

class _SkeletonLinesState extends State<_SkeletonLines> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget line(double w) => FractionallySizedBox(
          widthFactor: w,
          alignment: Alignment.centerLeft,
          child: Container(
            height: 7,
            margin: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(color: const Color(0x2EFFFFFF), borderRadius: BorderRadius.circular(4)),
          ),
        );
    return FadeTransition(
      opacity: Tween(begin: 0.45, end: 1.0).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [line(0.86), line(0.58)]),
    );
  }
}

/// Live streaming words ticker that scrolls smoothly as tokens arrive before the synthesized summary settles.
class _LiveTicker extends StatelessWidget {
  final String text;
  const _LiveTicker({required this.text});

  @override
  Widget build(BuildContext context) {
    final cleaned = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    final tail = cleaned.length > 140 ? '…${cleaned.substring(cleaned.length - 140)}' : cleaned;
    return Text(
      tail,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: VType.summary(color: VColors.textPrimary),
    );
  }
}
