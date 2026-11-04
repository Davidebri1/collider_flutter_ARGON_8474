import 'package:material_ui/material_ui.dart';
import '../../../core/vision/vision_kit.dart';

/// Tiers & Entitlements — account-style window (Vision OS Design System 417:8552):
/// close circle, centred title, one grouped card per tier with interactive selection.
class UpgradeScreen extends StatefulWidget {
  final VoidCallback onClose;

  const UpgradeScreen({super.key, required this.onClose});

  @override
  State<UpgradeScreen> createState() => _UpgradeScreenState();
}

class _UpgradeScreenState extends State<UpgradeScreen> {
  String _activePlan = 'Free Tier';

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 820;
    final cards = [
      _tier(
        'Free Tier',
        '\$0',
        _activePlan == 'Free Tier' ? 'Current Plan' : 'Switch to Free',
        false,
        const [
          '5 Free models (Nemotron 3.5 Lightning, Gemma 4, etc.)',
          '50 Daily queries',
          'Standard single-stream consensus',
          'Curated Live Wallpaper themes',
        ],
      ),
      _tier(
        'Pro Tier',
        '\$19 / mo',
        _activePlan == 'Pro Tier' ? 'Active Plan ✓' : 'Upgrade to Pro',
        true,
        const [
          'Unlock all Pro General, Image, Video & Audio models',
          'Parallel multi-model streaming up to 6 models',
          'Interactive 3D Consensus View',
          'SmartGen Boards, Canvas & Genie synthesis',
          '2,000 monthly credits',
        ],
      ),
      _tier(
        'Elite Tier',
        '\$49 / mo',
        _activePlan == 'Elite Tier' ? 'Active Plan ✓' : 'Upgrade to Elite',
        false,
        const [
          'All Pro capabilities + 9-model comparison grid',
          'Full 120 FPS high-fidelity spatial glass effects',
          'Unlimited Smart Gen household projects',
          '10,000 monthly credits',
          'Instant priority model responses',
        ],
      ),
    ];
    return Stack(
      fit: StackFit.expand,
      children: [
        VScrim(onTap: widget.onClose, blur: true),
        SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(VSpace.md, 16, VSpace.md, 76),
              child: VWindow(
                title: 'Tiers & Entitlements',
                centerTitle: true,
                maxWidth: wide ? 860 : VOverlay.menuWidth(context) + 36,
                leading: VCircleButton(icon: Icons.close_rounded, tooltip: 'Close', onTap: widget.onClose),
                child: wide
                    ? IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(child: cards[0]),
                            const SizedBox(width: VSpace.sm),
                            Expanded(child: cards[1]),
                            const SizedBox(width: VSpace.sm),
                            Expanded(child: cards[2]),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            cards[0],
                            const SizedBox(height: VSpace.sm),
                            cards[1],
                            const SizedBox(height: VSpace.sm),
                            cards[2],
                          ],
                        ),
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _tier(String name, String price, String cta, bool featured, List<String> features) {
    final isCurrent = _activePlan == name;
    return AnimatedContainer(
      duration: VMotion.fast,
      padding: const EdgeInsets.all(VSpace.md),
      decoration: BoxDecoration(
        color: isCurrent
            ? Color.alphaBlend(VColors.accentBlue.withValues(alpha: 0.14), VColors.overlayLight)
            : (featured ? VColors.overlayLight : VColors.fillCell),
        borderRadius: BorderRadius.circular(VRadius.lg),
        border: Border.all(
          color: isCurrent
              ? VColors.accentBlue.withValues(alpha: 0.65)
              : (featured ? VColors.borderHeavy : VColors.borderSubtle),
          width: isCurrent ? 1.0 : 0.6,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text(name, style: VType.headline())),
            Text(price, style: VType.headline()),
          ]),
          const SizedBox(height: VSpace.xs),
          for (final f in features)
            Padding(
              padding: const EdgeInsets.only(bottom: VSpace.xxs),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.check_rounded,
                    size: 14,
                    color: isCurrent ? VColors.accentBlue : VColors.textSecondary,
                  ),
                ),
                const SizedBox(width: VSpace.xs),
                Expanded(child: Text(f, style: VType.footnote())),
              ]),
            ),
          const SizedBox(height: VSpace.sm),
          VButton(
            label: cta,
            dense: true,
            expand: true,
            variant: isCurrent || featured ? VButtonVariant.primary : VButtonVariant.secondary,
            onTap: () => setState(() => _activePlan = name),
          ),
        ],
      ),
    );
  }
}
