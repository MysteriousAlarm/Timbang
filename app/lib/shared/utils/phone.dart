/// Normalizes a Philippine mobile number to E.164 (+639XXXXXXXXX).
/// Accepts 09XXXXXXXXX, 9XXXXXXXXX, 639XXXXXXXXX, +639XXXXXXXXX, with spaces or dashes.
/// Returns null if it is not a valid PH mobile number.
String? normalizePhMobile(String input) {
  final digits = input.replaceAll(RegExp(r'[\s\-().]'), '');
  final match = RegExp(r'^(?:\+?63|0)?(9\d{9})$').firstMatch(digits);
  if (match == null) return null;
  return '+63${match.group(1)}';
}

/// Display form: +63 917 123 4567
String formatPhMobile(String e164) {
  final m = RegExp(r'^\+63(\d{3})(\d{3})(\d{4})$').firstMatch(e164);
  if (m == null) return e164;
  return '+63 ${m.group(1)} ${m.group(2)} ${m.group(3)}';
}
