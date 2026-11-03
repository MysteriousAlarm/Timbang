/// Source tier of a price (CLAUDE.md Section 8). Shown with every price.
enum PriceSource {
  official,
  reporter,
  community;

  static PriceSource parse(Object? v) =>
      PriceSource.values.firstWhere((s) => s.name == v, orElse: () => PriceSource.community);
}

enum ReportStatus {
  valid,
  outlier,
  rejected;

  static ReportStatus parse(Object? v) =>
      ReportStatus.values.firstWhere((s) => s.name == v, orElse: () => ReportStatus.valid);
}

/// price_reports/{id} (read-only on the client; written by Cloud Functions).
class PriceReport {
  const PriceReport({
    required this.id,
    required this.commodityId,
    required this.marketId,
    required this.price,
    required this.unit,
    required this.source,
    required this.status,
    required this.timestamp,
    this.isDemo = false,
    this.sourceNote,
  });

  final String id;
  final String commodityId;
  final String marketId;
  final double price;
  final String unit;
  final PriceSource source;
  final ReportStatus status;
  final DateTime timestamp;
  final bool isDemo;
  final String? sourceNote;
}

/// Accepts "55", "55.5", "₱55.50", "1,250.00". Returns null if not a valid price.
double? parsePrice(String input) {
  final cleaned = input.replaceAll(RegExp(r'[₱Pp\s,]'), '').replaceAll('PHP', '');
  if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(cleaned)) return null;
  final v = double.tryParse(cleaned);
  if (v == null || v < 0.01 || v > 100000) return null;
  return v;
}
