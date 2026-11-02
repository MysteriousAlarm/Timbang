import '../../../core/config/app_config.dart';
import 'catalog_item.dart';

/// What is wrong with a field. Rendered as text by the admin UI.
enum IssueKind { missing, tooLong, tooShort, badId, notAllowed, badBool, duplicate, missingColumn }

class RowIssue {
  const RowIssue(this.field, this.kind);
  final String field;
  final IssueKind kind;

  @override
  bool operator ==(Object other) => other is RowIssue && other.field == field && other.kind == kind;
  @override
  int get hashCode => Object.hash(field, kind);
  @override
  String toString() => '$field:$kind';
}

/// Mirrors functions/src/catalog.ts. The function re-validates; this gives instant feedback.
abstract final class CatalogValidation {
  static List<RowIssue> commodity(Commodity c) => [
    ..._id(c.id),
    ..._text('nameFil', c.nameFil, 1, 60),
    ..._text('nameEn', c.nameEn, 1, 60),
    if (!AppConfig.units.contains(c.unit)) const RowIssue('unit', IssueKind.notAllowed),
    ..._text('category', c.category, 1, 40),
  ];

  static List<RowIssue> market(Market m) => [
    ..._id(m.id),
    ..._text('name', m.name, 2, 80),
    if (!AppConfig.municipalities.contains(m.municipality))
      const RowIssue('municipality', IssueKind.notAllowed),
    if (!AppConfig.marketTypes.contains(m.type)) const RowIssue('type', IssueKind.notAllowed),
  ];

  static List<RowIssue> item(CatalogItem i) => switch (i) {
    Commodity() => commodity(i),
    Market() => market(i),
  };

  static List<RowIssue> _id(String id) => [
    if (id.isEmpty)
      const RowIssue('id', IssueKind.missing)
    else if (!validCatalogId(id))
      const RowIssue('id', IssueKind.badId),
  ];

  static List<RowIssue> _text(String field, String v, int min, int max) {
    final t = v.trim();
    if (t.isEmpty && min > 0) return [RowIssue(field, IssueKind.missing)];
    if (t.length < min) return [RowIssue(field, IssueKind.tooShort)];
    if (t.length > max) return [RowIssue(field, IssueKind.tooLong)];
    return const [];
  }
}
