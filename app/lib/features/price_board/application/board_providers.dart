import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/session.dart';
import '../../catalog/data/catalog_providers.dart';
import '../../catalog/domain/catalog_item.dart';
import '../data/price_board_repository.dart';
import '../domain/board_entry.dart';
import 'price_scope.dart';

export 'price_scope.dart';

final priceBoardRepositoryProvider = Provider<PriceBoardRepository>(
  (ref) => FirestorePriceBoardRepository(FirebaseFirestore.instance),
);

/// Ticks every minute so "updated X ago" and stale labels stay current.
final clockProvider = StreamProvider<DateTime>((ref) async* {
  yield DateTime.now();
  yield* Stream.periodic(const Duration(minutes: 1), (_) => DateTime.now());
});

/// Market chosen on the price board. null = default (first market in the user's town).
class SelectedMarket extends Notifier<String?> {
  @override
  String? build() => null;
  void select(String id) => state = id;
  void clear() => state = null;
}

final selectedMarketIdProvider = NotifierProvider<SelectedMarket, String?>(SelectedMarket.new);

/// Active markets, the user's own town first.
final orderedMarketsProvider = Provider<List<Market>>((ref) {
  final session = ref.watch(sessionProvider);
  final town = session is SignedIn ? session.profile.municipality : null;
  final markets = (ref.watch(marketsProvider).value ?? const <Market>[])
      .where((m) => m.active)
      .toList();
  markets.sort((a, b) {
    final at = a.municipality == town ? 0 : 1;
    final bt = b.municipality == town ? 0 : 1;
    return at != bt ? at - bt : a.name.compareTo(b.name);
  });
  return markets;
});

/// Active markets in the chosen municipality (all active markets for the province view).
final scopedMarketsProvider = Provider<List<Market>>((ref) {
  final scope = ref.watch(priceScopeProvider);
  final markets = ref.watch(orderedMarketsProvider);
  return scope == null ? markets : markets.where((m) => m.municipality == scope).toList();
});

/// The market used for single-market views: inside the chosen municipality when one is
/// chosen, otherwise the user's own town first.
final activeMarketProvider = Provider<Market?>((ref) {
  final scoped = ref.watch(scopedMarketsProvider);
  final markets = ref.watch(priceScopeProvider) == null || scoped.isEmpty
      ? ref.watch(orderedMarketsProvider)
      : scoped;
  if (markets.isEmpty) return null;
  final chosen = ref.watch(selectedMarketIdProvider);
  return markets.firstWhere((m) => m.id == chosen, orElse: () => markets.first);
});

final marketBoardProvider = StreamProvider.family<BoardSnapshot, String>(
  (ref, marketId) => ref.watch(priceBoardRepositoryProvider).watchMarket(marketId),
);

final provinceBoardProvider = StreamProvider<BoardSnapshot>(
  (ref) => ref.watch(priceBoardRepositoryProvider).watchAll(),
);

final commodityBoardProvider = StreamProvider.family<BoardSnapshot, String>(
  (ref, commodityId) => ref.watch(priceBoardRepositoryProvider).watchCommodity(commodityId),
);

/// A board row joined with its commodity, sorted by Filipino name. Inactive commodities hidden.
typedef BoardRow = ({BoardEntry entry, Commodity commodity});

List<BoardRow> joinRows(List<BoardEntry> entries, List<Commodity> commodities) {
  final byId = {for (final c in commodities) c.id: c};
  final rows = <BoardRow>[
    for (final e in entries)
      if (byId[e.commodityId]?.active ?? false) (entry: e, commodity: byId[e.commodityId]!),
  ];
  rows.sort(
    (a, b) => a.commodity.nameFil.toLowerCase().compareTo(b.commodity.nameFil.toLowerCase()),
  );
  return rows;
}

/// Market comparison: the commodity at every active market, user's town first, then cheapest.
typedef ComparisonRow = ({BoardEntry entry, Market market, bool ownTown});

