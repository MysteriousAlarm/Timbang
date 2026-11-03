import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:timbang/core/theme/harvest_earth_theme.dart';
import 'package:timbang/features/auth/data/auth_repository.dart';
import 'package:timbang/features/catalog/data/catalog_providers.dart';
import 'package:timbang/features/catalog/domain/catalog_item.dart';
import 'package:timbang/features/listings/application/listing_providers.dart';
import 'package:timbang/features/listings/data/listing_repository.dart';
import 'package:timbang/features/listings/domain/listing.dart';
import 'package:timbang/features/listings/presentation/create_listing_screen.dart';
import 'package:timbang/features/listings/presentation/listing_detail_screen.dart';
import 'package:timbang/features/listings/presentation/listings_tab.dart';
import 'package:timbang/features/price_board/application/board_providers.dart';
import 'package:timbang/features/price_board/data/price_board_repository.dart';
import 'package:timbang/features/price_board/domain/board_entry.dart';
import 'package:timbang/features/profile/domain/user_profile.dart';
import 'package:timbang/shared/models/confidence.dart';
import 'package:timbang/shared/models/role.dart';

import 'fakes.dart';

final now = DateTime(2026, 11, 3, 12);

Listing mk(
  String id, {
  double price = 55,
  ListingStatus status = ListingStatus.active,
  Duration expiresIn = const Duration(days: 10),
  String farmer = 'f1',
  String town = 'Bayombong',
}) => Listing(
  id: id,
  farmerId: farmer,
  farmerName: 'Juan Dela Cruz',
  farmerPhone: '+639171234567',
  commodityId: 'kamatis',
  quantity: 50,
  unit: 'kg',
  askingPrice: price,
  municipality: town,
  harvestDate: now,
  photoUrls: const [],
  status: status,
  createdAt: now.subtract(const Duration(hours: 1)),
  expiresAt: now.add(expiresIn),
);

class FakeListings implements ListingRepository {
  List<Listing> active = [];
  List<Listing> mine = [];
  final updates = <(String, Map<String, Object?>)>[];
  ListingDraft? created;
  PostResult result = PostResult.saved;
  ListingFilter? lastFilter;

  @override
  Stream<List<Listing>> watchActive(ListingFilter filter) async* {
    lastFilter = filter;
    yield active;
  }

  @override
  Stream<List<Listing>> watchMine(String uid) async* {
    yield mine;
  }

  @override
  Stream<Listing?> watchOne(String id) async* {
    yield [...active, ...mine].where((x) => x.id == id).firstOrNull;
  }

  @override
  Future<PostResult> create({
    required String uid,
    required String farmerName,
    required String farmerPhone,
    required ListingDraft draft,
    required List<Uint8List> photos,
  }) async {
    created = draft;
    return result;
  }

  @override
  Future<void> update(String id, Map<String, Object?> changes) async => updates.add((id, changes));
}

class EmptyBoard implements PriceBoardRepository {
  EmptyBoard([this.entries = const []]);
  final List<BoardEntry> entries;
  @override
  Stream<BoardSnapshot> watchMarket(String marketId) => Stream.value(const BoardSnapshot([]));
  @override
  Stream<BoardSnapshot> watchCommodity(String commodityId) => Stream.value(BoardSnapshot(entries));
}

