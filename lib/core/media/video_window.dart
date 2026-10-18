import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../vision/vision_kit.dart';

/// Collider's own video player. Made by Claude (2026-10-18) from David's Figma reference row 19 (417:8630,
/// visionOS video player): the video in a rounded window, back at its top left and the volume slider at its top
/// right, inside the picture; under the window a control ornament with back, play/pause, forward (10 s; the reference shows 15, which Material has no glyph for), the
/// position line and more. "More" opens the [actions] (icons only).
/// The window rises into place when summoned and the controls fade after a few seconds of stillness; a touch
/// or a move over the window brings them back.
class VideoWindow extends StatefulWidget {
  final String url;
  final String? poster;
  final VoidCallback onClose;
  final List<Widget> actions;
  final bool active;

  const VideoWindow({super.key, required this.url, this.poster, required this.onClose, this.actions = const [], this.active = true});

  @override
  State<VideoWindow> createState() => _VideoWindowState();
}

class _VideoWindowState extends State<VideoWindow> with SingleTickerProviderStateMixin {
  VideoPlayerController? _c;
  double _volume = 0; // starts silent, as a looping wallpaper should
  bool _more = false;
  bool _chrome = true;
  DateTime _lastTouch = DateTime.now();
  late final AnimationController _in = AnimationController(vsync: this, duration: const Duration(milliseconds: 520))..forward();

  @override
  void initState() {
    super.initState();
    if (widget.active) _start();
  }

  @override
  void didUpdateWidget(VideoWindow old) {
    super.didUpdateWidget(old);
    if (widget.active && _c == null) _start();
    final c = _c;
    if (c == null || !c.value.isInitialized) return;
    if (!widget.active && c.value.isPlaying) c.pause();
    if (widget.active && !old.active) c.play();
  }

  void _start() {
    final c = _c = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    c.addListener(_tick);
    c.initialize().then((_) async {
      await c.setLooping(true);
      await c.setVolume(_volume);
      if (widget.active) await c.play();
    });
  }

  void _tick() {
    if (!mounted) return;
    final still = DateTime.now().difference(_lastTouch).inMilliseconds > 3200;
    final playing = _c?.value.isPlaying ?? false;
    final chrome = !(still && playing && !_more);
    setState(() => _chrome = chrome);
  }

  void _touch() {
    _lastTouch = DateTime.now();
    if (!_chrome) setState(() => _chrome = true);
  }

  @override
  void dispose() {
    _c?.removeListener(_tick);
    _c?.dispose();
    _in.dispose();
    super.dispose();
  }

  void _skip(int s) {
    final c = _c;
    if (c == null || !c.value.isInitialized) return;
    final d = c.value.duration;
    var p = c.value.position + Duration(seconds: s);
    if (p < Duration.zero) p = Duration.zero;
    if (p > d) p = d;
    c.seekTo(p);
    _touch();
  }

