import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timbang/features/catalog/domain/catalog_csv.dart';
import 'package:timbang/features/catalog/domain/catalog_item.dart';
import 'package:timbang/features/reports/domain/official_csv.dart';
import 'package:timbang/shared/utils/spreadsheet.dart';

Uint8List xlsx(List<List<CellValue?>> rows) {
  final book = Excel.createExcel();
  final sheet = book[book.getDefaultSheet()!];
  for (final r in rows) {
    sheet.appendRow(r);
  }
  return Uint8List.fromList(book.encode()!);
}

void main() {
  test('reads an Excel commodity list like a CSV', () {
    final bytes = xlsx([
      [
        TextCellValue('id'),
        TextCellValue('nameFil'),
        TextCellValue('nameEn'),
        TextCellValue('unit'),
        TextCellValue('category'),
      ],
      [
        TextCellValue('kamatis'),
        TextCellValue('Kamatis'),
        TextCellValue('Tomato'),
        TextCellValue('kg'),
        TextCellValue('Lowland vegetables'),
      ],
    ]);
    final r = parseCatalogTable(CatalogKind.commodities, readSpreadsheet(bytes, 'DA list.xlsx'));
    expect(r.canImport, isTrue);
    expect((r.items.single as Commodity).nameEn, 'Tomato');
  });

  test('Excel numbers and dates become plain text for official prices', () {
    final bytes = xlsx([
      [
        TextCellValue('Bilihin'),
        TextCellValue('Palengke'),
        TextCellValue('Presyo'),
        TextCellValue('Petsa'),
      ],
      [
        TextCellValue('kamatis'),
        TextCellValue('bpm'),
        const IntCellValue(60),
        const DateCellValue(year: 2026, month: 11, day: 3),
      ],
      [
        TextCellValue('repolyo'),
        TextCellValue('bpm'),
        const DoubleCellValue(45.5),
        const DateCellValue(year: 2026, month: 11, day: 3),
      ],
    ]);
    final table = readSpreadsheet(bytes, 'nvat.xlsx');
    expect(table[1], ['kamatis', 'bpm', '60', '2026-11-03']);
    final r = parseOfficialTable(table, commodityIds: {'kamatis', 'repolyo'}, marketIds: {'bpm'});
    expect(r.canImport, isTrue);
    expect(r.rows[1].price, 45.5);
  });

  test('CSV files still work and unsupported names are flagged', () {
    final bytes = Uint8List.fromList('id,name\nx,y\n'.codeUnits);
    expect(readSpreadsheet(bytes, 'list.csv'), [
      ['id', 'name'],
      ['x', 'y'],
    ]);
    expect(isSupportedSpreadsheet('a.xlsx'), isTrue);
    expect(isSupportedSpreadsheet('a.pdf'), isFalse);
  });
}
