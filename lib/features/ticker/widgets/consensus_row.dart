// E.D. — Collider — Signed: Gemini 4 Argon (2026-10-27)
import 'package:material_ui/material_ui.dart';
import '../../../core/vision/vision_kit.dart';
import 'model_pill.dart';

/// The consensus, first line of the ticker.
/// The score leads its words, coloured red to green with emissive light bloom by how many agree;
/// standardized 11pt 2-line summary; tapping opens the 3D Consensus Map.
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
    final double? agree = m == null || int.parse(m.group(2)!) == 0 ? null : int.parse(m.group(1)!) / int.parse(m.group(2)!);
    final Color ink = agree == null ? VColors.accentBlue : HSVColor.fromAHSV(1, 130 * agree.clamp(0.0, 1.0), 0.72, 1).toColor();
    return VPress(
      onTap: onTap ?? onGenerateConsensus,
      child: VAmbientPulse(
        active: isGenerating,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: ink.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(ModelPill.radius),
            border: Border.all(color: ink.withValues(alpha: 0.35), width: 0.6),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 3, right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: ink.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(VRadius.full),
                  border: Border.all(color: ink.withValues(alpha: 0.65), width: 0.6),
                  boxShadow: VShadow.emissive(ink, intensity: 0.75),
                ),
                child: Text(
                  agree == null ? '–/–' : score,
                  style: VType.caption(color: Colors.white, weight: FontWeight.w700),
                ),
              ),
              Expanded(
                child: Text(
                  summary.isNotEmpty ? summary : (isGenerating ? 'Synthesizing multi-model consensus…' : 'Tap to inspect 3D Consensus Galaxy'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: VType.summary(color: VColors.textPrimary, weight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The hairline under the consensus: one line of light across the column, fading out at both ends.
class TickerDivider extends StatelessWidget {
  const TickerDivider({super.key});
  @override
  Widget build(BuildContext context) => Container(
        height: 1,
        margin: const EdgeInsets.symmetric(horizontal: ModelPill.radius / 2, vertical: 4),
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [Color(0x00FFFFFF), Color(0x24FFFFFF), Color(0x24FFFFFF), Color(0x00FFFFFF)], stops: [0, 0.2, 0.8, 1]),
        ),
      );
}