  void _seek(double dx, double w) {
    final c = _c;
    if (c == null || w <= 0 || !c.value.isInitialized) return;
    c.seekTo(c.value.duration * (dx / w).clamp(0.0, 1.0));
    _touch();
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    final v = c?.value;
    final ready = v != null && v.isInitialized;
    final ar = ready && v.aspectRatio > 0 ? v.aspectRatio : 16 / 9;
    final d = ready ? v.duration.inMilliseconds : 0;
    final f = d == 0 ? 0.0 : (v!.position.inMilliseconds / d).clamp(0.0, 1.0);
    final rise = CurvedAnimation(parent: _in, curve: const Cubic(0.2, 0.9, 0.25, 1));
    return MouseRegion(
      onHover: (_) => _touch(),
      child: AnimatedBuilder(
          animation: rise,
          builder: (_, child) => Opacity(
            opacity: rise.value.clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(0, 28 * (1 - rise.value)),
              child: Transform.scale(scale: 0.94 + 0.06 * rise.value, child: child),
            ),
          ),
          child: LayoutBuilder(builder: (context, box) {
            final w = box.maxWidth.clamp(0.0, 760.0);
            final picH = (w / ar).clamp(0.0, box.maxHeight - 80);
            final picW = picH * ar;
            return Center(
              child: GestureDetector(
                onTap: _touch, // a tap on the player stays in it; a tap around it closes the overlay
                child: SizedBox(
                width: picW,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // the window
                    Container(
                      height: picH,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(VRadius.lg),
                        boxShadow: const [BoxShadow(color: Color(0x73000000), blurRadius: 40, offset: Offset(0, 18))],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(VRadius.lg),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (ready)
                              FittedBox(fit: BoxFit.cover, child: SizedBox(width: v.size.width, height: v.size.height, child: VideoPlayer(c!)))
                            else if (widget.poster != null && widget.poster!.isNotEmpty)
                              Image.asset(widget.poster!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const ColoredBox(color: Colors.black))
                            else
                              const ColoredBox(color: Colors.black),
                            // the controls inside the picture
                            AnimatedOpacity(
                              opacity: _chrome ? 1 : 0,
                              duration: const Duration(milliseconds: 420),
                              curve: Curves.easeOut,
                              child: IgnorePointer(
                                ignoring: !_chrome,
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _Round(icon: Icons.chevron_left_rounded, onTap: widget.onClose),
                                      const Spacer(),
                                      _Volume(
                                        value: _volume,
                                        onChanged: (x) {
                                          setState(() => _volume = x);
                                          c?.setVolume(x);
                                          _touch();
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // the ornament
                    AnimatedOpacity(
                      opacity: _chrome ? 1 : 0,
                      duration: const Duration(milliseconds: 420),
                      curve: Curves.easeOut,
                      child: IgnorePointer(
                        ignoring: !_chrome,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: (picW * 0.6).clamp(260.0, 420.0)),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AnimatedSize(
                                duration: VMotion.base,
                                curve: Curves.easeOutCubic,
                                child: _more && widget.actions.isNotEmpty
                                    ? Padding(
                                        padding: const EdgeInsets.only(bottom: 8),
                                        child: Align(
                                          alignment: Alignment.centerRight,
                                          child: VGlass(
                                            material: VMaterial.elevated,
                                            radius: VRadius.full,
                                            padding: const EdgeInsets.all(4),
                                            child: Row(mainAxisSize: MainAxisSize.min, children: widget.actions),
                                          ),
                                        ),
                                      )
                                    : const SizedBox(width: double.infinity),
                              ),
                              VGlass(
                                material: VMaterial.elevated,
                                radius: VRadius.full,
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                child: Row(
                                  children: [
                                    _Plain(icon: Icons.replay_10_rounded, onTap: () => _skip(-10)),
                                    _Plain(
                                      icon: ready && v.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                      size: 22,
                                      onTap: () {
                                        if (!ready) return;
                                        v.isPlaying ? c!.pause() : c!.play();
                                        _touch();
                                      },
                                    ),
                                    _Plain(icon: Icons.forward_10_rounded, onTap: () => _skip(10)),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: LayoutBuilder(
                                        builder: (_, b) => GestureDetector(
                                          behavior: HitTestBehavior.opaque,
                                          onTapDown: (e) => _seek(e.localPosition.dx, b.maxWidth),
                                          onHorizontalDragUpdate: (e) => _seek(e.localPosition.dx, b.maxWidth),
                                          child: SizedBox(height: 24, child: Center(child: _Line(value: f))),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    _Plain(
                                      icon: Icons.more_horiz_rounded,
                                      onTap: () {
                                        setState(() => _more = !_more);
                                        _touch();
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              ),
            );
          }),
        ),
    );
  }
}

class _Line extends StatelessWidget {
  final double value;
  const _Line({required this.value});

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(VRadius.full),
        child: SizedBox(
          height: 4,
          width: double.infinity,
          child: Stack(children: [
            const Positioned.fill(child: ColoredBox(color: Color(0x40FFFFFF))),
            FractionallySizedBox(widthFactor: value, heightFactor: 1, alignment: Alignment.centerLeft, child: const ColoredBox(color: Color(0xE6FFFFFF))),
          ]),
        ),
      );
}

class _Plain extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;
  const _Plain({required this.icon, required this.onTap, this.size = 18});

  @override
  Widget build(BuildContext context) => VPress(
        onTap: onTap,
        child: SizedBox(width: 34, height: 30, child: Icon(icon, size: size, color: const Color(0xE6FFFFFF))),
      );
}

/// A small round glass button laid over the picture (the reference's back button).
class _Round extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _Round({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => VPress(
        onTap: onTap,
        child: ClipOval(
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(width: 30, height: 30, color: const Color(0x4D3A3A3C), child: Icon(icon, size: 20, color: Colors.white)),
          ),
        ),
      );
}

/// The reference's volume pill: a slider and the speaker, laid over the picture.
class _Volume extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;
  const _Volume({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(VRadius.full),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            height: 26,
            padding: const EdgeInsets.fromLTRB(10, 0, 8, 0),
            color: const Color(0x4D3A3A3C),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 92,
                  child: LayoutBuilder(
                    builder: (_, b) => GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (e) => onChanged((e.localPosition.dx / b.maxWidth).clamp(0.0, 1.0)),
                      onHorizontalDragUpdate: (e) => onChanged((e.localPosition.dx / b.maxWidth).clamp(0.0, 1.0)),
                      child: SizedBox(height: 26, child: Center(child: _Line(value: value))),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                VPress(
                  onTap: () => onChanged(value > 0 ? 0 : 0.8),
                  child: Icon(value > 0 ? Icons.volume_up_rounded : Icons.volume_off_rounded, size: 15, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      );
}
