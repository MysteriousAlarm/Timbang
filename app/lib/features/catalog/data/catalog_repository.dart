import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../domain/catalog_item.dart';

/// Server-side rejection with per-row errors (1-based row numbers in the payload).
class CatalogWriteException implements Exception {
  const CatalogWriteException(this.code, [this.rowErrors = const []]);
  final String code;
  final List<({int row, String message})> rowErrors;
}

abstract class CatalogRepository {
  Stream<List<Commodity>> watchCommodities();
  Stream<List<Market>> watchMarkets();
  Future<int> upsert(CatalogKind kind, List<CatalogItem> items);
  Future<int> clearDemo(CatalogKind kind);
}

class FirebaseCatalogRepository implements CatalogRepository {
  FirebaseCatalogRepository(this._db, this._functions);
  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;

  @override
  Stream<List<Commodity>> watchCommodities() => _db
      .collection('commodities')
      .snapshots()
      .map(
        (s) =>
            [for (final d in s.docs) Commodity.fromMap(d.id, d.data())]
              ..sort((a, b) => a.nameFil.toLowerCase().compareTo(b.nameFil.toLowerCase())),
      );

  @override
  Stream<List<Market>> watchMarkets() => _db
      .collection('markets')
      .snapshots()
      .map(
        (s) =>
            [for (final d in s.docs) Market.fromMap(d.id, d.data())]
              ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())),
      );

  @override
  Future<int> upsert(CatalogKind kind, List<CatalogItem> items) async {
    try {
      final res = await _functions.httpsCallable('upsertCatalog').call<Map<String, dynamic>>({
        'kind': kind.name,
        'items': [for (final i in items) i.toPayload()],
      });
      return (res.data['written'] as num).toInt();
    } on FirebaseFunctionsException catch (e) {
      final details = e.details;
      final rows = <({int row, String message})>[];
      if (details is Map && details['errors'] is List) {
        for (final err in details['errors'] as List) {
          if (err is Map) {
            rows.add((row: (err['row'] as num).toInt(), message: '${err['message']}'));
          }
        }
      }
      throw CatalogWriteException(e.code, rows);
    }
  }

  @override
  Future<int> clearDemo(CatalogKind kind) async {
    final res = await _functions.httpsCallable('clearDemoCatalog').call<Map<String, dynamic>>({
      'kind': kind.name,
    });
    return (res.data['deleted'] as num).toInt();
  }
}
