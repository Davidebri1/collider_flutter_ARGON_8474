import 'package:material_ui/material_ui.dart';
import '../../../core/vision/vision_kit.dart';

/// Pinned consensus preview. Made by Claude (2026-10-04).
/// One line: the score (red to green by how many agree, glowing), then the consensus. The line is written to the length the row holds (see VOneLine), so it
/// is never cut, wrapped or scrolled. Tapping opens the consensus map.
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
    // The score is coloured red to green by how many agree, and glows. Until every model has answered it reads -/-.
    final m = RegExp(r'^(\d+)\s*/\s*(\d+)$').firstMatch(score);
    final double? agree = m == null || int.parse(m.group(2)!) == 0 ? null : int.parse(m.group(1)!) / int.parse(m.group(2)!);
    final Color ink = agree == null ? VColors.textSecondary : HSVColor.fromAHSV(1, 120 * agree.clamp(0.0, 1.0), 0.72, 1).toColor();
    return VPress(
      onTap: onTap ?? onGenerateConsensus,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        decoration: BoxDecoration(color: VColors.fillRow, borderRadius: BorderRadius.circular(VRadius.row)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // The score leads the line it belongs to; it does not take a line of its own.
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(agree == null ? '\u2013/\u2013' : score,
                    maxLines: 1,
                    softWrap: false,
                    style: VType.caption(color: ink, weight: FontWeight.w700).copyWith(
                      fontSize: 12,
                      height: 17 / 12,
                      shadows: agree == null
                          ? null
                          : [Shadow(color: ink.withValues(alpha: 0.9), blurRadius: 10), Shadow(color: ink.withValues(alpha: 0.5), blurRadius: 3)],
                    )),
                const SizedBox(width: 8),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: VMotion.base,
                    layoutBuilder: (cur, prev) => Stack(alignment: Alignment.centerLeft, children: [...prev, if (cur != null) cur]),
                    child: summary.isEmpty
                        ? const SizedBox(key: ValueKey('none'), height: 17, width: double.infinity)
                        : VOneLine(key: ValueKey(summary), text: summary),
                  ),
                ),
              ],
            ),
            if (isGenerating) ...[
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(VRadius.full),
                child: const LinearProgressIndicator(
                  minHeight: 2,
                  backgroundColor: VColors.fillCell,
                  valueColor: AlwaysStoppedAnimation<Color>(VColors.textSecondary),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
