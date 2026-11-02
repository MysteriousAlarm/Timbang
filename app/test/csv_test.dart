import 'package:flutter_test/flutter_test.dart';
import 'package:timbang/shared/utils/csv.dart';

void main() {
  test('simple rows, LF and CRLF, blank lines skipped', () {
    expect(parseCsv('a,b\n1,2\r\n\n3,4'), [
      ['a', 'b'],
      ['1', '2'],
      ['3', '4'],
    ]);
  });
  test('quoted fields with commas, quotes and newlines', () {
    expect(parseCsv('name,note\n"Sitaw, pula","say ""hi""\nok"\n'), [
      ['name', 'note'],
      ['Sitaw, pula', 'say "hi"\nok'],
    ]);
  });
  test('strips UTF-8 BOM (Excel exports)', () {
    expect(parseCsv('﻿id\nx'), [
      ['id'],
      ['x'],
    ]);
  });
  test('empty trailing fields are kept', () {
    expect(parseCsv('a,b,\n'), [
      ['a', 'b', ''],
    ]);
  });
}
