import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timbang/core/l10n/generated/app_localizations_fil.dart';
import 'package:timbang/core/theme/harvest_earth_theme.dart';
import 'package:timbang/features/auth/data/auth_repository.dart';
import 'package:timbang/features/catalog/data/catalog_providers.dart';
import 'package:timbang/features/catalog/domain/catalog_item.dart';
import 'package:timbang/features/price_board/application/board_providers.dart';
import 'package:timbang/features/price_board/data/price_board_repository.dart';
import 'package:timbang/features/price_board/domain/board_entry.dart';
import 'package:timbang/features/price_board/presentation/board_widgets.dart';
import 'package:timbang/features/price_board/presentation/commodity_detail_screen.dart';
import 'package:timbang/features/price_board/presentation/price_board_section.dart';
import 'package:timbang/features/profile/domain/user_profile.dart';
import 'package:timbang/shared/models/confidence.dart';
import 'package:timbang/shared/models/role.dart';

import 'fakes.dart';

final now = DateTime(2026, 11, 3, 12);

BoardEntry e(
  String c,
  String m,
  double p, {
  Duration age = const Duration(hours: 2),
  Confidence conf = Confidence.medium,
  bool demo = false,
}) => BoardEntry(
  commodityId: c,
  marketId: m,
  unit: 'kg',
  medianPrice: p,
  confidence: conf,
  reportCount: 2,
  trend: Trend.up,
  latestReportAt: now.subtract(age),
  reporter: 1,
  community: 1,
  isDemo: demo,
);

const commodities = [
  Commodity(id: 'kamatis', nameFil: 'Kamatis', nameEn: 'Tomato', unit: 'kg', category: 'Gulay'),
  Commodity(id: 'repolyo', nameFil: 'Repolyo', nameEn: 'Cabbage', unit: 'kg', category: 'Gulay'),
  Commodity(id: 'old', nameFil: 'Luma', nameEn: 'Old', unit: 'kg', category: 'x', active: false),
];
const markets = [
  Market(id: 'solano-pm', name: 'Solano PM', municipality: 'Solano', type: 'public_market'),
  Market(
    id: 'bayombong-pm',
    name: 'Bayombong PM',
    municipality: 'Bayombong',
    type: 'public_market',
  ),
  Market(id: 'bambang-pm', name: 'Bambang PM', municipality: 'Bambang', type: 'public_market'),
];

class FakeBoard implements PriceBoardRepository {
  final market = StreamController<BoardSnapshot>.broadcast();
  final commodity = StreamController<BoardSnapshot>.broadcast();
  BoardSnapshot marketData = const BoardSnapshot([]);
  BoardSnapshot commodityData = const BoardSnapshot([]);
  String? lastMarket;

  @override
  Stream<BoardSnapshot> watchMarket(String marketId) async* {
    lastMarket = marketId;
    yield marketData;
  }

  @override
  Stream<BoardSnapshot> watchCommodity(String commodityId) async* {
    yield commodityData;
  }
}

