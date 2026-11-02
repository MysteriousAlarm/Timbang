import 'package:flutter_test/flutter_test.dart';
import 'package:timbang/features/catalog/domain/catalog_csv.dart';
import 'package:timbang/features/catalog/domain/catalog_item.dart';
import 'package:timbang/features/catalog/domain/catalog_validation.dart';

void main() {
  test('templates parse cleanly for both kinds', () {
    for (final kind in CatalogKind.values) {
      final r = parseCatalogCsv(kind, csvTemplate(kind));
      expect(r.canImport, isTrue, reason: kind.name);
      expect(r.errorCount, 0);
    }
  });

  test('commodities: column order and case do not matter; active defaults true', () {
    final r = parseCatalogCsv(
      CatalogKind.commodities,
      'UNIT,id,NameFil,nameen,category\nKG,kamatis,Kamatis,Tomato,Lowland vegetables\n',
    );
    expect(r.canImport, isTrue);
    final c = r.items.single as Commodity;
    expect(c.unit, 'kg');
    expect(c.active, isTrue);
    expect(c.toPayload(), {
      'id': 'kamatis',
      'nameFil': 'Kamatis',
      'nameEn': 'Tomato',
      'unit': 'kg',
      'category': 'Lowland vegetables',
      'active': true,
    });
  });

  test('missing required column is a header error', () {
    final r = parseCatalogCsv(CatalogKind.commodities, 'id,nameFil\nkamatis,Kamatis\n');
    expect(r.canImport, isFalse);
    expect(r.headerIssues, contains(const RowIssue('unit', IssueKind.missingColumn)));
  });

  test('row errors carry line numbers; one bad row blocks the import', () {
    final r = parseCatalogCsv(
      CatalogKind.markets,
      'id,name,municipality,type,active\n'
      'bayombong-pm,Bayombong Public Market,bayombong,public_market,oo\n'
      'Bad ID,X,Makati,mall,maybe\n'
      'bayombong-pm,Copy,Solano,public_market,\n',
    );
    expect(r.canImport, isFalse);
    expect(r.rows[0].ok, isTrue);
    expect((r.rows[0].item! as Market).municipality, 'Bayombong');
    expect(r.rows[1].line, 3);
    expect(
      r.rows[1].issues,
      containsAll(const [
        RowIssue('id', IssueKind.badId),
        RowIssue('name', IssueKind.tooShort),
        RowIssue('municipality', IssueKind.notAllowed),
        RowIssue('type', IssueKind.notAllowed),
        RowIssue('active', IssueKind.badBool),
      ]),
    );
    expect(r.rows[2].issues, contains(const RowIssue('id', IssueKind.duplicate)));
  });

  test('active accepts true/false, yes/no, oo/hindi, 1/0', () {
    final r = parseCatalogCsv(
      CatalogKind.markets,
      'id,name,municipality,type,active\n'
      'a1,Market A,Solano,public_market,hindi\n'
      'a2,Market B,Solano,public_market,1\n',
    );
    expect(r.items.map((i) => i.active), [false, true]);
  });

  test('slugify makes valid ids', () {
    expect(slugify('Kamatis (Pula)'), 'kamatis-pula');
    expect(slugify('Alfonso Castañeda Market'), 'alfonso-castaneda-market');
    expect(validCatalogId(slugify('NVAT Trading Post, Bambang')), isTrue);
  });
}