List<ComparisonRow> compareRows(List<BoardEntry> entries, List<Market> markets, String? town) {
  final byId = {for (final m in markets) m.id: m};
  final rows = <ComparisonRow>[
    for (final e in entries)
      if (byId[e.marketId]?.active ?? false)
        (entry: e, market: byId[e.marketId]!, ownTown: byId[e.marketId]!.municipality == town),
  ];
  rows.sort((a, b) {
    if (a.ownTown != b.ownTown) return a.ownTown ? -1 : 1;
    return a.entry.medianPrice.compareTo(b.entry.medianPrice);
  });
  return rows;
}

/// Province-wide row: one commodity summarised across the markets that have a price.
typedef ProvinceRow = ({
  Commodity commodity,
  BoardEntry entry,
  int markets,
  double low,
  double high,
});

double _median(List<double> v) {
  final s = [...v]..sort();
  final n = s.length;
  return n.isOdd ? s[n ~/ 2] : (s[n ~/ 2 - 1] + s[n ~/ 2]) / 2;
}

/// Summarises each commodity across active markets:
/// - price: the median of the markets' medians (one market cannot pull it alone);
/// - confidence: the LOWEST among those markets (never overstates trust);
/// - age: the newest report; counts and source tiers: summed;
/// - change: median of today vs median of yesterday where known (±3% = steady).
/// Only entries in the commodity's most common unit are combined, so kg and bundle never mix.
List<ProvinceRow> provinceRows(
  List<BoardEntry> entries,
  List<Commodity> commodities,
  List<Market> markets,
) {
  final activeMarkets = {
    for (final m in markets)
      if (m.active) m.id,
  };
  final byCommodity = <String, List<BoardEntry>>{};
  for (final e in entries) {
    if (activeMarkets.contains(e.marketId)) {
      byCommodity.putIfAbsent(e.commodityId, () => []).add(e);
    }
  }
  final rows = <ProvinceRow>[];
  for (final c in commodities.where((c) => c.active)) {
    final list = byCommodity[c.id];
    if (list == null || list.isEmpty) continue;
    final unitCount = <String, int>{};
    for (final e in list) {
      unitCount[e.unit] = (unitCount[e.unit] ?? 0) + 1;
    }
    final unit = unitCount.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    final same = list.where((e) => e.unit == unit).toList();
    final prices = [for (final e in same) e.medianPrice];
    final median = _median(prices);
    final prevs = [for (final e in same) ?e.previousMedian];
    final prev = prevs.isEmpty ? null : _median(prevs);
    final trend = prev == null || prev == 0
        ? Trend.flat
        : (median - prev) / prev > 0.03
        ? Trend.up
        : (median - prev) / prev < -0.03
        ? Trend.down
        : Trend.flat;
    final lowest = same.map((e) => e.confidence).reduce((a, b) => a.index >= b.index ? a : b);
    rows.add((
      commodity: c,
      markets: same.length,
      low: prices.reduce((a, b) => a < b ? a : b),
      high: prices.reduce((a, b) => a > b ? a : b),
      entry: BoardEntry(
        commodityId: c.id,
        marketId: '',
        unit: unit,
        medianPrice: median,
        confidence: lowest,
        reportCount: same.fold(0, (n, e) => n + e.reportCount),
        trend: trend,
        latestReportAt: same.map((e) => e.latestReportAt).reduce((a, b) => a.isAfter(b) ? a : b),
        previousMedian: prev,
        official: same.fold(0, (n, e) => n + e.official),
        reporter: same.fold(0, (n, e) => n + e.reporter),
        community: same.fold(0, (n, e) => n + e.community),
        isDemo: same.any((e) => e.isDemo),
      ),
    ));
  }
  rows.sort(
    (a, b) => a.commodity.nameFil.toLowerCase().compareTo(b.commodity.nameFil.toLowerCase()),
  );
  return rows;
}
