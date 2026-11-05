import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Market switches, all off (David put the 2026-09-29 asks on hold, v8.3).
///
/// TEST PRICING: while true, every theme pack and the store subscription
/// cost $0.00 so the purchase flow can be tested end to end. Off: packs show
/// the catalog / S-C19 price.
const bool kTestFreePricing = false;

/// SUBSCRIPTION GATE (DEVIATIONS.md D6): while true, non-subscribers see the
/// first 3 themes only, with a subscription line and a Subscribe capsule
/// instead of Buy. Off: every theme, Buy / Apply, no subscription text.
const bool kSubscriptionGate = false;

/// A real store backend (StoreKit / Play Billing) is wired. Off on the web
/// link: Buy says purchases aren't available rather than unlocking for free.

/// OWNED BRIGHTER STATE (DEVIATIONS.md D5): while true, covers and the
/// background preview of themes the user does not own are dimmed and an
/// owned theme's preview lifts to full brightness. Off: the export's look
/// (brightness 0.5 / opacity 0.7 preview, undimmed covers) for every theme.
const bool kOwnedBrighterState = false;

/// DEBUG PREVIEW (map W3): shows the market's "Preview" button that applies
/// any theme for free, bypassing the price gate. For David's debugging.
/// Production builds pass --dart-define=COLLIDER_THEME_PREVIEW=false.
const bool kThemePreviewButton =
    bool.fromEnvironment('COLLIDER_THEME_PREVIEW', defaultValue: true);

/// Theme pack store. `purchasesAvailable` (COLLIDER_STORE) switches between
/// the real store backend (StoreKit / Play Billing via in_app_purchase) and
/// the local mock unlock used on the web/sandbox link. Both paths persist
/// into the same SharedPreferences keys, so call sites never change.
class ThemePackStore extends ChangeNotifier {
  ThemePackStore._();
  static final ThemePackStore instance = ThemePackStore._();

  static const _prefsKey = 'theme_pack_unlocked_ids';
  static const _subKey = 'theme_store_subscription_active';

  /// Price label shown while [kTestFreePricing] is on.
  static const String freePriceLabel = r'$0.00';

  /// Store subscription price label; null when no price is configured.
  static String? get subscriptionPriceLabel => kTestFreePricing ? freePriceLabel : null;

  /// Non-subscribers see this many themes (dimmed live previews) and no store.
  static const int previewCountWithoutSubscription = 3;

  /// Subscription product id (configurable in the store console).
  static const String subscriptionProductId = 'collider.theme.subscription';

  bool _subscribed = false;

  /// Paid store subscription (mock entitlement; persisted like pack unlocks).
  bool get isSubscribed => _subscribed;

  /// The whole store is open: no gate ([kSubscriptionGate] off), or subscribed.
  bool get storeOpen => !kSubscriptionGate || _subscribed;

  final Set<String> _unlocked = {};
  bool _ready = false;
  bool get isReady => _ready;

  static const bool purchasesAvailable = bool.fromEnvironment('COLLIDER_STORE');

  /// Fallback pack price when the catalog carries none (live wallpaper + 5 tracks).
  static const String packPriceLabel = r'$5.99';

  /// S-C19 price band for one pack.
  static const double minPackPrice = 2.99;
  static const double maxPackPrice = 7.99;

  // -- real store state -----------------------------------------------------
  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;
  final Map<String, ProductDetails> _products = {};
  bool _storeAlive = false;
  String? lastStoreError;

  /// Store product id: `collider.theme.<slug>`.
  String productIdFor(String slug) => 'collider.theme.$slug';

  ProductDetails? productForSlug(String slug) =>
      _products[productIdFor(slug)];

  /// Query the store for the catalog's premium product ids. Call once the
  /// ThemeCatalog is loaded. No-op when the store is not available.
  Future<void> refreshProducts(Set<String> productIds) async {
    if (!purchasesAvailable || productIds.isEmpty) return;
    try {
      final available = await InAppPurchase.instance.isAvailable();
      _storeAlive = available;
      if (!available) return;
      final resp = await InAppPurchase.instance
          .queryProductDetails(productIds.map(productIdFor).toSet());
      _products
        ..clear()
        ..addEntries([for (final p in resp.productDetails) MapEntry(p.id, p)]);
      _purchaseSub ??= InAppPurchase.instance.purchaseStream.listen(
        _onPurchases,
        onDone: () => _purchaseSub = null,
        onError: (Object e) {
          lastStoreError = e.toString();
          notifyListeners();
        },
      );
      notifyListeners();
    } catch (e) {
      // No store on this platform/link — the mock path keeps working.
      _storeAlive = false;
      lastStoreError = e.toString();
    }
  }

