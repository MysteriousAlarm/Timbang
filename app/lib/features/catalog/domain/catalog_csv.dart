import '../../../core/config/app_config.dart';
import '../../../shared/utils/csv.dart';
import 'catalog_item.dart';
import 'catalog_validation.dart';

class CsvRow {
  const CsvRow({required this.line, required this.item, required this.issues});

  /// 1-based line number in the file (header is line 1).
  final int line;
  final CatalogItem? item;
  final List<RowIssue> issues;
  bool get ok => issues.isEmpty && item != null;
}

class CsvImport {
  const CsvImport({required this.kind, required this.rows, this.headerIssues = const []});

  final CatalogKind kind;
  final List<CsvRow> rows;
  final List<RowIssue> headerIssues;

  List<CatalogItem> get items => [for (final r in rows) ?r.item];
  int get errorCount => headerIssues.length + rows.where((r) => !r.ok).length;
  bool get tooMany => rows.length > AppConfig.catalogMaxItemsPerImport;

  /// All-or-nothing, like the server: import only when every row is valid.
  bool get canImport => rows.isNotEmpty && errorCount == 0 && !tooMany;
}

/// Parses an admin CSV (see docs/templates). Column order does not matter;
/// header names are matched case-insensitively.
CsvImport parseCatalogCsv(CatalogKind kind, String text) => parseCatalogTable(kind, parseCsv(text));

/// Same as [parseCatalogCsv] for rows already read from a CSV or Excel file.
CsvImport parseCatalogTable(CatalogKind kind, List<List<String>> table) {
  if (table.isEmpty) return CsvImport(kind: kind, rows: const []);

  final header = [for (final h in table.first) h.trim().toLowerCase()];
  final col = <String, int>{};
  for (final name in kind.columns) {
    final i = header.indexOf(name.toLowerCase());
    if (i >= 0) col[name] = i;
  }
  final missing = [
    for (final c in kind.requiredColumns)
      if (!col.containsKey(c)) RowIssue(c, IssueKind.missingColumn),
  ];
  if (missing.isNotEmpty) return CsvImport(kind: kind, rows: const [], headerIssues: missing);

  final seen = <String>{};
  final rows = <CsvRow>[];
  for (var r = 1; r < table.length; r++) {
    final cells = table[r];
    String get(String name) {
      final i = col[name];
      return i == null || i >= cells.length ? '' : cells[i].trim();
    }

    final issues = <RowIssue>[];
    bool active = true;
    final rawActive = get('active').toLowerCase();
    if (rawActive.isNotEmpty) {
      if (const ['true', 'yes', 'oo', '1', 'y'].contains(rawActive)) {
        active = true;
      } else if (const ['false', 'no', 'hindi', '0', 'n'].contains(rawActive)) {
        active = false;
      } else {
        issues.add(const RowIssue('active', IssueKind.badBool));
      }
    }

    final CatalogItem item = switch (kind) {
      CatalogKind.commodities => Commodity(
        id: get('id'),
        nameFil: get('nameFil'),
        nameEn: get('nameEn'),
        unit: get('unit').toLowerCase(),
        category: get('category'),
        active: active,
      ),
      CatalogKind.markets => Market(
        id: get('id'),
        name: get('name'),
        municipality: _matchMunicipality(get('municipality')),
        type: get('type').toLowerCase(),
        active: active,
      ),
    };
    issues.addAll(CatalogValidation.item(item));
    if (item.id.isNotEmpty && !seen.add(item.id)) {
      issues.add(const RowIssue('id', IssueKind.duplicate));
    }
    rows.add(CsvRow(line: r + 1, item: item, issues: issues));
  }
  return CsvImport(kind: kind, rows: rows);
}

/// Accepts "bayombong" or "BAYOMBONG" for "Bayombong".
String _matchMunicipality(String v) {
  for (final m in AppConfig.municipalities) {
    if (m.toLowerCase() == v.toLowerCase()) return m;
  }
  return v;
}

/// The template shown in the import dialog (also in docs/templates/).
String csvTemplate(CatalogKind kind) => switch (kind) {
  CatalogKind.commodities =>
    'id,nameFil,nameEn,unit,category,active\n'
        'kamatis,Kamatis,Tomato,kg,Lowland vegetables,true\n'
        'repolyo,Repolyo,Cabbage,kg,Highland vegetables,true\n',
  CatalogKind.markets =>
    'id,name,municipality,type,active\n'
        'bayombong-public-market,Bayombong Public Market,Bayombong,public_market,true\n',
};
