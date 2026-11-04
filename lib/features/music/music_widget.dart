// The music bar.
// Vision OS Design System 417:1777, "Media Controls and Play Bar" — compact ornament with attached Music / Purchased dropdown.
import 'package:material_ui/material_ui.dart';
import '../../core/audio/music_player.dart';
import '../../core/media/theme_cloud.dart';
import '../../core/vision/vision_kit.dart';
import '../../models/theme_def.dart';
import '../theme/theme_pack_store.dart';

class MusicBar extends StatefulWidget {
  final MusicTrack track;
  final bool playing;
  final double progress; // 0 to 1
  final String? time;
  final VoidCallback onPrevious;
  final VoidCallback onPlayPause;
  final VoidCallback onNext;
  final VoidCallback onOpenLibrary;
  final VoidCallback? onOpenPurchased;
  final ValueChanged<double>? onSeek;

  const MusicBar({
    super.key,
    required this.track,
    required this.playing,
    required this.onPrevious,
    required this.onPlayPause,
    required this.onNext,
    required this.onOpenLibrary,
    this.onOpenPurchased,
    this.progress = 0,
    this.time,
    this.onSeek,
  });

  @override
  State<MusicBar> createState() => _MusicBarState();
}

class _MusicBarState extends State<MusicBar> {
  final GlobalKey _barKey = GlobalKey();
  static const _glyph = Color(0xEBFFFFFF);
  static const _chipWidth = 106.0;

