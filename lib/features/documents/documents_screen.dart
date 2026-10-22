// Documents. Made by Claude (2026-10-20).
// David, 20 Oct 2026: "include a document editor (including word and pdf files) with inline editing and the
// comprehensive suite of functionality ... you can get this from the vercel templates ... it can be a html render
// in flutter". The editor is Novel (Vercel's editor template) built into assets/html/claude_documents.html
// (source in dev/editor). It sits in one glass window; a tap outside does not close it, so no writing is lost.
import 'package:material_ui/material_ui.dart';
import '../../core/vision/vision_kit.dart';
import 'html_page.dart';

class DocumentsScreen extends StatelessWidget {
  final VoidCallback onClose;

  /// The file to open, as the app's server serves it (/files/<source>/<name>), or null for a new document.
  final String? fileUrl;
  final String? fileName;

  const DocumentsScreen({super.key, required this.onClose, this.fileUrl, this.fileName});

  String get _src {
    const page = 'assets/assets/html/claude_documents.html';
    if (fileUrl == null) return page;
    return '$page?file=${Uri.encodeQueryComponent(fileUrl!)}&name=${Uri.encodeQueryComponent(fileName ?? '')}';
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final compact = box.maxWidth < 768;
      final w = compact ? box.maxWidth - 16 : (box.maxWidth - 64).clamp(420.0, 1120.0);
      final h = box.maxHeight - (compact ? 16 : 40);
      return Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          builder: (_, t, child) => Opacity(opacity: t, child: Transform.scale(scale: 0.96 + 0.04 * t, child: child)),
          child: SizedBox(
            width: w,
            height: h,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: VGlass(
                    material: VMaterial.work,
                    radius: 24,
                    child: ClipRRect(borderRadius: BorderRadius.circular(24), child: HtmlPage(src: _src)),
                  ),
                ),
                Positioned(
                  top: -8,
                  right: -8,
                  child: VCircleButton(icon: Icons.close_rounded, size: 28, tooltip: 'Close', floating: true, onTap: onClose),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}
