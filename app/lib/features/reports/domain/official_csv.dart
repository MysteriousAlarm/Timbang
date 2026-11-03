import '../../../core/config/app_config.dart';
import '../../../shared/utils/csv.dart';
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

/// Header aliases, because the agencies' exact format is not known yet.
const _aliases = {
  'commodityId': ['commodityid', 'commodity', 'commodity_id', 'bilihin', 'item'],
  'marketId': ['marketid', 'market', 'market_id', 'palengke'],
  'price': ['price', 'presyo', 'prevailing_price', 'median'],
  'date': ['date', 'petsa', 'observed', 'observed_at'],
};

/// Parses an official price CSV. Column names are matched case-insensitively with
/// aliases; commodity/market values must be catalog IDs (known ids are checked here).
OfficialImport parseOfficialCsv(
  String text, {
  required Set<String> commodityIds,
  required Set<String> marketIds,
}) => parseOfficialTable(parseCsv(text), commodityIds: commodityIds, marketIds: marketIds);

/// Same as [parseOfficialCsv] for rows already read from a CSV or Excel file.
OfficialImport parseOfficialTable(
  List<List<String>> table, {
  required Set<String> commodityIds,
  required Set<String> marketIds,
}) {
  if (table.isEmpty) return const OfficialImport([]);
  final header = [for (final h in table.first) h.trim().toLowerCase()];
  final col = <String, int>{};
  _aliases.forEach((key, names) {
    final i = header.indexWhere(names.contains);
    if (i >= 0) col[key] = i;
  });
  final missing = [
    for (final k in const ['commodityId', 'marketId', 'price'])
      if (!col.containsKey(k)) k,
  ];
  if (missing.isNotEmpty) return OfficialImport(const [], headerIssues: missing);

  final rows = <OfficialRow>[];
  for (var r = 1; r < table.length; r++) {
    final cells = table[r];
    String get(String k) {
      final i = col[k];
      return i == null || i >= cells.length ? '' : cells[i].trim();
    }

    final issues = <String>[];
    final c = get('commodityId').toLowerCase();
    final m = get('marketId').toLowerCase();
    final price = parsePrice(get('price'));
    final rawDate = get('date');
    if (!commodityIds.contains(c)) issues.add('commodityId');
    if (!marketIds.contains(m)) issues.add('marketId');
    if (price == null) issues.add('price');
    String? date;
    if (rawDate.isNotEmpty) {
      final ok =
          RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(rawDate) && DateTime.tryParse(rawDate) != null;
      if (ok) {
        date = rawDate;
      } else {
        issues.add('date');
      }
    }
    rows.add(
      OfficialRow(
        line: r + 1,
        commodityId: c,
        marketId: m,
        price: price,
        date: date,
        issues: issues,
      ),
    );
  }
  return OfficialImport(rows);
}

const officialCsvTemplate =
    'commodityId,marketId,price,date\n'
    'kamatis,bayombong-public-market,60.00,2026-11-03\n'
    'repolyo,bayombong-public-market,45.50,2026-11-03\n';
