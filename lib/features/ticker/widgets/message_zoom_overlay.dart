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
    final name = await ColliderApi.instance.saveGenerated('$modelName - $words.md', message.text);
    if (context.mounted) _toast(context, name == null ? 'Not saved' : 'Saved to Files');
  }

  Future<void> _share(BuildContext context) async {
    if (!await shareText(message.text) && context.mounted) _copy(context);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    // The message rises out of the dim as if summoned: it fades and lifts into place, and its actions follow
    // a beat later. The actions are only words, lit and floating, with no box, circle or icon around them
    // (David, 2026-10-24, item 16: "get rid of the UI boxes and circles. just write the words").
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Stack(
        fit: StackFit.expand,
        children: [
          Opacity(opacity: t, child: VScrim(onTap: onClose)),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                // the actions end just above the dock, within the thumb's reach
                padding: const EdgeInsets.fromLTRB(VSpace.lg, VSpace.lg, VSpace.lg, 96),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Opacity(
                        opacity: t,
                        child: Transform.translate(
                          offset: Offset(0, 18 * (1 - t)),
                          child: Transform.scale(
                            scale: 0.97 + 0.03 * t,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(maxWidth: 320, maxHeight: size.height * 0.5),
                              child: VFadeScroll(
                                fade: 30,
                                padding: const EdgeInsets.symmetric(vertical: 24),
                                child: MdText(
                                  message.text,
                                  style: VType.body().copyWith(fontSize: 14.5, height: 1.5, shadows: const [Shadow(color: Color(0x8A000000), blurRadius: 12)]),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: VSpace.md),
                    Opacity(
                      opacity: ((t - 0.45) / 0.55).clamp(0.0, 1.0),
                      child: Transform.translate(
                        offset: Offset(0, 10 * (1 - t)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _Word('Copy', () => _copy(context)),
                            _Word('Save', () => _save(context)),
                            if (canShareText) _Word('Share', () => _share(context)),
                            _Word('Close', onClose, quiet: true),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One action as a lit, floating word: no platter, no outline, no icon. It brightens under the pointer
/// and dips when pressed.
class _Word extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final bool quiet;
  const _Word(this.label, this.onTap, {this.quiet = false});

  @override
  State<_Word> createState() => _WordState();
}

class _WordState extends State<_Word> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final lit = _hover;
    final color = widget.quiet && !lit ? const Color(0xA6FFFFFF) : (lit ? Colors.white : const Color(0xEBFFFFFF));
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: VPress(
        onTap: widget.onTap,
        tooltip: null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: AnimatedDefaultTextStyle(
            duration: VMotion.fast,
            style: VType.callout(color: color, weight: FontWeight.w600).copyWith(
              fontSize: 14,
              letterSpacing: 0.6,
              shadows: [
                const Shadow(color: Color(0x99000000), blurRadius: 10, offset: Offset(0, 3)),
                Shadow(color: Colors.white.withValues(alpha: lit ? 0.55 : 0.18), blurRadius: lit ? 14 : 8),
              ],
            ),
            child: Text(widget.label),
          ),
        ),
      ),
    );
  }
}
