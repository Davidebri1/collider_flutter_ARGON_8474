import 'package:material_ui/material_ui.dart';
import '../../../core/vision/vision_kit.dart';

/// Pinned consensus preview at the top of the Ticker.
/// Displays the glowing agreement ratio badge and a clean 1-to-2 line consensus summary.
/// Tapping opens the 3D Consensus Galaxy map.
class ConsensusRow extends StatelessWidget {
  final String agreementRatio;
  final String summary;
  final bool isGenerating;
  final VoidCallback? onGenerateConsensus;
  final VoidCallback? onTap;

  const ConsensusRow({
    super.key,
    required this.agreementRatio,
    required this.summary,
    this.onGenerateConsensus,
    this.onTap,
    this.isGenerating = false,
  });

  @override
  Widget build(BuildContext context) {
    final score = agreementRatio.replaceAll('Consensus', '').trim();
    final m = RegExp(r'^(\d+)\s*/\s*(\d+)$').firstMatch(score);
    final double? agree = m == null || int.parse(m.group(2)!) == 0
        ? null
        : int.parse(m.group(1)!) / int.parse(m.group(2)!);
    final Color ink = agree == null
        ? VColors.textSecondary
        : HSVColor.fromAHSV(1, 120 * agree.clamp(0.0, 1.0), 0.72, 1).toColor();

    return VPress(
      onTap: onTap ?? onGenerateConsensus,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: VColors.fillRow,
          borderRadius: BorderRadius.circular(VRadius.row),
          border: Border.all(
            color: agree != null ? ink.withValues(alpha: 0.36) : const Color(0x22FFFFFF),
            width: 0.7,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 20),
              child: AnimatedSwitcher(
                duration: VMotion.base,
                layoutBuilder: (cur, prev) => Stack(
                  alignment: Alignment.centerLeft,
                  children: [...prev, if (cur != null) cur],
                ),
                child: SizedBox(
                  key: ValueKey('$score|$summary|$isGenerating'),
                  width: double.infinity,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        margin: const EdgeInsets.only(top: 1),
                        decoration: BoxDecoration(
                          color: ink.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(VRadius.full),
                          border: Border.all(color: ink.withValues(alpha: 0.45), width: 0.6),
                        ),
                        child: Text(
                          agree == null ? '\u2013/\u2013' : score,
                          style: VType.caption(color: ink, weight: FontWeight.w700).copyWith(
                            fontSize: 11,
                            height: 14 / 11,
                            shadows: agree == null
                                ? null
                                : [
                                    Shadow(color: ink.withValues(alpha: 0.85), blurRadius: 8),
                                  ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          summary.isNotEmpty
                              ? summary
                              : (isGenerating ? 'Synthesizing multi-model consensus...' : 'Tap to inspect consensus map'),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: VOneLine.rowStyle.copyWith(
                            color: summary.isNotEmpty ? VColors.textPrimary : VColors.textSecondary,
                          ),
                        ),
                      ),
                      if (isGenerating) ...[
                        const SizedBox(width: 8),
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: CupertinoActivityIndicator(radius: 6),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
