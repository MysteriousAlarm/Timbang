/// Price confidence label (CLAUDE.md Section 8).
enum Confidence {
  high,
  medium,
  low;

  static Confidence? tryParse(Object? value) {
    for (final c in Confidence.values) {
      if (c.name == value) return c;
    }
    return null;
  }
}
