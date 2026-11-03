import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../auth/application/session.dart';
import '../../reports/data/price_report_repository.dart' show SubmitError, SubmitFailure;
import '../domain/inquiry.dart';

abstract class InquiryRepository {
  Future<void> send({required String listingId, required String message});
  Stream<List<Inquiry>> watchReceived(String uid);
  Stream<List<Inquiry>> watchSent(String uid);
  Future<void> setStatus(String id, InquiryStatus status);
}

class FirebaseInquiryRepository implements InquiryRepository {
  FirebaseInquiryRepository(this._db, this._fns);
  final FirebaseFirestore _db;
  final FirebaseFunctions _fns;

  static Inquiry _from(QueryDocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data();
    return Inquiry(
      id: d.id,
      listingId: m['listingId'] as String,
      farmerId: m['farmerId'] as String,
      buyerId: m['buyerId'] as String,
      buyerName: (m['buyerName'] as String?) ?? '',
      buyerPhone: (m['buyerPhone'] as String?) ?? '',
      commodityId: (m['commodityId'] as String?) ?? '',
      message: (m['message'] as String?) ?? '',
      status: InquiryStatus.parse(m['status']),
      createdAt: (m['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Stream<List<Inquiry>> _watch(String field, String uid) => _db
      .collection('inquiries')
      .where(field, isEqualTo: uid)
      .orderBy('createdAt', descending: true)
      .limit(100)
      .snapshots()
      .map((s) => [for (final d in s.docs) _from(d)]);

  @override
  Stream<List<Inquiry>> watchReceived(String uid) => _watch('farmerId', uid);

  @override
  Stream<List<Inquiry>> watchSent(String uid) => _watch('buyerId', uid);

  @override
  Future<void> send({required String listingId, required String message}) async {
    try {
      await _fns.httpsCallable('sendInquiry').call<Map<String, dynamic>>({
        'listingId': listingId,
        'message': message,
      });
    } on FirebaseFunctionsException catch (e) {
      throw SubmitFailure(switch (e.code) {
        'resource-exhausted' => SubmitError.rateLimited,
        'already-exists' => SubmitError.duplicate,
        'not-found' => SubmitError.notFound,
        'permission-denied' || 'failed-precondition' => SubmitError.notAllowed,
        'invalid-argument' => SubmitError.invalid,
        'unavailable' || 'deadline-exceeded' => SubmitError.network,
        _ => SubmitError.generic,
      });
    }
  }

  @override
  Future<void> setStatus(String id, InquiryStatus status) => _db.doc('inquiries/$id').update({
    'status': status.value,
    'updatedAt': FieldValue.serverTimestamp(),
  });
}

final inquiryRepositoryProvider = Provider<InquiryRepository>(
  (ref) => FirebaseInquiryRepository(
    FirebaseFirestore.instance,
    FirebaseFunctions.instanceFor(region: AppConfig.functionsRegion),
  ),
);

final receivedInquiriesProvider = StreamProvider<List<Inquiry>>((ref) {
  final s = ref.watch(sessionProvider);
  if (s is! SignedIn) return Stream.value(const []);
  return ref.watch(inquiryRepositoryProvider).watchReceived(s.user.uid);
});

final sentInquiriesProvider = StreamProvider<List<Inquiry>>((ref) {
  final s = ref.watch(sessionProvider);
  if (s is! SignedIn) return Stream.value(const []);
  return ref.watch(inquiryRepositoryProvider).watchSent(s.user.uid);
});

/// Unread count for the navigation badge.
final newInquiryCountProvider = Provider<int>(
  (ref) => (ref.watch(receivedInquiriesProvider).value ?? const [])
      .where((i) => i.status == InquiryStatus.newInquiry)
      .length,
);
