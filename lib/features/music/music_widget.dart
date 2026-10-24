// The music bar.
// Vision OS Design System 417:1777, "Media Controls and Play Bar".
import 'package:material_ui/material_ui.dart';
import '../../core/audio/music_player.dart';
import '../../core/vision/vision_kit.dart';

class MusicBar extends StatelessWidget {
  final MusicTrack track;
  final bool playing;
  final double progress; // 0 to 1
  final String? time; // shown under the title once the track's length is known
  final VoidCallback onPrevious;
  final VoidCallback onPlayPause;
  final VoidCallback onNext;
  final List<VMenuItem> Function()? menu;
  final ValueChanged<double>? onSeek;

  const MusicBar({
    super.key,
    required this.track,
    required this.playing,
    required this.onPrevious,
    required this.onPlayPause,
    required this.onNext,
    this.progress = 0,
    this.time,
    this.menu,
    this.onSeek,
  });

  static const _glyph = Color(0xD9FFFFFF); // white 85%
  static const _chipWidth = 140.0;

  Widget _button(IconData icon, double size, String tip, VoidCallback onTap) => VPress(
        onTap: onTap,
        tooltip: tip,
        child: SizedBox(width: 30, height: 40, child: Icon(icon, size: size, color: _glyph)),
      );

  @override
  Widget build(BuildContext context) {
    final p = MusicPlayer.instance;
    Widget chip = ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Stack(
        children: [
          Container(
            width: _chipWidth,
            height: 36,
            color: const Color(0x40000000),
            padding: const EdgeInsets.all(4),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: track.art.isEmpty
                      ? Container(
                          width: 28,
                          height: 28,
                          decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFFFF7A95), Color(0xFFD0105C)])),
                          child: const Icon(Icons.music_note_rounded, size: 16, color: Colors.white),
                        )
                      : Image.asset(track.art, width: 28, height: 28, fit: BoxFit.cover),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        track.title,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.fade,
                        style: VType.caption(color: Colors.white, weight: FontWeight.w500),
                      ),
                      if (time != null)
                        Text(
                          time!,
                          maxLines: 1,
                          style: VType.metaCaption(color: const Color(0x99FFFFFF)),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Audio track progress bar (PRD R42 & Surfaces: "Audio track progress bar permitted")
          Positioned(
            left: 0,
            bottom: 0,
            child: Container(
              width: _chipWidth * progress.clamp(0.0, 1.0),
              height: 2,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
    if (onSeek != null) {
      chip = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (d) => onSeek!(d.localPosition.dx / _chipWidth),
        onHorizontalDragUpdate: (d) => onSeek!(d.localPosition.dx / _chipWidth),
        child: chip,
      );
    }

    final bar = VGlass(
      material: VMaterial.elevated,
      radius: VRadius.full,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _button(Icons.fast_rewind_rounded, 22, 'Previous', onPrevious),
          _button(playing ? Icons.pause_rounded : Icons.play_arrow_rounded, 26, playing ? 'Pause' : 'Play', onPlayPause),
          _button(Icons.fast_forward_rounded, 22, 'Next', onNext),
          const SizedBox(width: 6),
          chip,
          const SizedBox(width: 4),
          if (menu != null)
            Builder(
              builder: (c) => _button(Icons.format_list_bulleted_rounded, 19, 'Tracks', () {
                final box = c.findRenderObject() as RenderBox;
                showVMenu(c, box.localToGlobal(Offset(box.size.width, box.size.height)), menu!(), align: VMenuAlign.end);
              }),
            ),
          AnimatedBuilder(
            animation: p,
            builder: (_, __) => _button(p.muted ? Icons.volume_off_rounded : Icons.volume_up_rounded, 20, p.muted ? 'Sound On' : 'Mute', p.toggleMute),
          ),
        ],
      ),
    );
    if (menu == null) return bar;
    return GestureDetector(
      onLongPressStart: (d) => showVMenu(context, d.globalPosition, menu!()),
      onSecondaryTapDown: (d) => showVMenu(context, d.globalPosition, menu!()),
      child: bar,
    );
  }
}

/// The bar floating over the app while a track is loaded.
class MusicWidget extends StatelessWidget {
  final VoidCallback onOpenLibrary;
  const MusicWidget({super.key, required this.onOpenLibrary});

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
                  menu: () => [
                    for (int i = 0; i < p.queue.length; i++)
                      VMenuItem(
                        p.isTrackEnabled(p.queue[i]) ? Icons.music_note_rounded : Icons.music_off_rounded,
                        p.queue[i].title,
                        () => p.play(i),
                        checked: i == p.index && p.isTrackEnabled(p.queue[i]),
                      ),
                    VMenuItem(
                      p.isTrackEnabled(t) ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                      p.isTrackEnabled(t) ? 'Turn Off "${t.title}"' : 'Turn On "${t.title}"',
                      () => p.toggleTrack(t),
                      apart: true,
                    ),
                    VMenuItem(null, 'Music Player', onOpenLibrary, apart: true),
                    VMenuItem(null, 'Close', p.close),
                  ],
                ),
        );
      },
    );
  }
}