void main() {
  test('validateDraft mirrors the rules', () {
    const ok = ListingDraft(
      commodityId: 'k',
      quantity: 5,
      unit: 'kg',
      askingPrice: 50,
      municipality: 'Solano',
      harvestDate: null,
    );
    expect(validateDraft(ok, now: now), [DraftIssue.harvestDate]);
    final good = ListingDraft(
      commodityId: 'k',
      quantity: 5,
      unit: 'kg',
      askingPrice: 50,
      municipality: 'Solano',
      harvestDate: now,
    );
    expect(validateDraft(good, now: now), isEmpty);
    final bad = ListingDraft(
      commodityId: null,
      quantity: 0,
      unit: 'kg',
      askingPrice: 0,
      municipality: 'Makati',
      harvestDate: now.add(const Duration(days: 90)),
      note: 'x' * 300,
    );
    expect(validateDraft(bad, now: now), DraftIssue.values);
    expect(parseQuantity('1,200.5'), 1200.5);
    expect(parseQuantity('-1'), isNull);
  });

  test('effective status treats overdue active listings as expired', () {
    expect(
      mk('a', expiresIn: const Duration(hours: -1)).effectiveStatus(now),
      ListingStatus.expired,
    );
    expect(mk('a').isLive(now), isTrue);
  });

  group('widgets', () {
    late FakeListings repo;
    late FakeAuthRepository auth;
    late FakeProfileRepository profiles;

    UserProfile profile(Role role) => UserProfile(
      uid: 'f1',
      name: 'Juan Dela Cruz',
      phone: '+639171234567',
      municipality: 'Bayombong',
      role: role,
      verified: false,
      status: AccountStatus.active,
    );

    setUp(() {
      repo = FakeListings();
      auth = FakeAuthRepository()..signIn(const AuthUser(uid: 'f1', phone: '+639171234567'));
      profiles = FakeProfileRepository()..current = profile(Role.farmer);
    });

    List<Override> overrides({List<BoardEntry> board = const []}) => [
      ...fakeOverrides(auth, profiles),
      listingRepositoryProvider.overrideWithValue(repo),
      priceBoardRepositoryProvider.overrideWithValue(EmptyBoard(board)),
      commoditiesProvider.overrideWith(
        (ref) => Stream.value(const [
          Commodity(id: 'kamatis', nameFil: 'Kamatis', nameEn: 'Tomato', unit: 'kg', category: 'x'),
        ]),
      ),
      marketsProvider.overrideWith(
        (ref) => Stream.value(const [
          Market(
            id: 'bayombong-pm',
            name: 'Bayombong PM',
            municipality: 'Bayombong',
            type: 'public_market',
          ),
        ]),
      ),
      clockProvider.overrideWith((ref) => Stream.value(now)),
    ];

    Future<void> pump(WidgetTester tester, Widget w, {List<BoardEntry> board = const []}) async {
      tester.view.physicalSize = const Size(800, 2600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        harness(
          w,
          theme: harvestEarthTheme,
          overrides: overrides(board: board),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('browse hides expired listings; cheapest sort; farmers get the post button', (
      tester,
    ) async {
      repo.active = [
        mk('a', price: 60),
        mk('b', price: 40),
        mk('c', expiresIn: const Duration(hours: -2)),
      ];
      await pump(tester, const ListingsTab());
      expect(find.byKey(const Key('listing_a')), findsOneWidget);
      expect(find.byKey(const Key('listing_b')), findsOneWidget);
      expect(find.byKey(const Key('listing_c')), findsNothing);
      expect(find.byKey(const Key('postListing')), findsOneWidget);
      await tester.tap(find.text('Pinakamura'));
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.byKey(const Key('listing_b'))).dy <
            tester.getTopLeft(find.byKey(const Key('listing_a'))).dy,
        isTrue,
      );
    });

    testWidgets('buyers do not get the post button', (tester) async {
      profiles.current = profile(Role.buyer);
      await pump(tester, const ListingsTab());
      expect(find.byKey(const Key('postListing')), findsNothing);
    });

    testWidgets('buyer sees contact and median comparison', (tester) async {
      auth = FakeAuthRepository()..signIn(const AuthUser(uid: 'b1', phone: '+639170000000'));
      profiles.current = profile(Role.buyer);
      repo.active = [mk('a', price: 70)];
      final entry = BoardEntry(
        commodityId: 'kamatis',
        marketId: 'bayombong-pm',
        unit: 'kg',
        medianPrice: 64,
        confidence: Confidence.high,
        reportCount: 3,
        trend: Trend.up,
        latestReportAt: now,
      );
      await pump(tester, const ListingDetailScreen(listingId: 'a'), board: [entry]);
      expect(find.text('+63 917 123 4567'), findsOneWidget);
      expect(find.text('Tumawag'), findsOneWidget);
      expect(find.text('₱6.00 mas mataas sa median sa palengke.'), findsOneWidget);
      expect(find.byKey(const Key('markSold')), findsNothing);
    });

    testWidgets('owner can mark sold', (tester) async {
      repo.active = [mk('a')];
      await pump(tester, const ListingDetailScreen(listingId: 'a'));
      await tester.tap(find.byKey(const Key('markSold')));
      await tester.pumpAndSettle();
      expect(repo.updates.single.$2, {'status': 'sold'});
    });

    testWidgets('create validates then posts with the commodity unit', (tester) async {
      await pump(tester, const CreateListingScreen());
      await tester.tap(find.byKey(const Key('submitListing')));
      await tester.pumpAndSettle();
      expect(find.text('Pumili ng bilihin at palengke.'), findsOneWidget);
      expect(repo.created, isNull);

      await tester.tap(find.byKey(const Key('listingCommodity')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kamatis (Tomato)').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('listingQty')), '50');
      await tester.enterText(find.byKey(const Key('listingPrice')), '58.50');
      await tester.tap(find.byKey(const Key('submitListing')));
      await tester.pumpAndSettle();
      expect(repo.created!.commodityId, 'kamatis');
      expect(repo.created!.unit, 'kg');
      expect(repo.created!.askingPrice, 58.5);
      expect(repo.created!.municipality, 'Bayombong');
    });

    testWidgets('buyers cannot open the post form', (tester) async {
      profiles.current = profile(Role.buyer);
      await pump(tester, const CreateListingScreen());
      expect(find.text('Para sa magsasaka lamang'), findsOneWidget);
    });
  });
}