void main() {
  group('domain', () {
    test('peso formats with thousands and centavos', () {
      expect(peso(64), '₱64.00');
      expect(peso(1250.5), '₱1,250.50');
    });
    test('stale after 24 hours, never hidden', () {
      expect(e('k', 'm', 1, age: const Duration(hours: 23)).isStale(now), isFalse);
      expect(e('k', 'm', 1, age: const Duration(hours: 25)).isStale(now), isTrue);
    });
    test('ageLabel', () {
      final l = AppLocalizationsFil();
      expect(ageLabel(l, now, now), 'ngayon lang');
      expect(
        ageLabel(l, now, now.subtract(const Duration(minutes: 15))),
        '15 minuto na ang nakalipas',
      );
      expect(ageLabel(l, now, now.subtract(const Duration(hours: 3))), '3 oras na ang nakalipas');
      expect(ageLabel(l, now, now.subtract(const Duration(days: 2))), '2 araw na ang nakalipas');
    });
    test('joinRows hides inactive commodities and sorts by name', () {
      final rows = joinRows([
        e('repolyo', 'm', 40),
        e('old', 'm', 1),
        e('kamatis', 'm', 60),
      ], commodities);
      expect(rows.map((r) => r.commodity.id), ['kamatis', 'repolyo']);
    });
    test('compareRows: own town first, then cheapest', () {
      final rows = compareRows(
        [e('k', 'solano-pm', 50), e('k', 'bambang-pm', 45), e('k', 'bayombong-pm', 70)],
        markets,
        'Bayombong',
      );
      expect(rows.map((r) => r.market.id), ['bayombong-pm', 'bambang-pm', 'solano-pm']);
      expect(rows.first.ownTown, isTrue);
    });
  });

  group('widgets', () {
    late FakeBoard board;
    late FakeAuthRepository auth;
    late FakeProfileRepository profiles;

    setUp(() {
      board = FakeBoard();
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
    });

    Future<void> pump(WidgetTester tester, Widget child) async {
      tester.view.physicalSize = const Size(800, 2600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        harness(
          Scaffold(body: SingleChildScrollView(child: child)),
          theme: harvestEarthTheme,
          overrides: [
            ...fakeOverrides(auth, profiles),
            priceBoardRepositoryProvider.overrideWithValue(board),
            commoditiesProvider.overrideWith((ref) => Stream.value(commodities)),
            marketsProvider.overrideWith((ref) => Stream.value(markets)),
            clockProvider.overrideWith((ref) => Stream.value(now)),
          ],
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('board defaults to a market in the user town and shows every label', (
      tester,
    ) async {
      board.marketData = BoardSnapshot([
        e('kamatis', 'bayombong-pm', 64, conf: Confidence.high),
        e('repolyo', 'bayombong-pm', 44, age: const Duration(hours: 30), conf: Confidence.low),
      ]);
      await pump(tester, const PriceBoardSection());
      expect(board.lastMarket, 'bayombong-pm');
      expect(find.text('Bayombong PM'), findsOneWidget);
      expect(find.text('₱64.00'), findsOneWidget);
      expect(find.text('₱44.00'), findsOneWidget);
      expect(find.text('Mataas'), findsOneWidget);
      expect(find.text('Mababa'), findsOneWidget);
      expect(find.text('Tumaas'), findsNWidgets(2));
      // The 30-hour-old entry is still shown, marked stale with its age.
      expect(find.text('Luma na'), findsOneWidget);
      expect(find.textContaining('Na-update 1 araw na ang nakalipas'), findsOneWidget);
      expect(find.textContaining('Na-update 2 oras na ang nakalipas'), findsOneWidget);
      expect(find.textContaining('Tagapag-ulat'), findsNWidgets(2));
    });

    testWidgets('offline and demo banners', (tester) async {
      board.marketData = BoardSnapshot([
        e('kamatis', 'bayombong-pm', 64, demo: true),
      ], fromCache: true);
      await pump(tester, const PriceBoardSection());
      expect(find.textContaining('Offline ka'), findsOneWidget);
      expect(find.textContaining('Hindi ito totoong presyo'), findsOneWidget);
    });

    testWidgets('empty state', (tester) async {
      await pump(tester, const PriceBoardSection());
      expect(find.text('Wala pang presyo'), findsOneWidget);
    });

    testWidgets('switching market', (tester) async {
      await pump(tester, const PriceBoardSection());
      await tester.tap(find.byKey(const Key('marketPicker')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Solano PM'));
      await tester.pumpAndSettle();
      expect(board.lastMarket, 'solano-pm');
    });

    testWidgets('comparison: headline, own town first, cheapest and differences', (tester) async {
      board.commodityData = BoardSnapshot([
        e('kamatis', 'solano-pm', 61),
        e('kamatis', 'bambang-pm', 52),
        e('kamatis', 'bayombong-pm', 64, conf: Confidence.high),
      ]);
      tester.view.physicalSize = const Size(800, 2600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        harness(
          const CommodityDetailScreen(commodityId: 'kamatis'),
          theme: harvestEarthTheme,
          overrides: [
            ...fakeOverrides(auth, profiles),
            priceBoardRepositoryProvider.overrideWithValue(board),
            commoditiesProvider.overrideWith((ref) => Stream.value(commodities)),
            marketsProvider.overrideWith((ref) => Stream.value(markets)),
            clockProvider.overrideWith((ref) => Stream.value(now)),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Median sa Bayombong PM'), findsOneWidget);
      double y(String k) => tester.getTopLeft(find.byKey(Key(k))).dy;
      expect(y('cmp_bayombong-pm') < y('cmp_bambang-pm'), isTrue);
      expect(y('cmp_bambang-pm') < y('cmp_solano-pm'), isTrue);
      expect(find.text('Iyong bayan'), findsOneWidget);
      expect(find.text('Pinakamura'), findsOneWidget);
      expect(find.text('₱12.00 mas mababa'), findsOneWidget);
      expect(find.text('₱3.00 mas mababa'), findsOneWidget);
    });
  });
}
