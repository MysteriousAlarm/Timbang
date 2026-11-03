import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timbang/core/theme/harvest_earth_theme.dart';
import 'package:timbang/features/alerts/data/alert_repository.dart';
import 'package:timbang/features/alerts/domain/price_alert.dart';
import 'package:timbang/features/alerts/presentation/alerts_tab.dart';
import 'package:timbang/features/auth/data/auth_repository.dart';
import 'package:timbang/features/catalog/data/catalog_providers.dart';
import 'package:timbang/features/catalog/domain/catalog_item.dart';
import 'package:timbang/features/price_board/application/board_providers.dart';
import 'package:timbang/features/price_board/data/price_board_repository.dart';
import 'package:timbang/features/price_board/domain/board_entry.dart';
import 'package:timbang/features/profile/domain/user_profile.dart';
import 'package:timbang/shared/models/confidence.dart';
import 'package:timbang/shared/models/role.dart';

import 'fakes.dart';

final now = DateTime(2026, 11, 3, 12);

class FakeAlerts implements AlertRepository {
  List<PriceAlert> mine = [];
  final created = <(String, String, double, AlertDirection)>[];
  final toggled = <(String, bool)>[];
  @override
  Stream<List<PriceAlert>> watchMine(String uid) => Stream.value(mine);
  @override
  Future<void> create({
    required String uid,
    required String commodityId,
    required String marketId,
    required double threshold,
    required AlertDirection direction,
  }) async => created.add((commodityId, marketId, threshold, direction));
  @override
  Future<void> setActive(String id, bool active) async => toggled.add((id, active));
  @override
  Future<void> delete(String id) async {}
}

class Board implements PriceBoardRepository {
  @override
  Stream<BoardSnapshot> watchMarket(String marketId) => Stream.value(const BoardSnapshot([]));
  @override
  Stream<BoardSnapshot> watchCommodity(String commodityId) => Stream.value(
    BoardSnapshot([
      BoardEntry(
        commodityId: 'kamatis',
        marketId: 'bpm',
        unit: 'kg',
        medianPrice: 64,
        confidence: Confidence.high,
        reportCount: 3,
        trend: Trend.up,
        latestReportAt: now,
      ),
    ]),
  );
}

void main() {
  test('isMet', () {
    const a = PriceAlert(
      id: 'a',
      commodityId: 'k',
      marketId: 'm',
      threshold: 60,
      direction: AlertDirection.above,
      active: true,
    );
    expect(a.isMet(60), isTrue);
    expect(a.isMet(59), isFalse);
  });

  late FakeAlerts repo;
  setUp(() => repo = FakeAlerts());

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final auth = FakeAuthRepository()..signIn(const AuthUser(uid: 'u1', phone: '+639171234567'));
    final profiles = FakeProfileRepository()
      ..current = const UserProfile(
        uid: 'u1',
        name: 'Juan',
        phone: '+639171234567',
        municipality: 'Bayombong',
        role: Role.farmer,
        verified: false,
        status: AccountStatus.active,
      );
    await tester.pumpWidget(
      harness(
        const AlertsTab(),
        theme: harvestEarthTheme,
        overrides: [
          ...fakeOverrides(auth, profiles),
          alertRepositoryProvider.overrideWithValue(repo),
          priceBoardRepositoryProvider.overrideWithValue(Board()),
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
          clockProvider.overrideWith((ref) => Stream.value(now)),
        ],
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('lists alerts with the current median and toggles them', (tester) async {
    repo.mine = const [
      PriceAlert(
        id: 'a1',
        commodityId: 'kamatis',
        marketId: 'bpm',
        threshold: 60,
        direction: AlertDirection.above,
        active: true,
      ),
    ];
    await pump(tester);
    expect(find.text('Kamatis · Bayombong PM'), findsOneWidget);
    expect(find.text('Kapag umabot o lumampas sa ₱60.00'), findsOneWidget);
    expect(find.textContaining('Median ngayon: ₱64.00'), findsOneWidget);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(repo.toggled.single, ('a1', false));
  });

  testWidgets('creates an alert', (tester) async {
    await pump(tester);
    expect(find.text('Wala ka pang alerto'), findsOneWidget);
    await tester.tap(find.byKey(const Key('addAlert')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('alertCommodity')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kamatis (Tomato)').last);
    await tester.pumpAndSettle();
    expect(find.text('Median ngayon: ₱64.00'), findsOneWidget);
    await tester.tap(find.text('Bumaba sa'));
    await tester.enterText(find.byKey(const Key('alertThreshold')), '50');
    await tester.tap(find.byKey(const Key('alertSave')));
    await tester.pumpAndSettle();
    expect(repo.created.single, ('kamatis', 'bpm', 50.0, AlertDirection.below));
  });
}
