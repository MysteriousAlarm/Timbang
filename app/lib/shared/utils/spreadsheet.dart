import 'dart:convert';
import 'dart:typed_data';

import 'package:excel/excel.dart';

import 'csv.dart';

/// Reads a CSV or Excel (.xlsx) file into rows of trimmed text cells.
/// Excel: the first sheet that has data is used; dates become YYYY-MM-DD and whole numbers
/// lose the ".0", so the same parsers work for both formats.
List<List<String>> readSpreadsheet(Uint8List bytes, String fileName) {
  final name = fileName.toLowerCase();
  if (name.endsWith('.xlsx') || name.endsWith('.xlsm')) return _readXlsx(bytes);
  return parseCsv(utf8.decode(bytes, allowMalformed: true));
}

bool isSupportedSpreadsheet(String fileName) {
  final n = fileName.toLowerCase();
  return n.endsWith('.csv') || n.endsWith('.xlsx') || n.endsWith('.xlsm');
}

String _two(int v) => v.toString().padLeft(2, '0');

String cellText(CellValue? v) => switch (v) {
  null => '',
  TextCellValue() => v.value.toString().trim(),
  IntCellValue() => '${v.value}',
  DoubleCellValue() =>
    v.value == v.value.roundToDouble() ? v.value.toStringAsFixed(0) : '${v.value}',
  DateCellValue() => '${v.year}-${_two(v.month)}-${_two(v.day)}',
  DateTimeCellValue() => '${v.year}-${_two(v.month)}-${_two(v.day)}',
  BoolCellValue() => v.value ? 'true' : 'false',
  FormulaCellValue() => '',
  TimeCellValue() => v.toString(),
};

List<List<String>> _readXlsx(Uint8List bytes) {
  final book = Excel.decodeBytes(bytes);
  for (final sheet in book.tables.values) {
    final rows = <List<String>>[];
    for (final r in sheet.rows) {
      final cells = [for (final c in r) cellText(c?.value)];
      while (cells.isNotEmpty && cells.last.isEmpty) {
        cells.removeLast();
      }
      if (cells.any((c) => c.isNotEmpty)) rows.add(cells);
    }
    if (rows.isNotEmpty) return rows;
  }
  return const [];
}
