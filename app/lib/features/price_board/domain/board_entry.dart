import '../../../core/config/app_config.dart';
import '../../../shared/models/confidence.dart';

enum Trend {
  up,
  down,
  flat;

  static Trend parse(Object? v) =>
      Trend.values.firstWhere((t) => t.name == v, orElse: () => Trend.flat);
}

/// price_board/{commodityId}_{marketId}, written only by Cloud Functions.
class BoardEntry {
  const BoardEntry({
    required this.commodityId,
    required this.marketId,
    required this.unit,
    required this.medianPrice,
    required this.confidence,
    required this.reportCount,
    required this.trend,
    required this.latestReportAt,
    this.previousMedian,
    this.official = 0,
    this.reporter = 0,
    this.community = 0,
    this.isDemo = false,
  });

  final String commodityId;
  final String marketId;
  final String unit;
  final double medianPrice;
  final Confidence confidence;
  final int reportCount;
  final Trend trend;
  final double? previousMedian;
  final DateTime latestReportAt;
  final int official;
  final int reporter;
  final int community;
  final bool isDemo;

  /// No reports in the last 24 hours: keep showing, clearly marked with its age.
  bool isStale(DateTime now) => now.difference(latestReportAt) > AppConfig.priceWindow;

  factory BoardEntry.fromMap(Map<String, dynamic> m, {required DateTime Function(Object?) toDate}) {
    final sources = (m['sources'] as Map?) ?? const {};
    int n(Object? v) => (v as num?)?.toInt() ?? 0;
    return BoardEntry(
      commodityId: m['commodityId'] as String,
      marketId: m['marketId'] as String,
      unit: (m['unit'] as String?) ?? 'kg',
      medianPrice: (m['medianPrice'] as num).toDouble(),
      confidence: Confidence.tryParse(m['confidence']) ?? Confidence.low,
      reportCount: n(m['reportCount']),
      trend: Trend.parse(m['trend']),
      previousMedian: (m['previousMedian'] as num?)?.toDouble(),
      latestReportAt: toDate(m['latestReportAt']),
      official: n(sources['official']),
      reporter: n(sources['reporter']),
      community: n(sources['community']),
      isDemo: m['isDemo'] == true,
    );
  }
}

/// A list of board entries plus whether it came from the offline cache.
class BoardSnapshot {
  const BoardSnapshot(this.entries, {this.fromCache = false});
  final List<BoardEntry> entries;
  final bool fromCache;
  bool get hasDemo => entries.any((e) => e.isDemo);
}

/// "₱64.00"
String peso(double v) {
  final fixed = v.toStringAsFixed(2);
  final parts = fixed.split('.');
  final whole = parts[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  return '₱$whole.${parts[1]}';
}
