import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../../core/config/app_config.dart';
import '../domain/listing.dart';

class ListingFilter {
  const ListingFilter({this.commodityId, this.municipality});
  final String? commodityId;
  final String? municipality;

  @override
  bool operator ==(Object other) =>
      other is ListingFilter &&
      other.commodityId == commodityId &&
      other.municipality == municipality;
  @override
  int get hashCode => Object.hash(commodityId, municipality);
}

/// Outcome of posting: saved on the server, or queued on the phone until it is online.
enum PostResult { saved, queuedOffline, photosFailed }

abstract class ListingRepository {
  Stream<List<Listing>> watchActive(ListingFilter filter);
  Stream<List<Listing>> watchMine(String uid);
  Stream<Listing?> watchOne(String id);

  Future<PostResult> create({
    required String uid,
    required String farmerName,
    required String farmerPhone,
    required ListingDraft draft,
    required List<Uint8List> photos,
  });

  Future<void> update(String id, Map<String, Object?> changes);
}

class FirebaseListingRepository implements ListingRepository {
  FirebaseListingRepository(this._db, this._storage);
  final FirebaseFirestore _db;
  final FirebaseStorage _storage;

  CollectionReference<Map<String, dynamic>> get _col => _db.collection('listings');

  static DateTime _d(Object? v) =>
      v is Timestamp ? v.toDate() : DateTime.fromMillisecondsSinceEpoch(0);

  static Listing _fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data()!;
    return Listing(
      id: d.id,
      farmerId: m['farmerId'] as String,
      farmerName: (m['farmerName'] as String?) ?? '',
      farmerPhone: (m['farmerPhone'] as String?) ?? '',
      commodityId: m['commodityId'] as String,
      quantity: (m['quantity'] as num).toDouble(),
      unit: (m['unit'] as String?) ?? 'kg',
      askingPrice: (m['askingPrice'] as num).toDouble(),
      municipality: (m['municipality'] as String?) ?? '',
      harvestDate: _d(m['harvestDate']),
      photoUrls: [for (final u in (m['photoUrls'] as List?) ?? const []) '$u'],
      status: ListingStatus.parse(m['status']),
      // Pending offline writes have no server timestamp yet: treat as "now".
      createdAt: m['createdAt'] == null ? DateTime.now() : _d(m['createdAt']),
      expiresAt: _d(m['expiresAt']),
      note: m['note'] as String?,
      moderated: m.containsKey('moderatedAt'),
    );
  }

  @override
  Stream<List<Listing>> watchActive(ListingFilter f) {
    Query<Map<String, dynamic>> q = _col.where('status', isEqualTo: 'active');
    if (f.commodityId != null) q = q.where('commodityId', isEqualTo: f.commodityId);
    if (f.municipality != null) q = q.where('municipality', isEqualTo: f.municipality);
    return q
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map((s) => [for (final d in s.docs) _fromDoc(d)]);
  }

  @override
  Stream<List<Listing>> watchMine(String uid) => _col
      .where('farmerId', isEqualTo: uid)
      .orderBy('createdAt', descending: true)
      .limit(100)
      .snapshots()
      .map((s) => [for (final d in s.docs) _fromDoc(d)]);

  @override
  Stream<Listing?> watchOne(String id) =>
      _col.doc(id).snapshots().map((d) => d.exists ? _fromDoc(d) : null);

  @override
  Future<PostResult> create({
    required String uid,
    required String farmerName,
    required String farmerPhone,
    required ListingDraft draft,
    required List<Uint8List> photos,
  }) async {
    final ref = _col.doc();
    var photosFailed = false;
    final urls = <String>[];
    // Photos need a connection. If they fail, the listing is still posted without them.
    for (var i = 0; i < photos.length && i < AppConfig.listingMaxPhotos; i++) {
      try {
        final p = _storage.ref('listings/$uid/${ref.id}/photo_$i.jpg');
        await p
            .putData(photos[i], SettableMetadata(contentType: 'image/jpeg'))
            .timeout(const Duration(seconds: 30));
        urls.add(await p.getDownloadURL());
      } catch (_) {
        photosFailed = true;
      }
    }
    final write = ref.set({
      'farmerId': uid,
      'farmerName': farmerName,
      'farmerPhone': farmerPhone,
      'commodityId': draft.commodityId,
      'quantity': draft.quantity,
      'unit': draft.unit,
      'askingPrice': draft.askingPrice,
      'municipality': draft.municipality,
      'harvestDate': Timestamp.fromDate(draft.harvestDate!),
      'photoUrls': urls,
      if ((draft.note ?? '').trim().isNotEmpty) 'note': draft.note!.trim(),
      'status': 'active',
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(
        DateTime.now().add(const Duration(days: AppConfig.listingDays)),
      ),
    });
    try {
      // Offline, Firestore keeps the write on the phone and syncs it later.
      await write.timeout(const Duration(seconds: 8));
    } on TimeoutException {
      return PostResult.queuedOffline;
    }
    return photosFailed ? PostResult.photosFailed : PostResult.saved;
  }

  @override
  Future<void> update(String id, Map<String, Object?> changes) =>
      _col.doc(id).update({...changes, 'updatedAt': FieldValue.serverTimestamp()});
}