  void _onPurchases(List<PurchaseDetails> purchases) {
    var changed = false;
    for (final p in purchases) {
      final slug = _slugForProductId(p.productID);
      switch (p.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          if (slug != null && !_unlocked.contains(slug)) {
            _unlocked.add(slug);
            changed = true;
          }
          if (p.productID == subscriptionProductId && !_subscribed) {
            _subscribed = true;
            _persistSubscription();
            changed = true;
          }
          if (p.pendingCompletePurchase) {
            InAppPurchase.instance.completePurchase(p);
          }
        case PurchaseStatus.error:
          lastStoreError = p.error?.message;
        case PurchaseStatus.pending:
        case PurchaseStatus.canceled:
          break;
      }
    }
    if (changed) {
      _persist();
      notifyListeners();
    }
  }

  String? _slugForProductId(String productId) {
    const prefix = 'collider.theme.';
    if (productId == subscriptionProductId) return null;
    return productId.startsWith(prefix) ? productId.substring(prefix.length) : null;
  }

  Future<void> init() async {
    if (_ready) return;
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_prefsKey) ?? const <String>[];
    _unlocked
      ..clear()
      ..addAll(list);
    _subscribed = prefs.getBool(_subKey) ?? false;
    _ready = true;
    notifyListeners();
  }

  bool isUnlocked(String slug) => _unlocked.contains(slug);

  /// The catalog's per-theme price (themes.json `price`) when it is a valid
  /// label inside the S-C19 band ($2.99-$7.99); otherwise [packPriceLabel].
  String priceLabelFor(String slug, {String? catalogPrice}) {
    if (kTestFreePricing) return freePriceLabel;
    final m = RegExp(r'^\$(\d+(?:\.\d{2})?)$').firstMatch(catalogPrice?.trim() ?? '');
    final v = m == null ? null : double.tryParse(m.group(1)!);
    if (v != null && v >= minPackPrice && v <= maxPackPrice) return catalogPrice!.trim();
    return packPriceLabel;
  }

  /// Buy a pack. With a live store this starts the platform purchase flow —
  /// ownership lands via [refreshProducts]'s purchase stream. Without one,
  /// the sandbox mock unlocks locally (web link behaviour).
  Future<bool> buyPack(String slug) async {
    await init();
    final details = purchasesAvailable ? productForSlug(slug) : null;
    if (details != null && _storeAlive) {
      return InAppPurchase.instance
          .buyNonConsumable(purchaseParam: PurchaseParam(productDetails: details));
    }
    _unlocked.add(slug);
    await _persist();
    notifyListeners();
    return true;
  }

  /// DEBUG PREVIEW (map W3): unlocks [slug] for this session only — no
  /// persistence, no price gate. Used by the market's Preview button, which
  /// only exists while [kThemePreviewButton] is on.
  void previewUnlock(String slug) {
    _unlocked.add(slug);
    notifyListeners();
  }

  /// Mock store subscription ($0 while [kTestFreePricing]). Same sandbox path as
  /// [buyPack]: the entitlement is recorded locally.
  Future<bool> subscribe() async {
    await init();
    _subscribed = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_subKey, true);
    notifyListeners();
    return true;
  }

  /// Test hook: `?store=reset` clears the subscription and every pack unlock.
  Future<void> resetForTesting() async {
    await init();
    _subscribed = false;
    _unlocked.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_subKey);
    await prefs.remove(_prefsKey);
    notifyListeners();
  }

  Future<void> restorePurchases() async {
    await init();
    if (purchasesAvailable && _storeAlive) {
      // Restored entitlements arrive on the purchase stream.
      await InAppPurchase.instance.restorePurchases();
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_prefsKey) ?? const <String>[];
    _unlocked
      ..clear()
      ..addAll(list);
    _subscribed = prefs.getBool(_subKey) ?? false;
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKey, _unlocked.toList()..sort());
  }

  Future<void> _persistSubscription() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_subKey, true);
  }
}
