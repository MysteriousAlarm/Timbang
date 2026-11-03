import 'package:flutter/widgets.dart';

import '../domain/catalog_item.dart';

/// Commodity names in the user's language: English first in English, Filipino first in Filipino.
extension CommodityNames on Commodity {
  bool _english(BuildContext context) => Localizations.localeOf(context).languageCode == 'en';

  /// Main name in the current language (falls back to the other name if it is empty).
  String nameIn(BuildContext context) {
    final en = _english(context) && nameEn.trim().isNotEmpty;
    return en ? nameEn : nameFil;
  }

  /// The other language's name, or '' when it is the same or missing.
  String altNameIn(BuildContext context) {
    final main = nameIn(context);
    final other = main == nameFil ? nameEn : nameFil;
    return other.trim().isEmpty || other == main ? '' : other;
  }

  /// "Tomato (Kamatis)" / "Kamatis (Tomato)" for dropdowns.
  String labelIn(BuildContext context) {
    final alt = altNameIn(context);
    return alt.isEmpty ? nameIn(context) : '${nameIn(context)} ($alt)';
  }
}
