import 'package:material_ui/material_ui.dart';
import '../../../core/vision/vision_kit.dart';
import '../../drawers/settings_drawer.dart' show AccountStore;

/// Tiers & Quotas — Snap Submenu Popover (<= 1/4 screen size, anchored above PermanentNavBar).
/// Zero full-screen blur scrim so the sacred background stage stays crystal-clear.
class UpgradeScreen extends StatefulWidget {
  final VoidCallback onClose;

  const UpgradeScreen({super.key, required this.onClose});

  @override
  State<UpgradeScreen> createState() => _UpgradeScreenState();
}

class _UpgradeScreenState extends State<UpgradeScreen> {
  static const _tiers = ['Free', 'Pro', 'Elite'];
  int _idx = switch (AccountStore.tier) {
    'Elite' => 2,
    'Pro' => 1,
    _ => 0,
  };

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final selectedTier = _tiers[_idx];
    final isCurrent = AccountStore.tier == selectedTier;
    final (String price, Color accent, List<String> perks) = switch (selectedTier) {
      'Elite' => (
          '\$49/mo',
          VColors.accentGold,
          const [
            '9-model parallel grid & priority speed',
            '10,000 monthly synthesis & video credits',
            'Unlimited Smart Gen & Cinema themes',
          ]
        ),
      'Pro' => (
          '\$19/mo',
          VColors.accentBlue,
          const [
            'All Pro General, Image, Video & Audio models',
            '6-model parallel streaming & 3D Consensus',
            '2,000 monthly credits + Smart Gen Boards',
          ]
        ),
      _ => (
          '\$0',
          VColors.textSecondary,
          const [
            '5 Free models (Nemotron, Gemma 4, GLM)',
            '50 daily queries & single-stream consensus',
            'Curated free Live Wallpaper themes',
          ]
        ),
    };

    final popW = (size.width * 0.62).clamp(228.0, 248.0);
    final maxH = (size.height * 0.245).clamp(188.0, 210.0);

    return Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: widget.onClose,
          child: const SizedBox.expand(),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 68,
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: popW, maxHeight: maxH),
              child: GestureDetector(
                onTap: () {},
                child: VGlass(
                  material: VMaterial.modal,
                  radius: VRadius.lg,
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: 22,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Center(
                              child: Text(
                                'Tiers & Quotas',
                                textAlign: TextAlign.center,
                                style: VType.callout(weight: FontWeight.w600).copyWith(fontSize: 11.5),
                              ),
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: VCircleButton(icon: Icons.close_rounded, size: 22, tooltip: 'Close', onTap: widget.onClose),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          for (int i = 0; i < _tiers.length; i++) ...[
                            if (i > 0) const SizedBox(width: 5),
                            Expanded(
                              child: VPress(
                                onTap: () => setState(() => _idx = i),
                                child: AnimatedContainer(
                                  duration: VMotion.fast,
                                  height: 24,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: _idx == i ? VColors.fillActive : VColors.fillCell,
                                    borderRadius: BorderRadius.circular(VRadius.full),
                                    border: Border.all(
                                      color: _idx == i ? accent.withValues(alpha: 0.7) : VColors.borderSubtle,
                                      width: 0.6,
                                    ),
                                  ),
                                  child: Text(
                                    _tiers[i],
                                    style: VType.caption(
                                      color: _idx == i ? Colors.white : VColors.textSecondary,
                                      weight: _idx == i ? FontWeight.w700 : FontWeight.w500,
                                    ).copyWith(fontSize: 10.0),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final p in perks)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 3),
                                child: Row(
                                  children: [
                                    Icon(Icons.check_rounded, size: 12, color: accent),
                                    const SizedBox(width: 5),
                                    Expanded(
                                      child: Text(
                                        p,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: VType.caption(color: VColors.textSecondary).copyWith(fontSize: 9.8),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      VPress(
                        onTap: () async {
                          await AccountStore.setTier(selectedTier);
                          if (mounted) setState(() {});
                        },
                        child: Container(
                          height: 28,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isCurrent ? VColors.fillActive : VColors.accentBlue,
                            borderRadius: BorderRadius.circular(VRadius.full),
                            border: Border.all(
                              color: isCurrent ? VColors.borderHeavy : VColors.accentBlue,
                              width: 0.6,
                            ),
                          ),
                          child: Text(
                            isCurrent ? 'Current Plan ($price) ✓' : 'Switch to $selectedTier · $price',
                            style: VType.caption(color: Colors.white, weight: FontWeight.w600).copyWith(fontSize: 10.5),
                          ),
                        ),
                      ),
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
}
