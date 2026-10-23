import 'package:material_ui/material_ui.dart';
import '../../../models/ticker_item.dart';
import '../../../core/vision/vision_kit.dart';

/// One model's row in the ticker: its name, status/time, and its 1-to-2 line summary.
/// Active models sit at the top of the container and remain lit with their provider glow;
/// inactive models sit below and are visually dimmed.
class ModelPill extends StatefulWidget {
  final TickerItem item;
  final bool isExpanded;
  final VoidCallback onToggleExpand;
  final double elevation;
  final bool compact;
  final bool isActive;

  const ModelPill({
    super.key,
    required this.item,
    required this.isExpanded,
    required this.onToggleExpand,
    this.elevation = 0,
    this.compact = false,
    this.isActive = true,
  });

  @override
  State<ModelPill> createState() => _ModelPillState();
}

class _ModelPillState extends State<ModelPill> {
  static const List<String> _fallbackMediaUrls = [
    'https://collider-media.ebridavid.workers.dev/free/starbridge.jpg',
    'https://collider-media.ebridavid.workers.dev/free/sanctuary.jpg',
    'https://collider-media.ebridavid.workers.dev/free/observatory.jpg',
    'https://collider-media.ebridavid.workers.dev/free/neoncity.jpg',
  ];

  String _resolveMediaUrl(String raw, int i) {
    if (raw.startsWith('http://') || raw.startsWith('https://') || raw.startsWith('/api/')) {
      return raw;
    }
    return _fallbackMediaUrls[i % _fallbackMediaUrls.length];
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final c = item.modelDef.providerColor;
    final active = widget.isActive;
    final e = widget.isExpanded ? 1.0 : (active ? widget.elevation.clamp(0.25, 1.0) : 0.0);
    final top = active
        ? Color.lerp(c.withValues(alpha: 0.24), c.withValues(alpha: 0.36), e)!
        : const Color(0x24141620);
    final bottom = active
        ? Color.lerp(c.withValues(alpha: 0.10), c.withValues(alpha: 0.16), e)!
        : const Color(0x1810121A);
    final waiting = item.isStreaming;

    final metaStyle = VType.caption(
      color: active ? const Color(0xE6FFFFFF) : VColors.textTertiary,
      weight: active ? FontWeight.w600 : FontWeight.w500,
    ).copyWith(fontSize: 11, height: 14 / 11);

    final timeStyle = VType.caption(
      color: active ? VColors.textSecondary : VColors.textTertiary,
      weight: FontWeight.w500,
    ).copyWith(fontSize: 10.5, height: 13 / 10.5);

    return AnimatedOpacity(
      duration: VMotion.base,
      curve: Curves.easeOutCubic,
      opacity: active ? 1.0 : 0.44,
      child: VPress(
        onTap: widget.onToggleExpand,
        child: AnimatedContainer(
          duration: VMotion.base,
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.alphaBlend(top, VColors.fillRow),
                Color.alphaBlend(bottom, VColors.fillRow),
              ],
            ),
            borderRadius: BorderRadius.circular(VRadius.row),
            border: Border.all(
              color: active ? c.withValues(alpha: 0.46) : const Color(0x18FFFFFF),
              width: active ? 0.8 : 0.5,
            ),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: c.withValues(alpha: 0.12 * e),
                      blurRadius: 12,
                      offset: const Offset(0, 2),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.10 + 0.10 * e),
                      blurRadius: 8 + 10 * e,
                      offset: Offset(0, 2 + 4 * e),
                    ),
                  ]
                : const [],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: active ? c : c.withValues(alpha: 0.38),
                      boxShadow: active
                          ? [
                              BoxShadow(
                                color: c.withValues(alpha: 0.85),
                                blurRadius: 6,
                              ),
                            ]
                          : null,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      item.modelDef.label,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.fade,
                      style: metaStyle,
                    ),
                  ),
                  if (waiting)
                    _Pulse(color: c)
                  else if (!widget.compact)
                    Text(
                      active ? item.relativeTime : (item.relativeTime.isNotEmpty ? item.relativeTime : 'Inactive'),
                      style: timeStyle,
                    ),
                ],
              ),
              const SizedBox(height: 4),
              AnimatedSize(
                duration: VMotion.base,
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 18),
                  child: AnimatedSwitcher(
                    duration: VMotion.base,
                    layoutBuilder: (cur, prev) => Stack(
                      alignment: Alignment.topLeft,
                      children: [...prev, if (cur != null) cur],
                    ),
                    child: waiting && item.summary.isEmpty
                        ? _SkeletonLines(key: const ValueKey('wait'), color: c)
                        : SizedBox(
                            key: ValueKey(item.summary),
                            width: double.infinity,
                            child: Text(
                              item.summary.isNotEmpty ? item.summary : (active ? 'Ready' : 'Inactive model'),
                              maxLines: widget.isExpanded ? null : 2,
                              overflow: widget.isExpanded ? null : TextOverflow.ellipsis,
                              style: VOneLine.rowStyle.copyWith(
                                color: active ? VColors.textPrimary : VColors.textSecondary,
                              ),
                            ),
                          ),
                  ),
                ),
              ),
              if (item.mediaUrls != null && item.mediaUrls!.isNotEmpty) ...[
                const SizedBox(height: VSpace.xs),
                SizedBox(
                  height: 58,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: item.mediaUrls!.length,
                    separatorBuilder: (_, __) => const SizedBox(width: VSpace.xs),
                    itemBuilder: (_, i) => ClipRRect(
                      borderRadius: BorderRadius.circular(VRadius.sm),
                      child: Image.network(
                        _resolveMediaUrl(item.mediaUrls![i], i),
                        width: 58,
                        height: 58,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 58,
                          height: 58,
                          color: VColors.fillCell,
                          child: const Icon(CupertinoIcons.photo, size: 18, color: VColors.textTertiary),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Quiet breathing dot while a model is answering.
class _Pulse extends StatefulWidget {
  final Color color;
  const _Pulse({required this.color});
  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.35, end: 1.0).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut)),
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      ),
    );
  }
}

/// Shimmering placeholder lines shown until the answer arrives.
class _SkeletonLines extends StatefulWidget {
  final Color color;
  const _SkeletonLines({super.key, required this.color});
  @override
  State<_SkeletonLines> createState() => _SkeletonLinesState();
}

class _SkeletonLinesState extends State<_SkeletonLines> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        Widget line(double w) => FractionallySizedBox(
              widthFactor: w,
              alignment: Alignment.centerLeft,
              child: Container(
                height: 8,
                margin: const EdgeInsets.symmetric(vertical: 2.5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(5),
                  gradient: LinearGradient(
                    begin: Alignment(-1.5 + 3 * _c.value, 0),
                    end: Alignment(-0.5 + 3 * _c.value, 0),
                    colors: [
                      Colors.white.withValues(alpha: 0.08),
                      widget.color.withValues(alpha: 0.35),
                      Colors.white.withValues(alpha: 0.08),
                    ],
                  ),
                ),
              ),
            );
        return SizedBox(
          width: double.infinity,
          child: Column(mainAxisSize: MainAxisSize.min, children: [line(0.86), line(0.58)]),
        );
      },
    );
  }
}
