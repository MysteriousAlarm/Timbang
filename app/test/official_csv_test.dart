import 'package:flutter_test/flutter_test.dart';
import 'package:timbang/features/catalog/domain/catalog_item.dart';
import 'package:timbang/features/catalog/domain/name_index.dart';
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

  group('office sheets', () {
    const commodities = [
      Commodity(id: 'kamatis', nameFil: 'Kamatis', nameEn: 'Tomato', unit: 'kg', category: 'x'),
      Commodity(id: 'repolyo', nameFil: 'Repolyo', nameEn: 'Cabbage', unit: 'kg', category: 'x'),
    ];
    const markets = [
      Market(
        id: 'bpm',
        name: 'Bayombong Public Market',
        municipality: 'Bayombong',
        type: 'public_market',
      ),
      Market(
        id: 'spm',
        name: 'Solano Public Market',
        municipality: 'Solano',
        type: 'public_market',
      ),
      Market(id: 'spm2', name: 'Solano Trading Post', municipality: 'Solano', type: 'trading_post'),
    ];
    final cIds = {for (final x in commodities) x.id};
    final mIds = {for (final x in markets) x.id};
    final cNames = commodityNameIndex(commodities);
    final mNames = marketNameIndex(markets);

    test('long layout with names, title rows and sub-headings', () {
      final r = parseOfficialTable(
        [
          ['PRICE MONITORING REPORT'],
          ['As of November 9, 2026'],
          ['Commodity', 'Market', 'Prevailing Price (P/kg)'],
          ['LOWLAND VEGETABLES', '', ''],
          ['Tomato', 'Bayombong Public Market', '60.00'],
          ['repolyo', 'Bayombong', '₱45.50'],
        ],
        commodityIds: cIds,
        marketIds: mIds,
        commodityNames: cNames,
        marketNames: mNames,
      );
      expect(r.canImport, isTrue, reason: '${r.headerIssues} ${r.rows.map((x) => x.issues)}');
      expect(
        [for (final x in r.rows) x.toPayload()],
        [
          {'commodityId': 'kamatis', 'marketId': 'bpm', 'price': 60.0},
          {'commodityId': 'repolyo', 'marketId': 'bpm', 'price': 45.5},
        ],
      );
      expect(r.rows.first.line, 5);
    });

    test('wide layout: one column per market, blank cells skipped', () {
      final r = parseOfficialTable(
        [
          ['Gulay', 'Bayombong Public Market', 'Solano Public Market', 'Solano Trading Post'],
          ['Kamatis', '60', '', '55'],
          ['Cabbage', '44', '41', ''],
        ],
        commodityIds: cIds,
        marketIds: mIds,
        commodityNames: cNames,
        marketNames: mNames,
      );
      expect(r.canImport, isTrue, reason: '${r.headerIssues} ${r.rows.map((x) => x.issues)}');
      expect(
        [for (final x in r.rows) '${x.commodityId}@${x.marketId}=${x.price}'],
        ['kamatis@bpm=60.0', 'kamatis@spm2=55.0', 'repolyo@bpm=44.0', 'repolyo@spm=41.0'],
      );
    });

    test('a town with two markets is not guessed', () {
      final r = parseOfficialTable(
        [
          ['Commodity', 'Market', 'Price'],
          ['Tomato', 'Solano', '60'],
        ],
        commodityIds: cIds,
        marketIds: mIds,
        commodityNames: cNames,
        marketNames: mNames,
      );
      expect(r.rows.single.issues, ['marketId']);
    });
  });
}