  @override
  void initState() {
    super.initState();
    if (Uri.base.queryParameters['music_open'] == '1') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openAttachedDropdown();
      });
    }
  }

  Widget _button(IconData icon, double size, String tip, VoidCallback onTap) => VPress(
        onTap: onTap,
        tooltip: tip,
        child: SizedBox(width: 26, height: 32, child: Icon(icon, size: size, color: _glyph)),
      );

  List<(WallpaperTheme, MusicTrack, int)> _purchasedTracks() {
    final owned = ThemePackStore.instance.unlocked;
    final bypass = ThemePackStore.instance.bypass;
    final allThemes = <WallpaperTheme>[
      ...WallpaperCatalog.freeThemes,
      ...ThemeCloud.instance.themes,
    ];
    final seen = <String>{};
    final out = <(WallpaperTheme, MusicTrack, int)>[];
    for (final t in allThemes) {
      if (!bypass && !owned.contains(t.id) && t.priceLabel != null) continue;
      final songs = MusicPlayer.forTheme(t);
      for (int i = 0; i < songs.length; i++) {
        final key = '${songs[i].title.toLowerCase()}|${songs[i].file}';
        if (seen.add(key)) {
          out.add((t, songs[i], i));
        }
      }
    }
    return out;
  }

  void _openAttachedDropdown() {
    final box = _barKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final globalPos = box.localToGlobal(Offset(box.size.width / 2, box.size.height + 6));
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close',
      barrierColor: Colors.transparent,
      transitionDuration: VMotion.fast,
      pageBuilder: (ctx, _, __) {
        final screen = MediaQuery.sizeOf(ctx);
        const menuW = 228.0;
        final left = (globalPos.dx - menuW / 2).clamp(12.0, screen.width - menuW - 12.0);
        final top = globalPos.dy.clamp(12.0, screen.height - 220.0);
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () => Navigator.of(ctx).pop(),
              ),
            ),
            Positioned(
              left: left,
              top: top,
              width: menuW,
              child: Material(
                type: MaterialType.transparency,
                child: _AttachedMusicDropdown(
                  purchasedTracks: _purchasedTracks(),
                  onOpenLibrary: () {
                    Navigator.of(ctx).pop();
                    widget.onOpenLibrary();
                  },
                  onOpenPurchased: widget.onOpenPurchased == null
                      ? null
                      : () {
                          Navigator.of(ctx).pop();
                          widget.onOpenPurchased!();
                        },
                  onClosePlayer: () {
                    Navigator.of(ctx).pop();
                    MusicPlayer.instance.close();
                  },
                ),
              ),
            ),
          ],
        );
      },
      transitionBuilder: (ctx, a, _, child) => FadeTransition(
        opacity: a,
        child: ScaleTransition(
          alignment: Alignment.topCenter,
          scale: Tween(begin: 0.96, end: 1.0).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = MusicPlayer.instance;
    Widget chip = ClipRRect(
      borderRadius: BorderRadius.circular(9),
      child: Stack(
        children: [
          Container(
            width: _chipWidth,
            height: 28,
            color: VColors.fillRecessed,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: Row(
              children: [
                const Icon(Icons.music_note_rounded, size: 13, color: VColors.accentCyan),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    widget.track.title,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: VType.caption(color: Colors.white, weight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            bottom: 0,
            child: Container(
              width: _chipWidth * widget.progress.clamp(0.0, 1.0),
              height: 2,
              color: VColors.accentBlue,
            ),
          ),
        ],
      ),
    );
    if (widget.onSeek != null) {
      chip = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (d) => widget.onSeek!(d.localPosition.dx / _chipWidth),
        onHorizontalDragUpdate: (d) => widget.onSeek!(d.localPosition.dx / _chipWidth),
        child: chip,
      );
    }

    return KeyedSubtree(
      key: _barKey,
      child: VGlass(
        material: VMaterial.elevated,
        radius: VRadius.full,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _button(Icons.fast_rewind_rounded, 18, 'Previous', widget.onPrevious),
            _button(widget.playing ? Icons.pause_rounded : Icons.play_arrow_rounded, 21, widget.playing ? 'Pause' : 'Play', widget.onPlayPause),
            _button(Icons.fast_forward_rounded, 18, 'Next', widget.onNext),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: _openAttachedDropdown,
              child: chip,
            ),
            const SizedBox(width: 2),
            _button(Icons.keyboard_arrow_down_rounded, 18, 'Music & Purchased Tracks', _openAttachedDropdown),
            AnimatedBuilder(
              animation: p,
              builder: (_, __) => _button(
                p.muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                17,
                p.muted ? 'Sound On' : 'Mute',
                p.toggleMute,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttachedMusicDropdown extends StatefulWidget {
  final List<(WallpaperTheme, MusicTrack, int)> purchasedTracks;
  final VoidCallback onOpenLibrary;
  final VoidCallback? onOpenPurchased;
  final VoidCallback onClosePlayer;

  const _AttachedMusicDropdown({
    required this.purchasedTracks,
    required this.onOpenLibrary,
    this.onOpenPurchased,
    required this.onClosePlayer,
  });

  @override
  State<_AttachedMusicDropdown> createState() => _AttachedMusicDropdownState();
}

class _AttachedMusicDropdownState extends State<_AttachedMusicDropdown> {
  int _tab = 0; // 0 = Music (Active Theme Queue), 1 = Purchased (Unlocked Theme Tracks)

  @override
  Widget build(BuildContext context) {
    final p = MusicPlayer.instance;
    return AnimatedBuilder(
      animation: p,
      builder: (context, _) {
        final cur = p.current;
        return VGlass(
          material: VMaterial.modal,
          radius: VRadius.card,
          padding: const EdgeInsets.fromLTRB(9, 8, 9, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Centered Segmented Header: Music vs Purchased
              VSegmented(
                ornament: false,
                labels: const ['Music', 'Purchased'],
                active: _tab,
                onSelect: (i) => setState(() => _tab = i),
              ),
              const SizedBox(height: 5),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 112),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: _tab == 0
                        ? [
                            for (int i = 0; i < p.queue.length; i++)
                              _trackRow(
                                title: p.queue[i].title,
                                subtitle: 'Current Theme Track',
                                selected: i == p.index && p.isTrackEnabled(p.queue[i]),
                                enabled: p.isTrackEnabled(p.queue[i]),
                                onTap: () => p.play(i),
                                onToggleEnable: () => p.toggleTrack(p.queue[i]),
                              ),
                          ]
                        : [
                            for (final item in widget.purchasedTracks)
                              _trackRow(
                                title: item.$2.title,
                                subtitle: item.$1.name,
                                selected: cur?.file == item.$2.file,
                                enabled: p.isTrackEnabled(item.$2),
                                onTap: () => p.play(
                                  item.$3,
                                  list: MusicPlayer.forTheme(item.$1),
                                  id: item.$1.id,
                                ),
                                onToggleEnable: () => p.toggleTrack(item.$2),
                              ),
                          ],
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Divider(height: 1, thickness: 0.5, color: VColors.borderLight),
              ),
              Row(
                children: [
                  Expanded(
                    child: VPress(
                      onTap: _tab == 1 && widget.onOpenPurchased != null ? widget.onOpenPurchased! : widget.onOpenLibrary,
                      child: Container(
                        height: 26,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: VColors.fillCell,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _tab == 1 ? 'Open Purchased' : 'Music Player',
                          style: VType.metaCaption(color: Colors.white, weight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  VPress(
                    onTap: widget.onClosePlayer,
                    child: Container(
                      height: 26,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: VColors.fillCell,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('Close', style: VType.metaCaption(color: VColors.textSecondary, weight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _trackRow({
    required String title,
    required String subtitle,
    required bool selected,
    required bool enabled,
    required VoidCallback onTap,
    required VoidCallback onToggleEnable,
  }) {
    return VPress(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        margin: const EdgeInsets.only(bottom: 2),
        decoration: BoxDecoration(
          color: selected ? VColors.fillActive : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: onToggleEnable,
              child: Icon(
                enabled ? (selected ? Icons.graphic_eq_rounded : Icons.music_note_rounded) : Icons.music_off_rounded,
                size: 13,
                color: selected ? VColors.accentBlue : (enabled ? VColors.textSecondary : VColors.textTertiary),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: VType.caption(
                      color: enabled ? Colors.white : VColors.textTertiary,
                      weight: selected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: VType.metaCaption(color: VColors.textTertiary),
                  ),
                ],
              ),
            ),
            if (selected) const Icon(Icons.check_rounded, size: 13, color: VColors.accentBlue),
          ],
        ),
      ),
    );
  }
}

/// The bar floating over the app while a track is loaded.
class MusicWidget extends StatelessWidget {
  final VoidCallback onOpenLibrary;
  final VoidCallback? onOpenPurchased;
  const MusicWidget({super.key, required this.onOpenLibrary, this.onOpenPurchased});

  @override
  Widget build(BuildContext context) {
    final p = MusicPlayer.instance;
    return AnimatedBuilder(
      animation: p,
      builder: (_, __) {
        final t = p.current;
        return AnimatedSwitcher(
          duration: VMotion.base,
          transitionBuilder: (c, a) => ScaleTransition(scale: Tween(begin: 0.9, end: 1.0).animate(a), child: FadeTransition(opacity: a, child: c)),
          child: t == null
              ? const SizedBox.shrink(key: ValueKey('none'))
              : MusicBar(
                  key: const ValueKey('player'),
                  track: t,
                  playing: p.playing,
                  progress: p.progress,
                  time: p.duration > 0 ? '${musicTime(p.position)} / ${musicTime(p.duration)}' : null,
                  onPrevious: p.previous,
                  onPlayPause: p.toggle,
                  onNext: p.next,
                  onSeek: p.seek,
                  onOpenLibrary: onOpenLibrary,
                  onOpenPurchased: onOpenPurchased,
                ),
        );
      },
    );
  }
}
