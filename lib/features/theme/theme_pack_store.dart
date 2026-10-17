import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Theme pack IAP scaffold — productId per Designer premium slug.
/// Web/sandbox: mock buy unlocks locally via SharedPreferences.
class ThemePackStore extends ChangeNotifier {
  ThemePackStore._();
  static final ThemePackStore instance = ThemePackStore._();

  static const _prefsKey = 'theme_pack_unlocked_ids';

  final Set<String> _unlocked = {};
  bool _ready = false;
  bool get isReady => _ready;

  static const Map<String, String> productIds = {
    'obsidian-rain': 'collider.theme.obsidian-rain',
    'limestone-dust': 'collider.theme.limestone-dust',
    'glasshouse-fog': 'collider.theme.glasshouse-fog',
    'copper-kiln': 'collider.theme.copper-kiln',
    'tide-concrete': 'collider.theme.tide-concrete',
    'paper-lantern-alley': 'collider.theme.paper-lantern-alley',
    'snowmelt-atrium': 'collider.theme.snowmelt-atrium',
    'lantern-alley': 'collider.theme.lantern-alley',
    'tide-glass': 'collider.theme.tide-glass',
    'observatory': 'collider.theme.observatory',
    'brutal-atrium': 'collider.theme.brutal-atrium',
    'bamboo-corridor': 'collider.theme.bamboo-corridor',
    'canopy-shafts': 'collider.theme.canopy-shafts',
    'salt-flat-dusk': 'collider.theme.salt-flat-dusk',
    'harbor-crane-night': 'collider.theme.harbor-crane-night',
    'gilt-arcade': 'collider.theme.gilt-arcade',
    'indigo-dye-vat': 'collider.theme.indigo-dye-vat',
    'earthen-kiln': 'collider.theme.earthen-kiln',
    'subway-platform': 'collider.theme.subway-platform',
  };

  static const Map<String, String> priceLabels = {
    'obsidian-rain': r'$5.99',
    'limestone-dust': r'$4.99',
    'glasshouse-fog': r'$5.99',
    'copper-kiln': r'$6.99',
    'tide-concrete': r'$4.99',
    'paper-lantern-alley': r'$5.99',
    'snowmelt-atrium': r'$5.99',
    'lantern-alley': r'$3.99',
    'tide-glass': r'$4.99',
    'observatory': r'$6.99',
    'brutal-atrium': r'$7.99',
    'bamboo-corridor': r'$4.99',
    'canopy-shafts': r'$5.99',
    'salt-flat-dusk': r'$4.99',
    'harbor-crane-night': r'$5.99',
    'gilt-arcade': r'$6.99',
    'indigo-dye-vat': r'$5.99',
    'earthen-kiln': r'$5.99',
    'subway-platform': r'$4.99',
  };

  Future<void> init() async {
    if (_ready) return;
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_prefsKey) ?? const <String>[];
    _unlocked
      ..clear()
      ..addAll(list);
    _ready = true;
    notifyListeners();
  }

  bool isUnlocked(String slug) => _unlocked.contains(slug);

  /// Purchased pack slugs (Files > Purchased lists them).
  Set<String> get unlocked => Set.unmodifiable(_unlocked);

  String productIdFor(String slug) =>
      productIds[slug] ?? 'collider.theme.$slug';

  String priceLabelFor(String slug) => priceLabels[slug] ?? r'$4.99';

  Future<bool> buyPack(String slug) async {
    await init();
    _unlocked.add(slug);
    await _persist();
    notifyListeners();
    return true;
  }

  Future<void> restorePurchases() async {
    await init();
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_prefsKey) ?? const <String>[];
    _unlocked
      ..clear()
      ..addAll(list);
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKey, _unlocked.toList()..sort());
  }
}
