import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../models/ticker_item.dart';
import '../../../core/vision/vision_kit.dart';
import '../../../core/api/collider_api.dart';
import '../../../core/platform/open_url.dart';

/// The message, zoomed. Rewritten by Claude on 2026-10-04 to David's own line:
/// "zoomed in view (also scrollable) with blurred background or dimmed and with action options along the
/// bottom of the message and with no visible window and with faded edges".
/// No window and no header: the text stands on the dimmed screen, dissolves at its upper and lower edge,
/// and its actions sit under it. Only as tall as the message, and never more than half the screen.
/// The row holds Copy, Save and Share and nothing else; a tap anywhere outside the text closes it.
class MessageZoomOverlay extends StatelessWidget {
  final TickerMessage message;
  final String modelName;
  final Color providerColor;
  final VoidCallback onClose;

  const MessageZoomOverlay({
    super.key,
    required this.message,
    required this.modelName,
    required this.providerColor,
    required this.onClose,
  });

  void _toast(BuildContext context, String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      duration: const Duration(seconds: 1),
      behavior: SnackBarBehavior.floating,
      backgroundColor: VColors.glassDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VRadius.full)),
      // a short pill above the dock, never across it
      margin: EdgeInsets.fromLTRB(MediaQuery.sizeOf(context).width * 0.24, 0, MediaQuery.sizeOf(context).width * 0.24, 100),
      elevation: 0,
      content: Text(text, textAlign: TextAlign.center, style: VType.callout()),
    ));
  }

  void _copy(BuildContext context) {
    Clipboard.setData(ClipboardData(text: message.text));
    _toast(context, 'Copied');
  }

  /// Saves the message as a file in Files > Generated.
  Future<void> _save(BuildContext context) async {
    final words = message.text.replaceAll(RegExp(r'[#*_`>\[\]\n]'), ' ').trim().split(RegExp(r'\s+')).take(6).join(' ');
    final name = await ColliderApi.instance.saveGenerated('$modelName - $words.md', message.text, model: modelName);
    if (context.mounted) _toast(context, name == null ? 'Not saved' : 'Saved to Files');
  }

  Future<void> _share(BuildContext context) async {
    if (!await shareText(message.text) && context.mounted) _copy(context);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Stack(
      fit: StackFit.expand,
      children: [
        VScrim(onTap: onClose),
        SafeArea(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              // the actions end just above the dock, within the thumb's reach
              padding: const EdgeInsets.fromLTRB(VSpace.lg, VSpace.lg, VSpace.lg, 92),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: 300, maxHeight: size.height * 0.5),
                      child: VFadeScroll(
                        fade: 26,
                        padding: const EdgeInsets.symmetric(vertical: 22),
                        child: MdText(
                          message.text,
                          style: VType.body().copyWith(fontSize: 14, height: 1.45, shadows: const [Shadow(color: Color(0x8A000000), blurRadius: 12)]),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: VSpace.xs),
                  // Each of these glyphs says what it does on its own; no words needed.
                  VOrnament(
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        VCircleButton(icon: Icons.copy_rounded, tooltip: 'Copy', onTap: () => _copy(context)),
                        const SizedBox(width: 4),
                        VCircleButton(icon: Icons.bookmark_border_rounded, tooltip: 'Save', onTap: () => _save(context)),
                        if (canShareText) ...[
                          const SizedBox(width: 4),
                          VCircleButton(icon: Icons.ios_share_rounded, tooltip: 'Share', onTap: () => _share(context)),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
