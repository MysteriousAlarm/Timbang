import '../../../core/config/app_config.dart';

enum CatalogKind {
  commodities,
  markets;

  /// CSV header, in order. `active` is optional (defaults to true).
  List<String> get columns => switch (this) {
    CatalogKind.commodities => const ['id', 'nameFil', 'nameEn', 'unit', 'category', 'active'],
    CatalogKind.markets => const ['id', 'name', 'municipality', 'type', 'active'],
  };

  List<String> get requiredColumns => columns.where((c) => c != 'active').toList();
}

/// Common shape of commodities and markets for tables and imports.
sealed class CatalogItem {
  const CatalogItem({required this.id, required this.active, this.isDemo = false});

  final String id;
  final bool active;

  /// Seeded placeholder data; shown with a DEMO badge and a banner, never as real.
  final bool isDemo;

  String get displayName;

  /// Payload for the `upsertCatalog` function (isDemo is set server-side).
  Map<String, Object> toPayload();
}

class Commodity extends CatalogItem {
  const Commodity({
    required super.id,
    required this.nameFil,
    required this.nameEn,
    required this.unit,
    required this.category,
    super.active = true,
    super.isDemo,
  });

  final String nameFil;
  final String nameEn;

  /// kg | bundle | piece
  final String unit;
  final String category;

  @override
  String get displayName => nameFil;

  factory Commodity.fromMap(String id, Map<String, dynamic> m) => Commodity(
    id: id,
    nameFil: (m['nameFil'] as String?) ?? id,
    nameEn: (m['nameEn'] as String?) ?? '',
    unit: (m['unit'] as String?) ?? 'kg',
    category: (m['category'] as String?) ?? '',
    active: m['active'] != false,
    isDemo: m['isDemo'] == true,
  );

  @override
  Map<String, Object> toPayload() => {
    'id': id,
    'nameFil': nameFil,
    'nameEn': nameEn,
    'unit': unit,
    'category': category,
    'active': active,
  };
}

class Market extends CatalogItem {
  const Market({
    required super.id,
    required this.name,
    required this.municipality,
    required this.type,
    super.active = true,
    super.isDemo,
  });

  final String name;
  final String municipality;

  /// public_market | trading_post | farmgate_area
  final String type;

  @override
  String get displayName => name;

  factory Market.fromMap(String id, Map<String, dynamic> m) => Market(
    id: id,
    name: (m['name'] as String?) ?? id,
    municipality: (m['municipality'] as String?) ?? '',
    type: (m['type'] as String?) ?? 'public_market',
    active: m['active'] != false,
    isDemo: m['isDemo'] == true,
  );

  @override
  Map<String, Object> toPayload() => {
    'id': id,
    'name': name,
    'municipality': municipality,
    'type': type,
    'active': active,
  };
}

/// "Kamatis (Pula)" -> "kamatis-pula"
String slugify(String input) {
  const accents = {'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', 'ñ': 'n'};
  final lower = input.toLowerCase().split('').map((c) => accents[c] ?? c).join();
  final slug = lower.replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');
  return slug.length > 49 ? slug.substring(0, 49).replaceAll(RegExp(r'-+$'), '') : slug;
}

bool validCatalogId(String id) => AppConfig.catalogIdPattern.hasMatch(id);
