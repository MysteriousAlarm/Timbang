import '../../../core/config/app_config.dart';
import '../../../shared/utils/csv.dart';
import '../../../shared/utils/names.dart';
import 'price_report.dart';

/// One row of an official price file (DA / DAR / NVAT).
class OfficialRow {
  const OfficialRow({
    required this.line,
    required this.commodityId,
    required this.marketId,
    required this.price,
    this.date,
    this.issues = const [],
  });

  final int line;
  final String commodityId;
  final String marketId;
  final double? price;

  /// YYYY-MM-DD or null (= today).
  final String? date;
  final List<String> issues;
  bool get ok => issues.isEmpty;

  Map<String, Object> toPayload() => {
    'commodityId': commodityId,
    'marketId': marketId,
    'price': price!,
    'date': ?date,
  };
}

class OfficialImport {
  const OfficialImport(this.rows, {this.headerIssues = const []});
  final List<OfficialRow> rows;
  final List<String> headerIssues;
  int get errorCount => headerIssues.length + rows.where((r) => !r.ok).length;
  bool get tooMany => rows.length > AppConfig.officialImportMaxRows;
  bool get canImport => rows.isNotEmpty && errorCount == 0 && !tooMany;
}

/// Header aliases (compared with [normKey]), because the agencies' exact format is not
/// known yet. Price headers only need to start with one of these ("Price (P/kg)", "Presyo ngayon").
const _aliases = {
  'commodityId': [
    'commodityid',
    'commodity',
    'commodityname',
    'bilihin',
    'item',
    'items',
    'vegetable',
    'vegetables',
    'gulay',
    'produce',
    'name',
    'pangalan',
    'paninda',
    'description',
  ],
  'marketId': ['marketid', 'market', 'marketname', 'palengke', 'location', 'lugar'],
  'date': ['date', 'petsa', 'observed', 'observedat', 'dateobserved', 'asof'],
};
const _pricePrefixes = ['price', 'presyo', 'prevailing', 'retail', 'median', 'farmgate'];

bool _isPrice(String key) => _pricePrefixes.any(key.startsWith);

/// Parses an official price CSV. See [parseOfficialTable].
OfficialImport parseOfficialCsv(
  String text, {
  required Set<String> commodityIds,
  required Set<String> marketIds,
  Map<String, String> commodityNames = const {},
  Map<String, String> marketNames = const {},
}) => parseOfficialTable(
  parseCsv(text),
  commodityIds: commodityIds,
  marketIds: marketIds,
  commodityNames: commodityNames,
  marketNames: marketNames,
);

/// Reads an official price sheet as it comes from the office, in either layout:
/// - long: one row per price, with commodity, market and price columns (date optional);
/// - wide: one row per commodity and one column per market, each cell a price.
/// Commodities and markets may be written as their catalog ID or their name
/// ([commodityNames] / [marketNames] map [normKey] of a name to an ID).
/// Title rows above the header and sub-heading rows without prices are skipped.
OfficialImport parseOfficialTable(
  List<List<String>> table, {
  required Set<String> commodityIds,
  required Set<String> marketIds,
  Map<String, String> commodityNames = const {},
  Map<String, String> marketNames = const {},
}) {
  if (table.isEmpty) return const OfficialImport([]);
  String? resolve(String raw, Set<String> ids, Map<String, String> names) {
    final v = raw.trim().toLowerCase();
    if (ids.contains(v)) return v;
    final byName = names[normKey(raw)];
    return byName != null && ids.contains(byName) ? byName : null;
  }

  int? findCol(List<String> keys, List<String> names) {
    final i = keys.indexWhere(names.contains);
    return i < 0 ? null : i;
  }

  bool looksLikeHeader(List<String> keys) =>
      findCol(keys, _aliases['commodityId']!) != null &&
      (keys.any(_isPrice) || keys.any((k) => resolve(k, marketIds, marketNames) != null));

  final h = findHeaderRow(table, looksLikeHeader);
  final keys = [for (final c in table[h]) normKey(c)];
  final cCol = findCol(keys, _aliases['commodityId']!);
  final mCol = findCol(keys, _aliases['marketId']!);
  final dCol = findCol(keys, _aliases['date']!);
  final pIdx = keys.indexWhere(_isPrice);
  final pCol = pIdx < 0 ? null : pIdx;
  // Wide layout: headers that are markets.
  final marketCols = <int, String>{
    for (var i = 0; i < keys.length; i++)
      if (i != cCol && i != dCol && resolve(table[h][i], marketIds, marketNames) != null)
        i: resolve(table[h][i], marketIds, marketNames)!,
  };
  final wide = mCol == null && marketCols.isNotEmpty;
  final missing = [
    if (cCol == null) 'commodityId',
    if (!wide && mCol == null) 'marketId',
    if (!wide && pCol == null) 'price',
  ];
  if (missing.isNotEmpty) return OfficialImport(const [], headerIssues: missing);

  final rows = <OfficialRow>[];
  for (var r = h + 1; r < table.length; r++) {
    final cells = table[r];
    String cell(int? i) => i == null || i >= cells.length ? '' : cells[i].trim();
    final rawC = cell(cCol);
    final rawDate = cell(dCol);
    String? date;
    var dateBad = false;
    if (rawDate.isNotEmpty) {
      final ok =
          RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(rawDate) && DateTime.tryParse(rawDate) != null;
      if (ok) {
        date = rawDate;
      } else {
        dateBad = true;
      }
    }
    final pairs = wide
        ? [for (final e in marketCols.entries) (e.value, '', cell(e.key))]
        : [(resolve(cell(mCol), marketIds, marketNames), cell(mCol), cell(pCol))];
    // Sub-heading or empty row ("HIGHLAND VEGETABLES"): nothing to import.
    if (pairs.every((p) => p.$3.isEmpty) && (wide || cell(mCol).isEmpty)) continue;
    final c = resolve(rawC, commodityIds, commodityNames);
    for (final (marketId, rawMarket, rawPrice) in pairs) {
      if (wide && rawPrice.isEmpty) continue; // that market did not report this item
      final price = parsePrice(rawPrice);
      rows.add(
        OfficialRow(
          line: r + 1,
          commodityId: c ?? rawC.toLowerCase(),
          marketId: marketId ?? rawMarket.toLowerCase(),
          price: price,
          date: date,
          issues: [
            if (c == null) 'commodityId',
            if (marketId == null) 'marketId',
            if (price == null) 'price',
            if (dateBad) 'date',
          ],
        ),
      );
    }
  }
  return OfficialImport(rows);
}

const officialCsvTemplate =
    'commodityId,marketId,price,date\n'
    'kamatis,bayombong-public-market,60.00,2026-11-03\n'
    'repolyo,bayombong-public-market,45.50,2026-11-03\n';
