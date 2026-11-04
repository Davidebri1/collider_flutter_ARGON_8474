import 'package:material_ui/material_ui.dart';
import '../../core/vision/vision_kit.dart';

/// REQ-12 Permanent 3-Icon Bottom Dock — unified visionOS optical glass capsule ornament
/// sharing the exact same compact spacing, material, elevation, and Light Emittance physics as SideNavRail.
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
          width: 42,
          height: 38,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(VRadius.full),
            color: selected ? hue.withValues(alpha: 0.28) : VColors.fillCell,
            border: Border.all(
              color: selected ? hue.withValues(alpha: 0.75) : VColors.borderSubtle,
              width: selected ? 1.0 : 0.6,
            ),
            boxShadow: selected ? VShadow.emissive(hue, intensity: 0.55, radius: 12) : null,
          ),
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 20,
            color: selected ? Colors.white : hue,
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _item(Icons.edit_note_rounded, 'Home / Compose', homeActive, onHome),
          const SizedBox(width: 10),
          _item(Icons.tune_rounded, 'Settings & Account', activeDrawer == 'settings', onSettings),
          const SizedBox(width: 10),
          _item(Icons.apps_rounded, 'Apps', activeDrawer == 'apps', onApps),
        ],
      ),
    );
  }
}
