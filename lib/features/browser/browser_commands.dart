// W5: shared browser plumbing — the search-engine constant behind the rail's
// Search actuator, URL normalization used by both WebFrame implementations,
// the command hooks the side nav can send to the open sheet, and the embed
// error card (the dead-white-frame antidote).
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/vision/vision_kit.dart';

/// Rail Search actuator → engine results. DuckDuckGo's HTML endpoint is the
/// iframe-friendliest engine (www.google.com and duckduckgo.com both refuse
/// to be framed); the html host sets no X-Frame-Options.
const String kSearchEngine = 'https://html.duckduckgo.com/html/?q=';

/// User input → loadable URL: an address without a scheme gets https://.
String normalizeBrowserUrl(String input) {
  final t = input.trim();
  if (t.isEmpty || RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*://').hasMatch(t)) return t;
  return 'https://$t';
}

/// Commands the module rail (called via main.dart) can send to the open
/// browser sheet. Handlers are registered while the sheet is open and inert
/// otherwise; see InAppBrowserSheet.initState/dispose.
class BrowserCommands {
  BrowserCommands._();

  /// Tabs entry — toggles the tabs overview grid.
  static VoidCallback? toggleTabsOverview;

  /// Search Engine entry — navigates the active tab to [kSearchEngine].
  static VoidCallback? openSearchEngine;

  /// Clear Cache entry — clears webview/iframe state and remounts the page.
  static VoidCallback? clearCache;
}

/// Shown when a site refuses to be framed (web) or the main-frame load
/// errors (native). [onOpenExternal], when provided, performs a real
/// target="_blank" navigation — no dead white frame.
class BrowserEmbedError extends StatelessWidget {
  final String url;
  final VoidCallback? onOpenExternal;
  final VoidCallback? onReload;

  const BrowserEmbedError({super.key, required this.url, this.onOpenExternal, this.onReload});

  String get _host {
    final u = Uri.tryParse(url);
    return (u != null && u.host.isNotEmpty) ? u.host : url;
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(20),
        constraints: const BoxConstraints(maxWidth: 360),
        decoration: BoxDecoration(
          color: VColors.glassDark,
          borderRadius: BorderRadius.circular(VRadius.card),
          border: Border.all(color: VColors.borderLight),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.block_rounded, size: 32, color: VColors.textSecondary),
            const SizedBox(height: 12),
            Text(
              'This site refuses embedding',
              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: VColors.textPrimary),
            ),
            const SizedBox(height: 4),
            Text(
              _host,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(fontSize: 13, color: VColors.textSecondary),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (onOpenExternal != null)
                  FilledButton(
                    onPressed: onOpenExternal,
                    style: FilledButton.styleFrom(
                      backgroundColor: VColors.fillActive,
                      foregroundColor: VColors.textPrimary,
                      minimumSize: const Size(0, 40),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    child: Text('Open in a new tab', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                if (onOpenExternal != null && onReload != null) const SizedBox(width: 8),
                if (onReload != null)
                  TextButton(
                    onPressed: onReload,
                    style: TextButton.styleFrom(foregroundColor: VColors.textSecondary, minimumSize: const Size(0, 40)),
                    child: Text('Reload', style: GoogleFonts.inter(fontSize: 14)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
