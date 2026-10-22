import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import '../../../core/api/collider_api.dart';
import '../../../core/vision/vision_kit.dart';

/// Settings. Made by Claude (2026-10-04).
/// It holds two switches, so it is a pane the size of two switches, sitting just above the dock. The screen behind stays recognisable. It closes like a pause menu: tap outside
/// it, or the dock button again.
/// Nothing here is for developers. The provider names that were listed (NVIDIA, Tavily) are gone:
/// David never asked for them and they mean nothing to a user.
///
/// Account (2026-10-17, map row 18, David: "make sure the account tab isnt oversized or big. there's no profile picture
/// so omit that section. no submenu should be larger than its menu"): a second tab in this same small pane, rows the
/// same height as the switches, each opening what the app already holds for the account: what was bought (Files ›
/// Purchased) and the upgrade. No picture, no name block, nothing the app does not have.
class SettingsDrawer extends StatefulWidget {
  final VoidCallback onClose;
  final bool incognito;
  final bool autosave;
  final ValueChanged<bool> onIncognito;
  final ValueChanged<bool> onAutosave;
  final VoidCallback onOpenPurchased;
  final VoidCallback onOpenUpgrade;

  const SettingsDrawer({
    super.key,
    required this.onClose,
    required this.incognito,
    required this.autosave,
    required this.onIncognito,
    required this.onAutosave,
    required this.onOpenPurchased,
    required this.onOpenUpgrade,
  });

  @override
  State<SettingsDrawer> createState() => _SettingsDrawerState();
}

class _SettingsDrawerState extends State<SettingsDrawer> {
  int _tab = 0;
  String _phone = '', _qr = ''; // the phone link (Claude, 2026-10-21)

  @override
  void initState() {
    super.initState();
    ColliderApi.instance.phone().then((v) {
      if (mounted) {
        setState(() {
          _phone = v.$1;
          _qr = v.$2;
        });
      }
    });
  }

  /// The phone link as a QR code for the phone's camera; a tap on it copies the link.
  void _showPhone() {
    final png = base64Decode(_qr.substring(_qr.indexOf(',') + 1));
    showDialog(
      context: context,
      barrierColor: VOverlay.scrim,
      builder: (ctx) => Center(
        child: VPress(
          onTap: () {
            Clipboard.setData(ClipboardData(text: _phone));
            Navigator.of(ctx).pop();
          },
          child: VGlass(
            material: VMaterial.modal,
            radius: 22,
            padding: const EdgeInsets.all(14),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(png, width: 220, height: 220, filterQuality: FilterQuality.none),
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(String label, Widget trailing) => SizedBox(
        height: 36,
        child: Row(
          children: [
            Text(label, maxLines: 1, style: VType.callout(color: const Color(0xF5FFFFFF), weight: FontWeight.w500).copyWith(fontSize: 13)),
            const SizedBox(width: 16),
            const Spacer(),
            trailing,
          ],
        ),
      );

  Widget _tabs() => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(children: [
          for (final (i, t) in const ['Settings', 'Account'].indexed) ...[
            if (i > 0) const SizedBox(width: 14),
            VPress(
              onTap: () => setState(() => _tab = i),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(t, style: VType.caption(color: i == _tab ? VColors.textPrimary : VColors.textSecondary, weight: i == _tab ? FontWeight.w600 : FontWeight.w500).copyWith(fontSize: 12)),
                const SizedBox(height: 3),
                AnimatedContainer(
                  duration: VMotion.fast,
                  width: 14,
                  height: 2,
                  decoration: BoxDecoration(color: i == _tab ? VColors.accentBlue : Colors.transparent, borderRadius: BorderRadius.circular(2)),
                ),
              ]),
            ),
          ],
        ]),
      );

  Widget _link(String label, VoidCallback onTap) => VPress(
        onTap: onTap,
        child: _row(label, const Icon(Icons.chevron_right_rounded, size: 18, color: VColors.textSecondary)),
      );

  @override
  Widget build(BuildContext context) {
    final w = widget;
    return Stack(
      fit: StackFit.expand,
      children: [
        VScrim(onTap: w.onClose, soft: true),
        Align(
          alignment: Alignment.bottomCenter,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 86),
              child: IntrinsicWidth(
                child: GestureDetector(
                  onTap: () {},
                  child: VGlass(
                    material: VMaterial.modal,
                    radius: 22,
                    padding: const EdgeInsets.fromLTRB(20, 10, 14, 10),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _tabs(),
                        // Both tabs keep the pane's size: the larger of the two sets it.
                        Stack(children: [
                          Visibility(
                            visible: _tab == 0,
                            maintainSize: true,
                            maintainAnimation: true,
                            maintainState: true,
                            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                              _row('Incognito', VToggle(value: w.incognito, onChanged: w.onIncognito)),
                              _row('Save to History', VToggle(value: w.autosave, onChanged: w.incognito ? null : w.onAutosave)),
                            ]),
                          ),
                          if (_tab == 1)
                            Positioned.fill(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                                _link('Purchased', w.onOpenPurchased),
                                _link('Upgrade', w.onOpenUpgrade),
                                if (_phone.isNotEmpty && _qr.isNotEmpty) _link('Phone', _showPhone),
                              ]),
                            ),
                        ]),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
