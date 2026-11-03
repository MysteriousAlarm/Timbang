import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/session.dart';
import '../../catalog/data/catalog_providers.dart';
import '../../catalog/domain/catalog_item.dart';
import '../data/price_board_repository.dart';
import '../domain/board_entry.dart';

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

final activeMarketProvider = Provider<Market?>((ref) {
  final markets = ref.watch(orderedMarketsProvider);
  if (markets.isEmpty) return null;
  final chosen = ref.watch(selectedMarketIdProvider);
  return markets.firstWhere((m) => m.id == chosen, orElse: () => markets.first);
});

final marketBoardProvider = StreamProvider.family<BoardSnapshot, String>(
  (ref, marketId) => ref.watch(priceBoardRepositoryProvider).watchMarket(marketId),
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
