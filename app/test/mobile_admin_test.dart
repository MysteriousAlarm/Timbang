import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timbang/core/theme/forest_gold_theme.dart';
import 'package:timbang/features/admin/presentation/catalog_page.dart';
import 'package:timbang/features/admin/presentation/official_price_dialog.dart';
import 'package:timbang/features/auth/data/auth_repository.dart';
import 'package:timbang/features/catalog/data/catalog_providers.dart';
import 'package:timbang/features/catalog/domain/catalog_item.dart';
import 'package:timbang/features/profile/domain/user_profile.dart';
import 'package:timbang/features/reports/data/price_report_repository.dart';
import 'package:timbang/features/reports/domain/official_csv.dart';
import 'package:timbang/features/reports/domain/price_report.dart';
import 'package:timbang/shared/models/role.dart';

import 'fakes.dart';

class FakeReports implements PriceReportRepository {
  (String, List<OfficialRow>)? imported;
  @override
  Future<int> importOfficial({required String sourceNote, required List<OfficialRow> rows}) async {
    imported = (sourceNote, rows);
    return rows.length;
  }

  @override
  Future<PriceSource> submit({
    required String commodityId,
    required String marketId,
    required double price,
  }) async => PriceSource.reporter;
  @override
  Stream<List<PriceReport>> watchRecent({int limit = 50}) => const Stream.empty();
}

void main() {
  late FakeReports reports;
  setUp(() => reports = FakeReports());

  Future<void> pump(WidgetTester tester, Widget w) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final auth = FakeAuthRepository()
      ..signIn(const AuthUser(uid: 'a', phone: '+639170000001'))
      ..claim = Role.admin;
    final profiles = FakeProfileRepository()
      ..current = const UserProfile(
        uid: 'a',
        name: 'Admin',
        phone: '+639170000001',
        municipality: 'Bayombong',
        role: Role.admin,
        verified: true,
        status: AccountStatus.active,
      );
    await tester.pumpWidget(
      harness(
        Scaffold(body: w),
        theme: forestGoldTheme,
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
                category: 'Lowland vegetables',
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

  testWidgets('on a phone the commodity list is cards, not a wide table', (tester) async {
    await pump(tester, const CatalogPage(kind: CatalogKind.commodities));
    expect(find.byKey(const Key('item_kamatis')), findsOneWidget);
    expect(find.byType(DataTable), findsNothing);
    expect(find.text('Kamatis'), findsOneWidget);
  });

  testWidgets('add one official price without a file', (tester) async {
    await pump(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => showOfficialPriceDialog(context),
          child: const Text('open'),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('opCommodity')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kamatis (Tomato)').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('opMarket')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bayombong PM · Bayombong').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('opPrice')), '58.50');
    await tester.enterText(find.byKey(const Key('opSource')), 'DA Bantay Presyo');
    await tester.tap(find.byKey(const Key('opSave')));
    await tester.pumpAndSettle();
    expect(reports.imported!.$1, 'DA Bantay Presyo');
    final row = reports.imported!.$2.single;
    expect((row.commodityId, row.marketId, row.price), ('kamatis', 'bpm', 58.5));
    expect(row.date, matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
  });
}
