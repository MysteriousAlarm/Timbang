// Accessibility pass (Step 10): Android tap targets (48x48), labeled tap targets, and text
// contrast (WCAG AA) on the main farmer screens in Filipino.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timbang/core/theme/forest_gold_theme.dart';
import 'package:timbang/core/theme/harvest_earth_theme.dart';
import 'package:timbang/features/auth/data/auth_repository.dart';
import 'package:timbang/features/auth/presentation/phone_screen.dart';
import 'package:timbang/features/catalog/data/catalog_providers.dart';
import 'package:timbang/features/catalog/domain/catalog_item.dart';
import 'package:timbang/features/landing/presentation/landing_page.dart';
import 'package:timbang/features/price_board/application/board_providers.dart';
import 'package:timbang/features/price_board/data/price_board_repository.dart';
import 'package:timbang/features/price_board/domain/board_entry.dart';
import 'package:timbang/features/price_board/presentation/price_board_section.dart';
import 'package:timbang/features/profile/domain/user_profile.dart';
import 'package:timbang/features/profile/presentation/profile_screen.dart';
import 'package:timbang/features/profile/presentation/profile_setup_screen.dart';
import 'package:timbang/shared/models/confidence.dart';
import 'package:timbang/shared/models/role.dart';

import 'fakes.dart';

final now = DateTime(2026, 11, 3, 12);

class Board implements PriceBoardRepository {
  @override
  Stream<BoardSnapshot> watchMarket(String marketId) => Stream.value(
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
        reporter: 3,
      ),
      BoardEntry(
        commodityId: 'repolyo',
        marketId: 'bpm',
        unit: 'kg',
        medianPrice: 44,
        confidence: Confidence.medium,
        reportCount: 1,
        trend: Trend.flat,
        latestReportAt: now.subtract(const Duration(hours: 30)),
        reporter: 1,
      ),
    ]),
  );
  @override
  Stream<BoardSnapshot> watchAll() => watchMarket('');

  @override
  Stream<BoardSnapshot> watchCommodity(String commodityId) => Stream.value(const BoardSnapshot([]));
}

Future<void> expectAccessible(WidgetTester tester) async {
  final handle = tester.ensureSemantics();
  await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  await expectLater(tester, meetsGuideline(textContrastGuideline));
  handle.dispose();
}

void main() {
  late FakeAuthRepository auth;
  late FakeProfileRepository profiles;

  setUp(() {
    auth = FakeAuthRepository()..signIn(const AuthUser(uid: 'u1', phone: '+639171234567'));
    profiles = FakeProfileRepository()
      ..current = const UserProfile(
        uid: 'u1',
        name: 'Juan Dela Cruz',
        phone: '+639171234567',
        municipality: 'Bayombong',
        role: Role.farmer,
        verified: true,
        status: AccountStatus.active,
      );
  });

  Future<void> pump(
    WidgetTester tester,
    Widget w, {
    ThemeData? theme,
    Size size = const Size(412, 915),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      harness(
        w,
        theme: theme ?? harvestEarthTheme,
        overrides: [
          ...fakeOverrides(auth, profiles),
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
              Commodity(
                id: 'repolyo',
                nameFil: 'Repolyo',
                nameEn: 'Cabbage',
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

  testWidgets('login screen', (tester) async {
    auth = FakeAuthRepository();
    await pump(tester, const PhoneScreen());
    await expectAccessible(tester);
  });

  testWidgets('profile setup', (tester) async {
    await pump(tester, const ProfileSetupScreen());
    await expectAccessible(tester);
  });

  testWidgets('price board', (tester) async {
    await pump(
      tester,
      const Scaffold(
        body: SingleChildScrollView(padding: EdgeInsets.all(16), child: PriceBoardSection()),
      ),
    );
    await expectAccessible(tester);
  });

  testWidgets('profile', (tester) async {
    await pump(tester, const Scaffold(body: ProfileScreen()));
    await expectAccessible(tester);
  });

  testWidgets('landing page (website theme)', (tester) async {
    await pump(tester, const LandingPage(), theme: forestGoldTheme, size: const Size(1280, 2400));
    await expectAccessible(tester);
  });
}
