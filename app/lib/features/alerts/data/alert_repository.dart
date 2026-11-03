import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/session.dart';
import '../domain/price_alert.dart';

abstract class AlertRepository {
  Stream<List<PriceAlert>> watchMine(String uid);
  Future<void> create({
    required String uid,
    required String commodityId,
    required String marketId,
    required double threshold,
    required AlertDirection direction,
  });
  Future<void> setActive(String id, bool active);
  Future<void> delete(String id);
}

class FirestoreAlertRepository implements AlertRepository {
  FirestoreAlertRepository(this._db);
  final FirebaseFirestore _db;

  @override
  Stream<List<PriceAlert>> watchMine(String uid) => _db
      .collection('alerts')
      .where('userId', isEqualTo: uid)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map(
        (s) => [
          for (final d in s.docs)
            PriceAlert(
              id: d.id,
              commodityId: d['commodityId'] as String,
              marketId: d['marketId'] as String,
              threshold: (d['threshold'] as num).toDouble(),
              direction: d['direction'] == 'below' ? AlertDirection.below : AlertDirection.above,
              active: d['active'] == true,
              lastTriggeredAt: (d.data()['lastTriggeredAt'] as Timestamp?)?.toDate(),
              lastTriggeredMedian: (d.data()['lastTriggeredMedian'] as num?)?.toDouble(),
            ),
        ],
      );

  @override
  Future<void> create({
    required String uid,
    required String commodityId,
    required String marketId,
    required double threshold,
    required AlertDirection direction,
  }) => _db.collection('alerts').add({
    'userId': uid,
    'commodityId': commodityId,
    'marketId': marketId,
    'threshold': threshold,
    'direction': direction.name,
    'active': true,
    'createdAt': FieldValue.serverTimestamp(),
  });

  @override
  Future<void> setActive(String id, bool active) =>
      _db.doc('alerts/$id').update({'active': active, 'updatedAt': FieldValue.serverTimestamp()});

  @override
  Future<void> delete(String id) => _db.doc('alerts/$id').delete();
}

final alertRepositoryProvider = Provider<AlertRepository>(
  (ref) => FirestoreAlertRepository(FirebaseFirestore.instance),
);

final myAlertsProvider = StreamProvider<List<PriceAlert>>((ref) {
  final s = ref.watch(sessionProvider);
  if (s is! SignedIn) return Stream.value(const []);
  return ref.watch(alertRepositoryProvider).watchMine(s.user.uid);
});
