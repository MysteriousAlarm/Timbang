import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../shared/models/role.dart';
import '../../profile/domain/user_profile.dart';
import '../../reports/domain/price_report.dart';

class AdminUser {
  const AdminUser({
    required this.profile,
    this.reporterScore,
    this.assignedMarketIds = const [],
    this.createdAt,
  });
  final UserProfile profile;
  final double? reporterScore;
  final List<String> assignedMarketIds;
  final DateTime? createdAt;
}

class AbuseReport {
  const AbuseReport({
    required this.id,
    required this.targetType,
    required this.targetId,
    required this.reason,
    required this.status,
    required this.createdAt,
    this.note,
  });
  final String id;
  final String targetType;
  final String targetId;
  final String reason;
  final String status;
  final DateTime createdAt;
  final String? note;
}

class AuditEntry {
  const AuditEntry({
    required this.id,
    required this.actorId,
    required this.action,
    required this.targetPath,
    required this.detail,
    required this.timestamp,
  });
  final String id;
  final String actorId;
  final String action;
  final String targetPath;
  final String detail;
  final DateTime timestamp;
}

/// Thin client over the admin-only callables and admin-readable collections.
class AdminRepository {
  AdminRepository(this._db, this._fns);
  final FirebaseFirestore _db;
  final FirebaseFunctions _fns;

  Future<Map<String, dynamic>> _call(String name, Map<String, Object?> data) async {
    final res = await _fns.httpsCallable(name).call<Object?>(data);
    final d = res.data;
    return d is Map ? Map<String, dynamic>.from(d) : const {};
  }

  Stream<List<AdminUser>> watchUsers() => _db
      .collection('users')
      .limit(500)
      .snapshots()
      .map(
        (s) => [
          for (final d in s.docs)
            AdminUser(
              profile: UserProfile.fromMap(d.id, d.data()),
              reporterScore: (d.data()['reporterScore'] as num?)?.toDouble(),
              assignedMarketIds: [
                for (final m in (d.data()['assignedMarketIds'] as List?) ?? const []) '$m',
              ],
              createdAt: (d.data()['createdAt'] as Timestamp?)?.toDate(),
            ),
        ]..sort((a, b) => a.profile.name.toLowerCase().compareTo(b.profile.name.toLowerCase())),
      );

  Stream<List<AbuseReport>> watchOpenAbuse() => _db
      .collection('abuse_reports')
      .where('status', isEqualTo: 'open')
      .orderBy('createdAt', descending: true)
      .limit(100)
      .snapshots()
      .map(
        (s) => [
          for (final d in s.docs)
            AbuseReport(
              id: d.id,
              targetType: d['targetType'] as String,
              targetId: d['targetId'] as String,
              reason: d['reason'] as String,
              status: d['status'] as String,
              note: d.data()['note'] as String?,
              createdAt: (d.data()['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
            ),
        ],
      );

  Stream<List<PriceReport>> watchOutliers() => _db
      .collection('price_reports')
      .where('status', isEqualTo: 'outlier')
      .orderBy('timestamp', descending: true)
      .limit(50)
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
              status: ReportStatus.outlier,
              timestamp: (d['timestamp'] as Timestamp).toDate(),
              isDemo: d.data()['isDemo'] == true,
            ),
        ],
      );

  Stream<List<AuditEntry>> watchAudit() => _db
      .collection('audit_logs')
      .orderBy('timestamp', descending: true)
      .limit(100)
      .snapshots()
      .map(
        (s) => [
          for (final d in s.docs)
            AuditEntry(
              id: d.id,
              actorId: (d.data()['actorId'] as String?) ?? '',
              action: (d.data()['action'] as String?) ?? '',
              targetPath: (d.data()['targetPath'] as String?) ?? '',
              detail: (d.data()['detail'] as String?) ?? '',
              timestamp: (d.data()['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
            ),
        ],
      );

  Future<void> setRole(String uid, Role role) =>
      _call('setUserRole', {'uid': uid, 'role': role.name});
  Future<void> setStatus(String uid, AccountStatus s) =>
      _call('setUserStatus', {'uid': uid, 'status': s.name});
  Future<void> setReporterMarkets(String uid, List<String> ids) =>
      _call('setReporterMarkets', {'uid': uid, 'marketIds': ids});
  Future<void> moderateReport(String id, {required bool reject, required String reason}) => _call(
    'moderateReport',
    {'reportId': id, 'action': reject ? 'reject' : 'restore', 'reason': reason},
  );
  Future<void> removeListing(String id, String reason) =>
      _call('moderateListing', {'listingId': id, 'reason': reason});
  Future<void> resolveAbuse(String id, {required bool resolved, String note = ''}) => _call(
    'resolveAbuseReport',
    {'id': id, 'resolution': resolved ? 'resolved' : 'dismissed', 'note': note},
  );
  Future<Map<String, dynamic>> metrics() => _call('getPilotMetrics', {});
  Future<String> simulateSms(String text) async =>
      '${(await _call('simulateSms', {'text': text}))['reply'] ?? ''}';
}

final adminRepositoryProvider = Provider<AdminRepository>(
  (ref) => AdminRepository(
    FirebaseFirestore.instance,
    FirebaseFunctions.instanceFor(region: AppConfig.functionsRegion),
  ),
);

final adminUsersProvider = StreamProvider<List<AdminUser>>(
  (ref) => ref.watch(adminRepositoryProvider).watchUsers(),
);
final openAbuseProvider = StreamProvider<List<AbuseReport>>(
  (ref) => ref.watch(adminRepositoryProvider).watchOpenAbuse(),
);
final outlierReportsProvider = StreamProvider<List<PriceReport>>(
  (ref) => ref.watch(adminRepositoryProvider).watchOutliers(),
);
final auditProvider = StreamProvider<List<AuditEntry>>(
  (ref) => ref.watch(adminRepositoryProvider).watchAudit(),
);
final pilotMetricsProvider = FutureProvider<Map<String, dynamic>>(
  (ref) => ref.watch(adminRepositoryProvider).metrics(),
);
