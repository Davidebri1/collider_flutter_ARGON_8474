// A picture opened large. Made by Claude (2026-10-21), on the layout of Grok Imagine's picture view (Mobbin, Grok iOS):
// the picture at its own shape on near-black, rounded; a row of actions under it; a sideways swipe to the next.
// David, 21 Oct: Discover "needs to extract the cinematic effect. Through dimming the background", and Remix hands the
// picture to the media chat as its reference ("Grok merely transfers you to the chat window when you hit remix").
// Actions: keep it (My Gallery), Files, share, remix. No words of Grok's.
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../../core/platform/open_url.dart';
import '../../core/vision/vision_kit.dart';

class ViewedPicture {
  final String id; // what My Gallery keeps it by
  final String url; // full size
  final double aspect; // width / height, as far as it is known
  final String? fileRef; // "source/name" in Files, when it is there
  final Widget Function(BoxFit fit)? builder; // a picture the app draws itself (a wallpaper's poster)
  const ViewedPicture({required this.id, required this.url, this.aspect = 9 / 16, this.fileRef, this.builder});
}

class PictureViewer extends StatefulWidget {
  final List<ViewedPicture> pictures;
  final int start;
  final Set<String> saved;
  final ValueChanged<ViewedPicture> onSave;
  final ValueChanged<ViewedPicture> onRemix;
  final ValueChanged<ViewedPicture>? onFiles;
  final VoidCallback onClose;
  const PictureViewer({
    super.key,
    required this.pictures,
    required this.start,
    required this.saved,
    required this.onSave,
    required this.onRemix,
    required this.onClose,
    this.onFiles,
  });

  @override
  State<PictureViewer> createState() => _PictureViewerState();
}

class _PictureViewerState extends State<PictureViewer> {
  late final PageController _pages = PageController(initialPage: widget.start);
  late int _i = widget.start;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _share(ViewedPicture p) async {
    if (canShareText && await shareText(p.url)) return;
    await Clipboard.setData(ClipboardData(text: p.url));
  }

  Widget _picture(ViewedPicture p) {
    final img = p.builder != null
        ? p.builder!(BoxFit.contain)
        : Image.network(p.url, fit: BoxFit.contain, filterQuality: FilterQuality.high, gaplessPlayback: true,
            loadingBuilder: (_, child, progress) => progress == null ? child : const ColoredBox(color: Color(0xFF0B0B0D)),
            errorBuilder: (_, __, ___) => const ColoredBox(color: Color(0xFF0B0B0D)));
    return ClipRRect(borderRadius: BorderRadius.circular(16), child: AspectRatio(aspectRatio: p.aspect, child: img));
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.pictures[_i];
    final saved = widget.saved.contains(p.id);
    Widget act(IconData icon, VoidCallback onTap, {Color? color}) =>
        VCircleButton(icon: icon, size: 44, selected: true, iconColor: color, onTap: onTap);
    return Stack(children: [
      // the room goes nearly black: the picture is all there is
      Positioned.fill(
        child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: widget.onClose, child: const ColoredBox(color: Color(0xF2000000))),
      ),
      SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Row(children: [VCircleButton(icon: Icons.arrow_back_rounded, size: 44, selected: true, onTap: widget.onClose)]),
          ),
          Expanded(
            child: PageView.builder(
              controller: _pages,
              itemCount: widget.pictures.length,
              onPageChanged: (i) => setState(() => _i = i),
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Center(child: _picture(widget.pictures[i])),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 96),
            // as Grok's picture view: remix on its own at the left; keep, Files and share together in one capsule at the right
            child: Row(children: [
              act(Icons.auto_fix_high_rounded, () => widget.onRemix(p)),
              const Spacer(),
              VGlass(
                material: VMaterial.elevated,
                radius: 26,
                padding: const EdgeInsets.all(4),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  VCircleButton(
                    icon: saved ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    size: 44,
                    iconColor: saved ? const Color(0xFFE5484D) : null,
                    onTap: () {
                      widget.onSave(p);
                      setState(() {});
                    },
                  ),
                  if (widget.onFiles != null) VCircleButton(icon: Icons.download_rounded, size: 44, onTap: () => widget.onFiles!(p)),
                  VCircleButton(icon: Icons.ios_share_rounded, size: 44, onTap: () => _share(p)),
                ]),
              ),
            ]),
          ),
        ]),
      ),
    ]);
  }
}
