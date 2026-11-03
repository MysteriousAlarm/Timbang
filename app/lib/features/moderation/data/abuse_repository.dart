import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const abuseReasons = ['wrong_price', 'scam', 'spam', 'offensive', 'other'];

abstract class AbuseRepository {
  Future<void> flag({
    required String uid,
    required String targetType,
    required String targetId,
    required String reason,
    String? note,
  });
}

class FirestoreAbuseRepository implements AbuseRepository {
  FirestoreAbuseRepository(this._db);
  final FirebaseFirestore _db;

  @override
  Future<void> flag({
    required String uid,
    required String targetType,
    required String targetId,
    required String reason,
    String? note,
  }) => _db.collection('abuse_reports').add({
    'targetType': targetType,
    'targetId': targetId,
    'reporterId': uid,
    'reason': reason,
    if ((note ?? '').trim().isNotEmpty) 'note': note!.trim(),
    'status': 'open',
    'createdAt': FieldValue.serverTimestamp(),
  });
}

final abuseRepositoryProvider = Provider<AbuseRepository>(
  (ref) => FirestoreAbuseRepository(FirebaseFirestore.instance),
);
