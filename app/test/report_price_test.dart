import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timbang/core/theme/harvest_earth_theme.dart';
import 'package:timbang/features/auth/data/auth_repository.dart';
import 'package:timbang/features/catalog/data/catalog_providers.dart';
import 'package:timbang/features/catalog/domain/catalog_item.dart';
import 'package:timbang/features/profile/domain/user_profile.dart';
import 'package:timbang/features/reports/data/price_report_repository.dart';
import 'package:timbang/features/reports/domain/official_csv.dart';
import 'package:timbang/features/reports/domain/price_report.dart';
import 'package:timbang/features/reports/presentation/report_price_screen.dart';
import 'package:timbang/shared/models/role.dart';

import 'fakes.dart';

class FakeReports implements PriceReportRepository {
  final sent = <(String, String, double)>[];
  SubmitFailure? fail;
  PriceSource answer = PriceSource.community;

  @override
  Future<PriceSource> submit({
    required String commodityId,
    required String marketId,
    required double price,
  }) async {
    if (fail != null) throw fail!;
    sent.add((commodityId, marketId, price));
    return answer;
  }

  @override
  Future<int> importOfficial({required String sourceNote, required List<OfficialRow> rows}) async =>
      0;

  @override
  Stream<List<PriceReport>> watchRecent({int limit = 50}) => const Stream.empty();
}

void main() {
  late FakeAuthRepository auth;
  late FakeProfileRepository profiles;
  late FakeReports reports;

  setUp(() {
    auth = FakeAuthRepository()..signIn(const AuthUser(uid: 'u1', phone: '+639171234567'));
    profiles = FakeProfileRepository()
      ..current = const UserProfile(
        uid: 'u1',
        name: 'Juan',
        phone: '+639171234567',
        municipality: 'Bayombong',
        role: Role.farmer,
        verified: false,
        status: AccountStatus.active,
      );
    reports = FakeReports();
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      harness(
        const ReportPriceScreen(),
        theme: harvestEarthTheme,
        overrides: [
          ...fakeOverrides(auth, profiles),
          priceReportRepositoryProvider.overrideWithValue(reports),
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
                id: 'solano-pm',
                name: 'Solano Public Market',
                municipality: 'Solano',
                type: 'public_market',
              ),
              Market(
                id: 'bayombong-pm',
                name: 'Bayombong Public Market',
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

  testWidgets('farmer sees the community notice and must pick everything', (tester) async {
    await pump(tester);
    expect(find.textContaining('ulat ng komunidad'), findsOneWidget);
    await tester.tap(find.byKey(const Key('submitReport')));
    await tester.pumpAndSettle();
    expect(find.text('Pumili ng bilihin at palengke.'), findsOneWidget);
    expect(reports.sent, isEmpty);
  });

  testWidgets('submits and shows the source tier', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('reportCommodity')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kamatis (Tomato)').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('reportMarket')));
    await tester.pumpAndSettle();
    // Own town (Bayombong) is listed first.
    final items = tester
        .widgetList<Text>(find.textContaining('Public Market ·'))
        .map((t) => t.data)
        .toList();
    expect(items.first, startsWith('Bayombong'));
    await tester.tap(find.text('Bayombong Public Market · Bayombong').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('reportPrice')), '55.50');
    await tester.tap(find.byKey(const Key('submitReport')));
    await tester.pumpAndSettle();
    expect(reports.sent.single, ('kamatis', 'bayombong-pm', 55.5));
    expect(find.text('Salamat! Natanggap ang ulat.'), findsOneWidget);
    expect(find.text('Komunidad'), findsOneWidget);
  });

  testWidgets('server rate limit is explained', (tester) async {
    reports.fail = const SubmitFailure(SubmitError.rateLimited);
    await pump(tester);
    await tester.tap(find.byKey(const Key('reportCommodity')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kamatis (Tomato)').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('reportMarket')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Solano Public Market · Solano').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('reportPrice')), '60');
    await tester.tap(find.byKey(const Key('submitReport')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Marami ka nang naiulat'), findsOneWidget);
  });
}
