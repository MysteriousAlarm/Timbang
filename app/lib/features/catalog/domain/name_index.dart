import '../../../shared/utils/names.dart';
import 'catalog_item.dart';

/// normKey(name) -> ID, for reading office spreadsheets that use names instead of IDs.
/// Filipino and English names both work.
Map<String, String> commodityNameIndex(Iterable<Commodity> items) => {
  for (final c in items) ...{
    normKey(c.id): c.id,
    if (c.nameEn.trim().isNotEmpty) normKey(c.nameEn): c.id,
    normKey(c.nameFil): c.id,
  },
};

/// Market name or ID -> ID. A town name also works when that town has exactly one market
/// ("Bayombong" -> the Bayombong public market).
Map<String, String> marketNameIndex(Iterable<Market> items) {
  final byTown = <String, List<Market>>{};
  for (final m in items) {
    byTown.putIfAbsent(normKey(m.municipality), () => []).add(m);
  }
  return {
    for (final e in byTown.entries)
      if (e.value.length == 1) e.key: e.value.single.id,
    for (final m in items) ...{normKey(m.id): m.id, normKey(m.name): m.id},
  };
}
