import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timbang/core/theme/forest_gold_theme.dart';
import 'package:timbang/core/theme/harvest_earth_theme.dart';
import 'package:timbang/features/admin/data/admin_repository.dart';
import 'package:timbang/features/admin/presentation/moderation_page.dart';
import 'package:timbang/features/admin/presentation/users_page.dart';
import 'package:timbang/features/auth/data/auth_repository.dart';
import 'package:timbang/features/catalog/data/catalog_providers.dart';
import 'package:timbang/features/catalog/domain/catalog_item.dart';
import 'package:timbang/features/moderation/data/abuse_repository.dart';
import 'package:timbang/features/moderation/presentation/flag_sheet.dart';
import 'package:timbang/features/profile/domain/user_profile.dart';
import 'package:timbang/features/reports/domain/price_report.dart';
import 'package:timbang/shared/models/role.dart';

import 'fakes.dart';

class FakeAdmin implements AdminRepository {
  final calls = <String>[];
  @override
  Future<void> setRole(String uid, Role role) async => calls.add('role:$uid:${role.name}');
  @override
  Future<void> setStatus(String uid, AccountStatus s) async => calls.add('status:$uid:${s.name}');
  @override
  Future<void> setReporterMarkets(String uid, List<String> ids) async =>
      calls.add('markets:$uid:${ids.join(',')}');
  @override
  Future<void> moderateReport(String id, {required bool reject, required String reason}) async =>
      calls.add('report:$id:$reject:$reason');
  @override
  Future<void> removeListing(String id, String reason) async => calls.add('remove:$id');
  @override
  Future<void> resolveAbuse(String id, {required bool resolved, String note = ''}) async =>
      calls.add('abuse:$id:$resolved');
  @override
  Future<Map<String, dynamic>> metrics() async => {};
  @override
  Stream<List<AdminUser>> watchUsers() => const Stream.empty();
  @override
  Stream<List<AbuseReport>> watchOpenAbuse() => const Stream.empty();
  @override
  Stream<List<PriceReport>> watchOutliers() => const Stream.empty();
  @override
  Stream<List<AuditEntry>> watchAudit() => const Stream.empty();
}

class FakeAbuse implements AbuseRepository {
  (String, String, String)? last;
  @override
  Future<void> flag({
    required String uid,
    required String targetType,
    required String targetId,
    required String reason,
    String? note,
  }) async => last = (targetType, targetId, reason);
}

UserProfile up(String uid, String name, Role role, {AccountStatus status = AccountStatus.active}) =>
    UserProfile(
      uid: uid,
      name: name,
      phone: '+639171234567',
      municipality: 'Solano',
      role: role,
      verified: role == Role.reporter,
      status: status,
    );

void main() {
  late FakeAdmin admin;
  late FakeAuthRepository auth;
  late FakeProfileRepository profiles;

  setUp(() {
    admin = FakeAdmin();
    auth = FakeAuthRepository()
      ..signIn(const AuthUser(uid: 'me', phone: '+639170000000'))
      ..claim = Role.admin;
    profiles = FakeProfileRepository()..current = up('me', 'Admin Ako', Role.admin);
  });

  Future<void> pump(
    WidgetTester tester,
    Widget w, {
    ThemeData? theme,
    List<AdminUser> users = const [],
    List<AbuseReport> abuse = const [],
    List<PriceReport> outliers = const [],
  }) async {
    tester.view.physicalSize = const Size(1400, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      harness(
        Scaffold(body: w),
        theme: theme ?? forestGoldTheme,
        overrides: [
          ...fakeOverrides(auth, profiles),
          adminRepositoryProvider.overrideWithValue(admin),
          adminUsersProvider.overrideWith((ref) => Stream.value(users)),
          openAbuseProvider.overrideWith((ref) => Stream.value(abuse)),
          outlierReportsProvider.overrideWith((ref) => Stream.value(outliers)),
          commoditiesProvider.overrideWith(
            (ref) => Stream.value(const [
              Commodity(
                id: 'kamatis',
                nameFil: 'Kamatis',
                nameEn: 'Tomato',
                unit: 'kg',
                category: 'x',
              ),
            ]),
          ),
          marketsProvider.overrideWith(
            (ref) => Stream.value(const [
              Market(
                id: 'bpm',
                name: 'Bayombong PM',
                municipality: 'Bayombong',
                type: 'public_market',
              ),
            ]),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('promote a farmer to reporter; suspend; cannot act on yourself', (tester) async {
    await pump(
      tester,
      const AdminUsersPage(),
      users: [
        AdminUser(profile: up('u1', 'Maria Santos', Role.farmer)),
        AdminUser(profile: up('me', 'Admin Ako', Role.admin)),
      ],
    );
    expect(find.text('Maria Santos'), findsOneWidget);
    expect(find.text('Ikaw ito'), findsOneWidget);
    await tester.tap(find.text('Palitan ang papel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tagapag-ulat ng presyo').last);
    await tester.pumpAndSettle();
    expect(admin.calls, contains('role:u1:reporter'));
    await tester.tap(find.text('I-suspend'));
    await tester.pumpAndSettle();
    expect(admin.calls, contains('status:u1:suspended'));
  });

  testWidgets('reporters get market assignment', (tester) async {
    await pump(
      tester,
      const AdminUsersPage(),
      users: [AdminUser(profile: up('r1', 'Rey Reporter', Role.reporter))],
    );
    expect(find.text('Kahit anong palengke'), findsOneWidget);
    await tester.tap(find.text('Mga palengke'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bayombong PM'));
    await tester.tap(find.text('I-save'));
    await tester.pumpAndSettle();
    expect(admin.calls, contains('markets:r1:bpm'));
  });

  testWidgets('moderation: remove a flagged listing with a reason, reject an outlier', (
    tester,
  ) async {
    await pump(
      tester,
      const AdminModerationPage(),
      abuse: [
        AbuseReport(
          id: 'a1',
          targetType: 'listing',
          targetId: 'L1',
          reason: 'scam',
          status: 'open',
          createdAt: DateTime(2026, 11, 3),
        ),
      ],
      outliers: [
        PriceReport(
          id: 'r1',
          commodityId: 'kamatis',
          marketId: 'bpm',
          price: 200,
          unit: 'kg',
          source: PriceSource.community,
          status: ReportStatus.outlier,
          timestamp: DateTime(2026, 11, 3),
        ),
      ],
    );
    expect(find.text('Panloloko o scam'), findsOneWidget);
    await tester.tap(find.text('Alisin ang listing'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Pekeng listing');
    await tester.tap(find.text('Kumpirmahin'));
    await tester.pumpAndSettle();
    expect(admin.calls, containsAll(['remove:L1', 'abuse:a1:true']));

    expect(find.text('Kamatis · Bayombong PM'), findsOneWidget);
    await tester.tap(find.text('Tanggihan'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Malayo sa median');
    await tester.tap(find.text('Kumpirmahin'));
    await tester.pumpAndSettle();
    expect(admin.calls, contains('report:r1:true:Malayo sa median'));
  });

  testWidgets('users can flag a listing', (tester) async {
    final abuse = FakeAbuse();
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      harness(
        const Scaffold(
          body: FlagButton(targetType: 'listing', targetId: 'L9', label: 'I-report'),
        ),
        theme: harvestEarthTheme,
        overrides: [
          ...fakeOverrides(auth, profiles),
          abuseRepositoryProvider.overrideWithValue(abuse),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('flagButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('reason_spam')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('flagSend')));
    await tester.pumpAndSettle();
    expect(abuse.last, ('listing', 'L9', 'spam'));
  });
}
