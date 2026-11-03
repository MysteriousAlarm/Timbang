import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/board_entry.dart';

abstract class PriceBoardRepository {
  /// Every commodity's board entry at one market.
  Stream<BoardSnapshot> watchMarket(String marketId);

  /// One commodity across all markets (market comparison).
  Stream<BoardSnapshot> watchCommodity(String commodityId);
}

/// Firestore with offline persistence: the last board stays readable without signal.
class FirestorePriceBoardRepository implements PriceBoardRepository {
  FirestorePriceBoardRepository(this._db);
  final FirebaseFirestore _db;

  static DateTime _toDate(Object? v) =>
      v is Timestamp ? v.toDate() : DateTime.fromMillisecondsSinceEpoch(0);

  Stream<BoardSnapshot> _watch(Query<Map<String, dynamic>> q) => q
      .snapshots(includeMetadataChanges: true)
      .map(
        (s) => BoardSnapshot([
          for (final d in s.docs) BoardEntry.fromMap(d.data(), toDate: _toDate),
        ], fromCache: s.metadata.isFromCache),
      );

  @override
  Stream<BoardSnapshot> watchMarket(String marketId) =>
      _watch(_db.collection('price_board').where('marketId', isEqualTo: marketId));

  @override
  Stream<BoardSnapshot> watchCommodity(String commodityId) =>
      _watch(_db.collection('price_board').where('commodityId', isEqualTo: commodityId));
}
