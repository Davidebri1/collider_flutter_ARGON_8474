import 'package:material_ui/material_ui.dart';
import '../../../models/ticker_item.dart';
import '../../../core/vision/vision_kit.dart';

/// One model's row in the ticker: its name, when it answered, and its answer in one line.
/// The row is the collapsed state (David's map, row 15: "Collapsed is left column"). Tapping it opens the
/// model's conversation, which is its own view (conversation_view.dart), not something inside the row.
/// Each model owns a colour across its whole row, and rows sit higher as they go up.
class ModelPill extends StatefulWidget {
  final TickerItem item;

  /// This model's conversation is the one that is open.
  final bool isExpanded;
  final VoidCallback onToggleExpand;

  /// 0 = resting (bottom of the stack) to 1 = highest row.
  final double elevation;

  const ModelPill({
    super.key,
    required this.item,
    required this.isExpanded,
    required this.onToggleExpand,
    this.elevation = 0,
  });

  @override
  State<ModelPill> createState() => _ModelPillState();
}

class _ModelPillState extends State<ModelPill> {
  static const List<String> _mediaAssets = ['aurora_drift', 'ember_fall', 'nebula_bloom', 'low_tide'];
  String _mediaAssetFor(int i) => _mediaAssets[i % _mediaAssets.length];

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final c = item.modelDef.providerColor;
    final e = widget.isExpanded ? 1.0 : widget.elevation.clamp(0.0, 1.0);
    final top = Color.lerp(c.withValues(alpha: 0.20), c.withValues(alpha: 0.30), e)!;
    final bottom = Color.lerp(c.withValues(alpha: 0.07), c.withValues(alpha: 0.12), e)!;
    final waiting = item.isStreaming;

    // The row exists for its summary line, so that line has the row's full width.
    final meta = VType.caption(color: VColors.textSecondary, weight: FontWeight.w500).copyWith(fontSize: 10.5, height: 14 / 10.5);
    return VPress(
      onTap: widget.onToggleExpand,
      child: AnimatedContainer(
        duration: VMotion.base,
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color.alphaBlend(top, VColors.fillRow), Color.alphaBlend(bottom, VColors.fillRow)],
          ),
          borderRadius: BorderRadius.circular(VRadius.row),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06 + 0.14 * e),
              blurRadius: 8 + 16 * e,
              offset: Offset(0, 2 + 6 * e),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 14,
              child: Row(
                children: [
                  Expanded(child: Text(item.modelDef.label, maxLines: 1, softWrap: false, overflow: TextOverflow.fade, style: meta)),
                  if (waiting) _Pulse(color: c) else Text(item.relativeTime, style: meta),
                ],
              ),
            ),
            const SizedBox(height: 3),
            AnimatedSwitcher(
              duration: VMotion.base,
              layoutBuilder: (cur, prev) => Stack(alignment: Alignment.topLeft, children: [...prev, if (cur != null) cur]),
              child: waiting && item.summary.isEmpty ? _SkeletonLines(key: const ValueKey('wait'), color: c) : VOneLine(key: ValueKey(item.summary), text: item.summary),
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
                    child: Image.asset('https://collider-media.ebridavid.workers.dev/premium/${_mediaAssetFor(i)}.jpg', width: 58, height: 58, fit: BoxFit.cover),
                  ),
                ),
              ),
            ],
          ],
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
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true);
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.35, end: 1.0).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut)),
      child: Container(width: 8, height: 8, decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle)),
    );
  }
}

/// Shimmering placeholder line shown until the answer arrives.
class _SkeletonLines extends StatefulWidget {
  final Color color;
  const _SkeletonLines({super.key, required this.color});
  @override
  State<_SkeletonLines> createState() => _SkeletonLinesState();
}

class _SkeletonLinesState extends State<_SkeletonLines> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();
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
                height: 9,
                margin: const EdgeInsets.symmetric(vertical: 5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(5),
                  gradient: LinearGradient(
                    begin: Alignment(-1.5 + 3 * _c.value, 0),
                    end: Alignment(-0.5 + 3 * _c.value, 0),
                    colors: [Colors.white.withValues(alpha: 0.08), widget.color.withValues(alpha: 0.35), Colors.white.withValues(alpha: 0.08)],
                  ),
                ),
              ),
            );
        return SizedBox(width: double.infinity, child: line(0.78));
      },
    );
  }
}
