// E.D. — Collider — Signed: Gemini 4 Argon (2026-10-27)
import 'package:material_ui/material_ui.dart';
import '../../core/vision/vision_kit.dart';
import 'contextual_side_nav.dart';

/// One affordance on the side nav. [key] is what the surface acts on.
class SideRailEntry {
  final String key;
  final IconData icon;
  final String label;
  const SideRailEntry(this.key, this.icon, this.label);
}

/// Master Spec §6.2: the side nav reshapes to the active work surface.
/// Surfaces themselves are reached from the Apps overlay, never from here.
List<SideRailEntry> sideRailEntries(ActiveWorkSurface s) => switch (s) {
      ActiveWorkSurface.chat => const [
          SideRailEntry('new', Icons.add_rounded, 'New'),
          SideRailEntry('history', Icons.history_rounded, 'History'),
        ],
      ActiveWorkSurface.smartgen => const [
          SideRailEntry('cards', Icons.style_rounded, 'Cards'),
          SideRailEntry('boards', Icons.dashboard_rounded, 'Boards'),
          SideRailEntry('canvas', Icons.crop_free_rounded, 'Canvas'),
          SideRailEntry('genie', Icons.assistant_rounded, 'Genie'),
          SideRailEntry('new', Icons.add_rounded, 'New Card'),
        ],
      ActiveWorkSurface.market => const [
          SideRailEntry('all', Icons.grid_view_rounded, 'All Categories'),
          SideRailEntry('cinematic', Icons.movie_filter_rounded, 'Cinematic'),
          SideRailEntry('architecture', Icons.apartment_rounded, 'Architecture'),
          SideRailEntry('glass', Icons.blur_on_rounded, '3D Glass'),
          SideRailEntry('bioluminescent', Icons.flare_rounded, 'Bioluminescent'),
          SideRailEntry('editorial', Icons.palette_rounded, 'Editorial'),
          SideRailEntry('gallery', Icons.collections_bookmark_rounded, 'My Saved Gallery'),
        ],
      ActiveWorkSurface.themes => const [
          SideRailEntry('all', Icons.auto_awesome_mosaic_rounded, 'All Themes'),
          SideRailEntry('spatial', Icons.weekend_rounded, 'Spatial Rooms'),
          SideRailEntry('nature', Icons.water_drop_rounded, 'Nature & Sea'),
          SideRailEntry('scifi', Icons.rocket_launch_rounded, 'Sci-Fi & Cosmos'),
          SideRailEntry('architecture', Icons.location_city_rounded, 'Architecture'),
          SideRailEntry('installed', Icons.download_done_rounded, 'Installed Themes'),
        ],
      ActiveWorkSurface.browser => const [
          SideRailEntry('tabs', Icons.tab_rounded, 'Tabs'),
          SideRailEntry('engine', Icons.travel_explore_rounded, 'Search Engine'),
        ],
      ActiveWorkSurface.files => const [
          SideRailEntry('all', Icons.folder_open_rounded, 'All Files'),
          SideRailEntry('artifacts', Icons.description_outlined, 'Artifacts'),
          SideRailEntry('attachments', Icons.attach_file_rounded, 'Attachments'),
          SideRailEntry('outputs', Icons.output_rounded, 'Model Outputs'),
          SideRailEntry('system', Icons.settings_suggest_outlined, 'System'),
        ],
    };

/// Vertical tab-bar ornament on the left edge, as in every visionOS app.
class SideNavRail extends StatelessWidget {
  final ActiveWorkSurface surface;
  final String? activeKey;
  final ValueChanged<String> onSelect;
  final bool compact;

  const SideNavRail({
    super.key,
    required this.surface,
    required this.activeKey,
    required this.onSelect,
    this.compact = true,
  });

  @override
  Widget build(BuildContext context) {
    final entries = sideRailEntries(surface);
    return AnimatedSwitcher(
      duration: VMotion.base,
      child: VOrnamentRail(
        key: ValueKey(surface),
        size: compact ? 36 : 40,
        items: [for (final e in entries) VRailItem(e.icon, e.label)],
        active: entries.indexWhere((e) => e.key == activeKey),
        onSelect: (i) => onSelect(entries[i].key),
      ),
    );
  }
}
