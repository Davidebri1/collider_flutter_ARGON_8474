import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/api/collider_api.dart';
import '../../../core/vision/vision_kit.dart';

/// Persistent account & session housekeeping store (R01–R04, R59).
class AccountStore {
  static const _kSignedIn = 'collider_acct_signed_in_v1';
  static const _kName = 'collider_acct_name_v1';
  static const _kEmail = 'collider_acct_email_v1';
  static const _kProvider = 'collider_acct_provider_v1';
  static const _kTier = 'collider_acct_tier_v1';

  static bool signedIn = true;
  static String name = 'David Ebri';
  static String email = 'david@collider.ai';
  static String provider = 'Google';
  static String tier = 'Pro'; // Free | Pro | Elite
  static bool _loaded = false;

  static Future<void> load() async {
    if (_loaded) return;
    final p = await SharedPreferences.getInstance();
    signedIn = p.getBool(_kSignedIn) ?? true;
    name = p.getString(_kName) ?? 'David Ebri';
    email = p.getString(_kEmail) ?? 'david@collider.ai';
    provider = p.getString(_kProvider) ?? 'Google';
    tier = p.getString(_kTier) ?? 'Pro';
    _loaded = true;
  }

  static Future<void> signIn({
    required String newProvider,
    required String newName,
    required String newEmail,
    String? newTier,
  }) async {
    signedIn = true;
    provider = newProvider;
    name = newName;
    email = newEmail;
    if (newTier != null) tier = newTier;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kSignedIn, true);
    await p.setString(_kProvider, provider);
    await p.setString(_kName, name);
    await p.setString(_kEmail, email);
    await p.setString(_kTier, tier);
  }

  static Future<void> setTier(String newTier) async {
    tier = newTier;
    final p = await SharedPreferences.getInstance();
    await p.setString(_kTier, tier);
  }

  static Future<void> signOut() async {
    signedIn = false;
    provider = 'Guest';
    name = 'Guest Session';
    email = 'Local device storage only';
    tier = 'Free';
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kSignedIn, false);
    await p.setString(_kProvider, provider);
    await p.setString(_kName, name);
    await p.setString(_kEmail, email);
    await p.setString(_kTier, tier);
  }
}

