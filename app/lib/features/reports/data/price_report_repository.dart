import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../domain/official_csv.dart';
import '../domain/price_report.dart';

enum SubmitError { rateLimited, duplicate, notFound, notAllowed, invalid, network, generic }

class SubmitFailure implements Exception {
  const SubmitFailure(this.error, [this.rowErrors = const []]);
  final SubmitError error;
  final List<({int row, String message})> rowErrors;
}

abstract class PriceReportRepository {
  /// Returns the source tier the server assigned.
  Future<PriceSource> submit({
    required String commodityId,
    required String marketId,
    required double price,
  });

  Future<int> importOfficial({required String sourceNote, required List<OfficialRow> rows});

  /// Admin only (rules): latest reports, newest first.
  Stream<List<PriceReport>> watchRecent({int limit = 50});
}

class FirebasePriceReportRepository implements PriceReportRepository {
  FirebasePriceReportRepository(this._db, this._fns);
  final FirebaseFirestore _db;
  final FirebaseFunctions _fns;

  SubmitFailure _map(FirebaseFunctionsException e) {
    final rows = <({int row, String message})>[];
    final d = e.details;
    if (d is Map && d['errors'] is List) {
      for (final x in d['errors'] as List) {
        if (x is Map) rows.add((row: (x['row'] as num).toInt(), message: '${x['message']}'));
      }
    }
    return SubmitFailure(switch (e.code) {
      'resource-exhausted' => SubmitError.rateLimited,
      'already-exists' => SubmitError.duplicate,
      'not-found' => SubmitError.notFound,
      'permission-denied' || 'failed-precondition' => SubmitError.notAllowed,
      'invalid-argument' => SubmitError.invalid,
      'unavailable' || 'deadline-exceeded' => SubmitError.network,
      _ => SubmitError.generic,
    }, rows);
  }

  @override
  Future<PriceSource> submit({
    required String commodityId,
    required String marketId,
    required double price,
  }) async {
    try {
      final res = await _fns.httpsCallable('submitPriceReport').call<Map<String, dynamic>>({
        'commodityId': commodityId,
        'marketId': marketId,
        'price': price,
      });
      return PriceSource.parse(res.data['source']);
    } on FirebaseFunctionsException catch (e) {
      throw _map(e);
    }
  }

  @override
  Future<int> importOfficial({required String sourceNote, required List<OfficialRow> rows}) async {
    try {
      final res = await _fns.httpsCallable('importOfficialPrices').call<Map<String, dynamic>>({
        'sourceNote': sourceNote,
        'rows': [for (final r in rows) r.toPayload()],
      });
      return (res.data['written'] as num).toInt();
    } on FirebaseFunctionsException catch (e) {
      throw _map(e);
    }
  }

  @override
  Stream<List<PriceReport>> watchRecent({int limit = 50}) => _db
      .collection('price_reports')
      .orderBy('timestamp', descending: true)
      .limit(limit)
      .snapshots()
      .map(
        (s) => [
          for (final d in s.docs)
            PriceReport(
              id: d.id,
              commodityId: d['commodityId'] as String,
              marketId: d['marketId'] as String,
              price: (d['price'] as num).toDouble(),
              unit: (d.data()['unit'] as String?) ?? 'kg',
              source: PriceSource.parse(d['source']),
              status: ReportStatus.parse(d['status']),
              timestamp: (d['timestamp'] as Timestamp).toDate(),
              isDemo: d.data()['isDemo'] == true,
              sourceNote: d.data()['sourceNote'] as String?,
            ),
        ],
      );
}

final priceReportRepositoryProvider = Provider<PriceReportRepository>(
  (ref) => FirebasePriceReportRepository(
    FirebaseFirestore.instance,
    FirebaseFunctions.instanceFor(region: AppConfig.functionsRegion),
  ),
);

final recentReportsProvider = StreamProvider<List<PriceReport>>(
  (ref) => ref.watch(priceReportRepositoryProvider).watchRecent(),
);
