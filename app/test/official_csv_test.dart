import 'package:flutter_test/flutter_test.dart';
import 'package:timbang/features/reports/domain/official_csv.dart';
import 'package:timbang/features/reports/domain/price_report.dart';

void main() {
  const c = {'kamatis', 'repolyo'};
  const m = {'bayombong-public-market'};

  test('parsePrice accepts peso formats, rejects junk', () {
    expect(parsePrice('55'), 55);
    expect(parsePrice('55.5'), 55.5);
    expect(parsePrice('₱ 1,250.00'), 1250);
    expect(parsePrice('P60'), 60);
    expect(parsePrice('0'), isNull);
    expect(parsePrice('1.234'), isNull);
    expect(parsePrice('abc'), isNull);
    expect(parsePrice('200000'), isNull);
  });

  test('template parses cleanly', () {
    final r = parseOfficialCsv(officialCsvTemplate, commodityIds: c, marketIds: m);
    expect(r.canImport, isTrue);
    expect(r.rows.first.toPayload(), {
      'commodityId': 'kamatis',
      'marketId': 'bayombong-public-market',
      'price': 60.0,
      'date': '2026-11-03',
    });
  });

  test('header aliases (Filipino) and optional date', () {
    final r = parseOfficialCsv(
      'Bilihin,Palengke,Presyo\nKAMATIS,bayombong-public-market,₱58\n',
      commodityIds: c,
      marketIds: m,
    );
    expect(r.canImport, isTrue);
    expect(r.rows.single.toPayload().containsKey('date'), isFalse);
  });

  test('unknown ids, bad price and bad date are reported per line', () {
    final r = parseOfficialCsv(
      'commodityId,marketId,price,date\nokra,solano,abc,03/11/2026\n',
      commodityIds: c,
      marketIds: m,
    );
    expect(r.canImport, isFalse);
    expect(r.rows.single.line, 2);
    expect(r.rows.single.issues, ['commodityId', 'marketId', 'price', 'date']);
  });

  test('missing price column is a header issue', () {
    final r = parseOfficialCsv('commodityId,marketId\nkamatis,x\n', commodityIds: c, marketIds: m);
    expect(r.headerIssues, ['price']);
    expect(r.canImport, isFalse);
  });
}
