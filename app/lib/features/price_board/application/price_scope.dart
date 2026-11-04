import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/app_config.dart';

/// Which place the price board shows: the whole province (null, the default) or one
/// municipality. Remembered on the device, like the municipality switcher in One Vizcaya.
const _prefsKey = 'timbang.priceScope';

/// Saved scope read at startup (overridden in bootstrap). '' or null = whole province.
final savedPriceScopeProvider = Provider<String?>((ref) => null);

class PriceScopeController extends Notifier<String?> {
  @override
  String? build() {
    final saved = ref.watch(savedPriceScopeProvider);
    return AppConfig.municipalities.contains(saved) ? saved : null;
  }

  /// null = all of Nueva Vizcaya.
  Future<void> choose(String? municipality) async {
    state = AppConfig.municipalities.contains(municipality) ? municipality : null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, state ?? '');
    } catch (_) {
      // Not saved (private browser window): the choice still applies for this session.
    }
  }
}

final priceScopeProvider = NotifierProvider<PriceScopeController, String?>(
  PriceScopeController.new,
);

Future<String?> loadSavedPriceScope() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(_prefsKey);
    return (v == null || v.isEmpty) ? null : v;
  } catch (_) {
    return null;
  }
}