/// Settings & Account Drawer — Temporary / Demure Hologram Popup (R35, R47):
/// Floats directly over the canvas without a full-screen dimming scrim and fades into the air.
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
  int _tab = Uri.base.queryParameters['sub'] == 'account' ? 1 : 0;
  String _phone = '', _qr = '';
  bool _emailPrompt = false;
  final TextEditingController _emailCtrl = TextEditingController(text: 'david@collider.ai');

  @override
  void initState() {
    super.initState();
    AccountStore.load().then((_) {
      if (mounted) setState(() {});
    });
    ColliderApi.instance.phone().then((v) {
      if (mounted) {
        setState(() {
          _phone = v.$1;
          _qr = v.$2;
        });
      }
    });
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  void _showPhone() {
    final png = base64Decode(_qr.substring(_qr.indexOf(',') + 1));
    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (ctx) => Center(
        child: VPress(
          onTap: () {
            Clipboard.setData(ClipboardData(text: _phone));
            Navigator.of(ctx).pop();
          },
          child: VGlass(
            material: VMaterial.modal,
            radius: VRadius.card,
            padding: const EdgeInsets.all(14),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(VRadius.row),
              child: Image.memory(png, width: 220, height: 220, filterQuality: FilterQuality.none),
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(String label, Widget trailing, {String? sub}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: VType.callout(color: VColors.textPrimary, weight: FontWeight.w500).copyWith(fontSize: 11.0)),
                  if (sub != null) Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: VType.caption(color: VColors.textTertiary).copyWith(fontSize: 9.5)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            trailing,
          ],
        ),
      );

  Widget _tabs() => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(children: [
          for (final (i, t) in const ['Settings', 'Account'].indexed) ...[
            if (i > 0) const SizedBox(width: 14),
            VPress(
              onTap: () => setState(() => _tab = i),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(
                  t,
                  style: VType.callout(
                    color: i == _tab ? VColors.textPrimary : VColors.textSecondary,
                    weight: i == _tab ? FontWeight.w600 : FontWeight.w500,
                  ).copyWith(fontSize: 11.5),
                ),
                const SizedBox(height: 3),
                AnimatedContainer(
                  duration: VMotion.fast,
                  width: 18,
                  height: 2,
                  decoration: BoxDecoration(
                    color: i == _tab ? VColors.accentBlue : Colors.transparent,
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: i == _tab ? VShadow.emissive(VColors.accentBlue, intensity: 0.9) : null,
                  ),
                ),
              ]),
            ),
          ],
          const Spacer(),
          VCircleButton(icon: Icons.close_rounded, size: 22, tooltip: 'Close', onTap: widget.onClose),
        ]),
      );

  Widget _link(String label, VoidCallback onTap, {String? badge, Color? badgeColor}) => VPress(
        onTap: onTap,
        child: _row(
          label,
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (badge != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: (badgeColor ?? VColors.accentBlue).withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(VRadius.full),
                    border: Border.all(color: (badgeColor ?? VColors.accentBlue).withValues(alpha: 0.55), width: 0.6),
                  ),
                  child: Text(badge, style: VType.caption(color: Colors.white, weight: FontWeight.w600).copyWith(fontSize: 9.5)),
                ),
                const SizedBox(width: 4),
              ],
              const Icon(Icons.chevron_right_rounded, size: 14, color: VColors.textSecondary),
            ],
          ),
        ),
      );

  Widget _authButton(IconData icon, String label, Color accent, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: VPress(
          onTap: onTap,
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(VRadius.row),
              border: Border.all(color: accent.withValues(alpha: 0.45), width: 0.6),
            ),
            child: Row(
              children: [
                Icon(icon, size: 16, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text(label, style: VType.callout(weight: FontWeight.w600))),
                const Icon(Icons.arrow_forward_rounded, size: 14, color: VColors.textSecondary),
              ],
            ),
          ),
        ),
      );

  Widget _buildAccountTab(SettingsDrawer w) {
    final tierColor = switch (AccountStore.tier) {
      'Elite' => VColors.accentGold,
      'Pro' => VColors.accentBlue,
      _ => VColors.textSecondary,
    };
    final quotaText = switch (AccountStore.tier) {
      'Elite' => 'Unlimited Frontier + Cinema Video',
      'Pro' => '462 / 500 Pro Queries Left Today',
      _ => '12 / 20 Free Daily Queries Left',
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Identity & Tier card
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0x1FFFFFFF),
            borderRadius: BorderRadius.circular(VRadius.row),
            border: Border.all(color: tierColor.withValues(alpha: 0.45), width: 0.6),
          ),
          child: Row(
            children: [
              VAvatar(label: AccountStore.name, color: tierColor, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(AccountStore.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: VType.caption(color: Colors.white, weight: FontWeight.w600)),
                    Text(quotaText, maxLines: 1, overflow: TextOverflow.ellipsis, style: VType.metaCaption(color: VColors.textSecondary)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: tierColor.withValues(alpha: 0.24),
                  borderRadius: BorderRadius.circular(VRadius.full),
                  border: Border.all(color: tierColor.withValues(alpha: 0.7), width: 0.6),
                ),
                child: Text(AccountStore.tier, style: VType.metaCaption(color: Colors.white, weight: FontWeight.w700)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 5),
        // Quick Tier Switcher (Free / Pro / Elite)
        Row(
          children: [
            for (final t in const ['Free', 'Pro', 'Elite']) ...[
              if (t != 'Free') const SizedBox(width: 4),
              Expanded(
                child: VPress(
                  onTap: () async {
                    await AccountStore.setTier(t);
                    if (mounted) setState(() {});
                  },
                  child: Container(
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AccountStore.tier == t ? VColors.fillActive : VColors.fillCell,
                      borderRadius: BorderRadius.circular(VRadius.full),
                      border: Border.all(color: AccountStore.tier == t ? VColors.borderHeavy : VColors.borderSubtle, width: 0.5),
                    ),
                    child: Text(t, style: VType.metaCaption(color: AccountStore.tier == t ? Colors.white : VColors.textSecondary, weight: FontWeight.w600)),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 5),
        if (!AccountStore.signedIn) ...[
          _authButton(Icons.g_mobiledata_rounded, 'Continue with Google', VColors.accentBlue, () async {
            await AccountStore.signIn(newProvider: 'Google', newName: 'David Ebri', newEmail: 'david@collider.ai', newTier: 'Pro');
            if (mounted) setState(() {});
          }),
          _authButton(Icons.apple_rounded, 'Continue with Apple', const Color(0xFF94A3B8), () async {
            await AccountStore.signIn(newProvider: 'Apple ID', newName: 'David Ebri', newEmail: 'david@icloud.com', newTier: 'Pro');
            if (mounted) setState(() {});
          }),
          if (!_emailPrompt)
            _authButton(Icons.auto_awesome_rounded, 'Sign in with Email', VColors.accentPurple, () => setState(() => _emailPrompt = true))
          else
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: VRecessed(
                height: 28,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _emailCtrl,
                        style: VType.caption(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'you@domain.com',
                          hintStyle: VType.caption(color: VColors.textTertiary),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                        onSubmitted: (v) async {
                          final em = v.trim().isEmpty ? 'david@collider.ai' : v.trim();
                          await AccountStore.signIn(newProvider: 'Email', newName: em.split('@').first, newEmail: em);
                          if (mounted) setState(() => _emailPrompt = false);
                        },
                      ),
                    ),
                    VCircleButton(
                      icon: Icons.check_rounded,
                      size: 22,
                      selected: true,
                      onTap: () async {
                        final em = _emailCtrl.text.trim().isEmpty ? 'david@collider.ai' : _emailCtrl.text.trim();
                        await AccountStore.signIn(newProvider: 'Email', newName: em.split('@').first, newEmail: em);
                        if (mounted) setState(() => _emailPrompt = false);
                      },
                    ),
                  ],
                ),
              ),
            ),
        ],
        _link('Purchased Themes & Media', w.onOpenPurchased),
        _link('Upgrade Plan & Quotas', w.onOpenUpgrade, badge: AccountStore.tier, badgeColor: tierColor),
        if (_phone.isNotEmpty && _qr.isNotEmpty) _link('Phone QR Instant Link', _showPhone, badge: 'Live'),
        if (AccountStore.signedIn)
          VPress(
            onTap: () async {
              await AccountStore.signOut();
              if (mounted) setState(() {});
            },
            child: _row(
              'Sign Out',
              const Icon(Icons.logout_rounded, size: 13, color: VColors.accentRed),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final w = widget;
    // Compact snap popover (<= 1/4 of screen size) anchored cleanly above the bottom dock with zero background blur scrim.
    return Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: w.onClose,
          child: const SizedBox.expand(),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 68,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 214, maxWidth: 236, maxHeight: 198),
              child: GestureDetector(
                onTap: () {},
                child: VGlass(
                  material: VMaterial.modal,
                  radius: VRadius.card,
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: AnimatedSize(
                    duration: VMotion.fast,
                    curve: Curves.easeOutCubic,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _tabs(),
                        Flexible(
                          child: EdgeFade(
                            fadeHeight: 12,
                            child: SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              child: _tab == 0
                                  ? Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        _row(
                                          'Incognito Session',
                                          VToggle(value: w.incognito, onChanged: w.onIncognito),
                                          sub: 'Zero server history or disk trace',
                                        ),
                                        _row(
                                          'Auto-Save to History',
                                          VToggle(value: w.autosave, onChanged: w.incognito ? null : w.onAutosave),
                                          sub: 'Persist threads & Smart Gen',
                                        ),
                                        _row(
                                          'Spatial Light Emittance',
                                          const VToggle(value: true),
                                          sub: 'Live radial glow on active pills',
                                        ),
                                      ],
                                    )
                                  : _buildAccountTab(w),
                            ),
                          ),
                        ),
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
