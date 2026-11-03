// E.D. — Collider — Signed: Gemini 4 Argon (2026-10-27)
import 'package:material_ui/material_ui.dart';
import '../../core/audio/music_player.dart';
import '../../core/vision/vision_kit.dart';

/// Compact top-edge spatial music ornament (~58% of legacy width, ~188px wide).
/// Contains: Play suite (prev, play/pause, next), song title with subtle progress bar (no images),
/// shuffle/repeat toggle, attached song-list dropdown trigger, and mute button.
class MusicWidget extends StatelessWidget {
  final VoidCallback? onOpenLibrary;
  const MusicWidget({super.key, this.onOpenLibrary});

  @override
  Widget build(BuildContext context) => MusicBar(onOpenLibrary: onOpenLibrary);
}

class MusicBar extends StatefulWidget {
  final VoidCallback? onOpenLibrary;
  const MusicBar({super.key, this.onOpenLibrary});

  @override
  State<MusicBar> createState() => _MusicBarState();
}

class _MusicBarState extends State<MusicBar> {
  final GlobalKey _barKey = GlobalKey();

  void _openSongsDropdown() {
    final p = MusicPlayer.instance;
    final box = _barKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final at = box.localToGlobal(Offset(box.size.width / 2, box.size.height + 2));
    showVMenu(
      context,
      at,
      maxWidth: box.size.width.clamp(168.0, 204.0),
      [
        for (int i = 0; i < p.queue.length; i++)
          VMenuItem(
            null,
            p.queue[i].title,
            () => p.play(i),
            checked: i == p.index,
          ),
        if (widget.onOpenLibrary != null)
          VMenuItem(
            Icons.library_music_rounded,
            'Music Library',
            widget.onOpenLibrary!,
            apart: true,
          ),
      ],
    );
  }

  void _cyclePlaybackMode() {
    MusicPlayer.instance.cyclePlaybackMode();
  }

  IconData _modeIcon(PlaybackMode m) => switch (m) {
        PlaybackMode.shuffle => Icons.shuffle_rounded,
        PlaybackMode.shuffleOnce => Icons.shuffle_on_rounded,
        PlaybackMode.loop => Icons.repeat_rounded,
        PlaybackMode.loopOnce => Icons.repeat_one_rounded,
      };

  String _modeTooltip(PlaybackMode m) => m.label;

  @override
  Widget build(BuildContext context) {
    final p = MusicPlayer.instance;
    return AnimatedBuilder(
      animation: p,
      builder: (context, _) {
        final t = p.current;
        final prog = p.progress;
        final isShuffleOrRepeat = p.playbackMode == PlaybackMode.shuffle || p.playbackMode == PlaybackMode.shuffleOnce;

        return KeyedSubtree(
          key: _barKey,
          child: VOrnament(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Play button suite (Prev / Play-Pause / Next)
                _MiniBarIcon(
                  icon: Icons.skip_previous_rounded,
                  size: 14,
                  tooltip: 'Previous',
                  onTap: p.queue.isEmpty ? null : p.previous,
                ),
                _MiniBarIcon(
                  icon: p.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  size: 16,
                  color: VColors.textPrimary,
                  tooltip: p.playing ? 'Pause' : 'Play',
                  onTap: p.toggle,
                ),
                _MiniBarIcon(
                  icon: Icons.skip_next_rounded,
                  size: 14,
                  tooltip: 'Next',
                  onTap: p.queue.isEmpty ? null : p.next,
                ),
                const SizedBox(width: 3),

                // Song title + dropdown trigger (NO album art / images inside widget)
                VPress(
                  tooltip: t?.title ?? 'Select Song',
                  onTap: p.queue.isEmpty ? widget.onOpenLibrary : _openSongsDropdown,
                  child: Container(
                    width: 72,
                    height: 22,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: VColors.fillRecessed,
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                t?.title ?? 'No Track',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: VType.caption(
                                  color: t == null ? VColors.textTertiary : VColors.textPrimary,
                                  weight: FontWeight.w600,
                                ).copyWith(fontSize: 10.0),
                              ),
                            ),
                          ),
                        ),
                        if (t != null)
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            height: 1.5,
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: prog,
                              child: const ColoredBox(color: Color(0xCCFFFFFF)),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 2),

                // Dropdown arrow button (opens attached song list below widget)
                _MiniBarIcon(
                  icon: Icons.keyboard_arrow_down_rounded,
                  size: 14,
                  tooltip: 'Song List',
                  onTap: p.queue.isEmpty ? widget.onOpenLibrary : _openSongsDropdown,
                ),

                // Shuffle / Playback mode button
                _MiniBarIcon(
                  icon: _modeIcon(p.playbackMode),
                  size: 12.5,
                  color: isShuffleOrRepeat ? VColors.textPrimary : VColors.textTertiary,
                  tooltip: _modeTooltip(p.playbackMode),
                  onTap: _cyclePlaybackMode,
                ),

                // Mute button
                _MiniBarIcon(
                  icon: p.muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                  size: 13.5,
                  color: p.muted ? VColors.textTertiary : VColors.textSecondary,
                  tooltip: p.muted ? 'Unmute' : 'Mute',
                  onTap: p.toggleMute,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MiniBarIcon extends StatelessWidget {
  final IconData icon;
  final double size;
  final Color? color;
  final String? tooltip;
  final VoidCallback? onTap;

  const _MiniBarIcon({
    required this.icon,
    this.size = 14,
    this.color,
    this.tooltip,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return VPress(
      tooltip: tooltip,
      onTap: onTap,
      child: SizedBox(
        width: 19,
        height: 22,
        child: Center(
          child: Icon(
            icon,
            size: size,
            color: color ?? VColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
