import 'package:material_ui/material_ui.dart';
import '../../core/vision/vision_kit.dart';

/// REQ-12 Permanent 3-Icon Bottom Dock — unified visionOS optical glass capsule ornament
/// sharing the exact same material, elevation, and Light Emittance physics as SideNavRail and Ticker.
class PermanentNavBar extends StatelessWidget {
  final bool isComposerSummoned;
  final VoidCallback onToggleComposer;
  final VoidCallback onHome;
  final VoidCallback onApps;
  final VoidCallback onSettings;
  final String? activeDrawer;

  const PermanentNavBar({
    super.key,
    required this.isComposerSummoned,
    required this.onToggleComposer,
    required this.onHome,
    required this.onApps,
    required this.onSettings,
    this.activeDrawer,
  });

  Widget _item(IconData icon, String tooltip, bool selected, VoidCallback onTap) {
    final Color hue = vHueFor(icon) ?? VColors.accentBlue;
    return Semantics(
      button: true,
      label: tooltip,
      child: VPress(
        onTap: onTap,
        tooltip: tooltip,
        child: AnimatedContainer(
          duration: VMotion.fast,
          width: 44,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(VRadius.full),
            color: selected ? hue.withValues(alpha: 0.22) : VColors.fillCell,
            border: Border.all(
              color: selected ? hue.withValues(alpha: 0.65) : VColors.borderSubtle,
              width: selected ? 1.0 : 0.6,
            ),
            boxShadow: selected ? VShadow.emissive(hue, intensity: 0.48, radius: 12) : null,
          ),
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 20,
            color: selected ? Colors.white : hue.withValues(alpha: 0.92),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final homeActive = activeDrawer == null;
    return VGlass(
      material: VMaterial.elevated,
      radius: VRadius.full,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: SizedBox(
        width: 224,
        height: 40,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _item(Icons.edit_note_rounded, 'Home / Compose', homeActive, onHome),
            _item(Icons.tune_rounded, 'Settings & Account', activeDrawer == 'settings', onSettings),
            _item(Icons.apps_rounded, 'Apps', activeDrawer == 'apps', onApps),
          ],
        ),
      ),
    );
  }
}
