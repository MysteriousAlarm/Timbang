import '../../../core/config/app_config.dart';
import '../../../shared/utils/csv.dart';
import '../../../shared/utils/names.dart';
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

/// Parses an admin CSV (see docs/templates). See [parseCatalogTable].
CsvImport parseCatalogCsv(CatalogKind kind, String text) => parseCatalogTable(kind, parseCsv(text));

/// Header aliases (compared with [normKey]) so an office spreadsheet can be imported as it is.
const _aliases = <CatalogKind, Map<String, List<String>>>{
  CatalogKind.commodities: {
    'id': ['id', 'code', 'commodityid'],
    'nameFil': [
      'namefil',
      'filipino',
      'filipinoname',
      'tagalog',
      'localname',
      'pangalan',
      'bilihin',
    ],
    'nameEn': [
      'nameen',
      'english',
      'englishname',
      'commodity',
      'commodityname',
      'vegetable',
      'name',
      'item',
    ],
    'unit': ['unit', 'units', 'yunit', 'uom', 'unitofmeasure', 'per'],
    'category': ['category', 'kategorya', 'group', 'classification', 'uri'],
    'active': ['active', 'status'],
  },
  CatalogKind.markets: {
    'id': ['id', 'code', 'marketid'],
    'name': ['name', 'market', 'marketname', 'palengke'],
    'municipality': ['municipality', 'town', 'bayan', 'lgu', 'city', 'municipalitycity'],
    'type': ['type', 'markettype', 'uri'],
    'active': ['active', 'status'],
  },
};

String _titleCase(String v) => v
    .toLowerCase()
    .split(RegExp(r'\s+'))
    .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
    .join(' ');

/// Unit as offices write it -> app unit.
String _unit(String v) {
  // "per kilo", "kada tali", "1 pc" -> the unit word alone.
  final k = normKey(v).replaceFirst(RegExp('^(per|kada|bawat|isang|1)'), '');
  if (k.isEmpty ||
      const [
        'kg',
        'kgs',
        'kilo',
        'kilos',
        'kilogram',
        'kilograms',
        'perkg',
        'kada kilo',
      ].contains(k)) {
    return 'kg';
  }
  if (const ['bundle', 'bundles', 'tali', 'bugkos', 'perbundle', 'bunch', 'tie'].contains(k)) {
    return 'bundle';
  }
  if (const ['piece', 'pieces', 'pc', 'pcs', 'piraso', 'perpiece', 'head', 'ulo'].contains(k)) {
    return 'piece';
  }
  return v.toLowerCase();
}

String _marketType(String v) {
  final k = normKey(v);
  if (k.isEmpty || k.contains('public') || k == 'publicmarket' || k == 'palengke') {
    return 'public_market';
  }
  if (k.contains('trading') || k.contains('bagsakan')) return 'trading_post';
  if (k.contains('farmgate')) return 'farmgate_area';
  return v.toLowerCase();
}

/// Reads a commodity or market list. Column order and header spelling do not matter
/// (see [_aliases]); title rows above the header are skipped. Only names are needed:
/// - commodities: a Filipino or English name (the other copies it if missing); the ID is
///   made from the name, unit defaults to kg, category to "Vegetables";
/// - markets: name and municipality; the ID is made from the name, type defaults to
///   public market.
/// Rows without any name (blank or sub-heading rows) are skipped.
CsvImport parseCatalogTable(CatalogKind kind, List<List<String>> table) {
  if (table.isEmpty) return CsvImport(kind: kind, rows: const []);
  final aliases = _aliases[kind]!;
  Map<String, int> columns(List<String> keys) => {
    for (final e in aliases.entries)
      if (keys.indexWhere(e.value.contains) >= 0) e.key: keys.indexWhere(e.value.contains),
  };
  final nameCols = kind == CatalogKind.commodities ? ['nameFil', 'nameEn'] : ['name'];
  final h = findHeaderRow(table, (keys) => nameCols.any(columns(keys).containsKey));
  final col = columns([for (final c in table[h]) normKey(c)]);
  // nameEn's aliases include generic "name"/"commodity"; if both point at one column, that is
  // the only name column: use it for both languages.
  final missing = [
    if (!nameCols.any(col.containsKey)) RowIssue(nameCols.first, IssueKind.missingColumn),
    if (kind == CatalogKind.markets && !col.containsKey('municipality'))
      const RowIssue('municipality', IssueKind.missingColumn),
  ];
  if (missing.isNotEmpty) return CsvImport(kind: kind, rows: const [], headerIssues: missing);

  final seen = <String>{};
  final rows = <CsvRow>[];
  var section = '';
  for (var r = h + 1; r < table.length; r++) {
    final cells = table[r];
    String get(String name) {
      final i = col[name];
      return i == null || i >= cells.length ? '' : cells[i].trim();
    }

    if (nameCols.every((n) => get(n).isEmpty)) continue;
    // A heading row ("HIGHLAND VEGETABLES": one cell, no lowercase letters) is not an item;
    // it becomes the category of the rows under it when the sheet has no category column.
    final filled = [
      for (final c in cells)
        if (c.trim().isNotEmpty && !RegExp(r'^\d+\.?$').hasMatch(c.trim())) c.trim(),
    ];
    if (kind == CatalogKind.commodities &&
        filled.length == 1 &&
        !RegExp('[a-z]').hasMatch(filled.single)) {
      section = _titleCase(filled.single);
      continue;
    }
    final issues = <RowIssue>[];
    bool active = true;
    final rawActive = get('active').toLowerCase();
    if (rawActive.isNotEmpty) {
      if (const ['true', 'yes', 'oo', '1', 'y', 'active', 'aktibo'].contains(rawActive)) {
        active = true;
      } else if (const ['false', 'no', 'hindi', '0', 'n', 'inactive'].contains(rawActive)) {
        active = false;
      } else {
        issues.add(const RowIssue('active', IssueKind.badBool));
      }
    }

    final CatalogItem item;
    switch (kind) {
      case CatalogKind.commodities:
        final fil = get('nameFil').isNotEmpty ? get('nameFil') : get('nameEn');
        final en = get('nameEn').isNotEmpty ? get('nameEn') : fil;
        final category = get('category');
        item = Commodity(
          id: get('id').isNotEmpty ? get('id').toLowerCase() : slugify(fil),
          nameFil: fil,
          nameEn: en,
          unit: _unit(get('unit')),
          category: category.isNotEmpty ? category : (section.isNotEmpty ? section : 'Vegetables'),
          active: active,
        );
      case CatalogKind.markets:
        item = Market(
          id: get('id').isNotEmpty ? get('id').toLowerCase() : slugify(get('name')),
          name: get('name'),
          municipality: _matchMunicipality(get('municipality')),
          type: _marketType(get('type')),
          active: active,
        );
    }
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
  final k = normKey(
    v.replaceAll(
      RegExp('municipality of|, *nueva vizcaya|nueva vizcaya', caseSensitive: false),
      '',
    ),
  );
  for (final m in AppConfig.municipalities) {
    if (normKey(m) == k) return m;
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
