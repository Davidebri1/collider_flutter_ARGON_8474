import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import '../../../models/ticker_item.dart';
import '../../../core/vision/vision_kit.dart';
import '../../../core/api/collider_api.dart';
import '../../../core/platform/open_url.dart';

/// The message, zoomed. Rewritten by Claude on 2026-10-04 to David's own line:
/// "zoomed in view (also scrollable) with blurred background or dimmed and with action options along the
/// bottom of the message and with no visible window and with faded edges".
/// Claude, 2026-10-23: now the app's one detail view (DetailView): Copy and Save, then Send, Open and Close, each with
/// its name under it.
class MessageZoomOverlay extends StatelessWidget {
  final TickerMessage message;
  final String modelName;
  final Color providerColor;
  final VoidCallback onClose;

  /// Opens the message as a document (Documents).
  final VoidCallback? onOpen;

  const MessageZoomOverlay({
    super.key,
    required this.message,
    required this.modelName,
    required this.providerColor,
    required this.onClose,
    this.onOpen,
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

  Future<void> _send(BuildContext context) async {
    if (!await shareText(message.text) && context.mounted) _copy(context);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return DetailView(
      onClose: onClose,
      onSend: () => _send(context),
      onOpen: onOpen,
      maxWidth: 520,
      actions: [
        DetailAction(Icons.copy_rounded, 'Copy', () => _copy(context)),
        DetailAction(Icons.bookmark_border_rounded, 'Save', () => _save(context)),
      ],
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: size.height * 0.62),
        child: VFadeScroll(
          fade: 30,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 26),
          child: MdText(
            message.text,
            style: VType.body().copyWith(fontSize: 15, height: 1.5, shadows: const [Shadow(color: Color(0x99000000), blurRadius: 14)]),
          ),
        ),
      ),
    );
  }
}
