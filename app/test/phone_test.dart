import 'package:flutter_test/flutter_test.dart';
import 'package:timbang/shared/utils/phone.dart';

void main() {
  group('normalizePhMobile', () {
    for (final input in [
      '09171234567',
      '9171234567',
      '639171234567',
      '+639171234567',
      '0917 123 4567',
      '0917-123-4567',
      '+63 917 123 4567',
    ]) {
      test('accepts "$input"', () => expect(normalizePhMobile(input), '+639171234567'));
    }
    for (final input in ['', '0817123456', '12345', '091712345678', '+1 917 123 4567', 'abc']) {
      test('rejects "$input"', () => expect(normalizePhMobile(input), isNull));
    }
  });

  test('formatPhMobile', () {
    expect(formatPhMobile('+639171234567'), '+63 917 123 4567');
  });
}
