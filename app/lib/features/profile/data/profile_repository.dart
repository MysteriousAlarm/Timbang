import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../domain/user_profile.dart';

abstract class ProfileRepository {
  Stream<UserProfile?> watch(String uid);
  Future<void> create(String uid, NewProfile profile);
  Future<void> update(String uid, {required String name, required String municipality});

  /// RA 10173 erasure, via the `deleteMyAccount` Cloud Function.
  Future<void> deleteMyAccount();
}

class FirestoreProfileRepository implements ProfileRepository {
  FirestoreProfileRepository(this._db, this._functions);
  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;

  DocumentReference<Map<String, dynamic>> _doc(String uid) => _db.collection('users').doc(uid);

  @override
  Stream<UserProfile?> watch(String uid) =>
      _doc(uid).snapshots().map((s) => s.exists ? UserProfile.fromMap(uid, s.data()!) : null);

  @override
  Future<void> create(String uid, NewProfile p) => _doc(uid).set({
    'name': p.name.trim(),
    'phone': p.phone,
    'municipality': p.municipality,
    'role': p.role.name,
    'verified': false,
    'status': 'active',
    'createdAt': FieldValue.serverTimestamp(),
    'consentAt': FieldValue.serverTimestamp(),
  });

  @override
  Future<void> update(String uid, {required String name, required String municipality}) => _doc(uid)
      .update({
        'name': name.trim(),
        'municipality': municipality,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  @override
  Future<void> deleteMyAccount() async {
    await _functions.httpsCallable('deleteMyAccount').call<Map<String, dynamic>>({});
  }
}
