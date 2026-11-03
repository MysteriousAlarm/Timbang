import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timbang/core/theme/harvest_earth_theme.dart';
import 'package:timbang/features/auth/data/auth_repository.dart';
import 'package:timbang/features/catalog/data/catalog_providers.dart';
import 'package:timbang/features/catalog/domain/catalog_item.dart';
import 'package:timbang/features/inquiries/data/inquiry_repository.dart';
import 'package:timbang/features/inquiries/domain/inquiry.dart';
import 'package:timbang/features/inquiries/presentation/ask_farmer.dart';
import 'package:timbang/features/inquiries/presentation/inbox_tab.dart';
import 'package:timbang/features/listings/domain/listing.dart';
import 'package:timbang/features/price_board/application/board_providers.dart';
import 'package:timbang/features/profile/domain/user_profile.dart';
import 'package:timbang/features/reports/data/price_report_repository.dart'
    show SubmitError, SubmitFailure;
import 'package:timbang/shared/models/role.dart';

import 'fakes.dart';

final now = DateTime(2026, 11, 3, 12);

class FakeInq implements InquiryRepository {
  List<Inquiry> received = [];
  List<Inquiry> sent = [];
  final statuses = <(String, InquiryStatus)>[];
  (String, String)? lastSent;
  SubmitFailure? fail;

  @override
  Future<void> send({required String listingId, required String message}) async {
    if (fail != null) throw fail!;
    lastSent = (listingId, message);
  }

  @override
  Stream<List<Inquiry>> watchReceived(String uid) => Stream.value(received);
  @override
  Stream<List<Inquiry>> watchSent(String uid) => Stream.value(sent);
  @override
  Future<void> setStatus(String id, InquiryStatus status) async => statuses.add((id, status));
}

Inquiry q(String id, {InquiryStatus status = InquiryStatus.newInquiry}) => Inquiry(
  id: id,
  listingId: 'L1',
  farmerId: 'f1',
  buyerId: 'b1',
  buyerName: 'Bea Santos',
  buyerPhone: '+639172220000',
  commodityId: 'kamatis',
  message: 'Available pa po?',
  status: status,
  createdAt: now.subtract(const Duration(minutes: 30)),
);

void main() {
  late FakeInq repo;
  late FakeAuthRepository auth;
  late FakeProfileRepository profiles;

  setUp(() {
    repo = FakeInq();
    auth = FakeAuthRepository()..signIn(const AuthUser(uid: 'f1', phone: '+639171234567'));
    profiles = FakeProfileRepository()
      ..current = const UserProfile(
        uid: 'f1',
        name: 'Juan',
        phone: '+639171234567',
        municipality: 'Bayombong',
        role: Role.farmer,
        verified: false,
        status: AccountStatus.active,
      );
  });

  Future<void> pump(WidgetTester tester, Widget w) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      harness(
        Scaffold(body: w),
        theme: harvestEarthTheme,
        overrides: [
          ...fakeOverrides(auth, profiles),
          inquiryRepositoryProvider.overrideWithValue(repo),
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
          clockProvider.overrideWith((ref) => Stream.value(now)),
        ],
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('farmer inbox shows buyer, contact, unread count; mark as read', (tester) async {
    repo.received = [q('Q1'), q('Q2', status: InquiryStatus.read)];
    await pump(tester, const InboxTab());
    expect(find.text('Natanggap (1)'), findsOneWidget);
    expect(find.text('Mula kay Bea Santos'), findsNWidgets(2));
    expect(find.text('+63 917 222 0000'), findsNWidgets(2));
    expect(find.text('Bago'), findsOneWidget);
    await tester.tap(find.byKey(const Key('markRead_Q1')));
    await tester.pumpAndSettle();
    expect(repo.statuses.single, ('Q1', InquiryStatus.read));
  });

  testWidgets('buyer sees only sent inquiries, without contact of themselves', (tester) async {
    profiles.current = const UserProfile(
      uid: 'f1',
      name: 'Bea',
      phone: '+639172220000',
      municipality: 'Solano',
      role: Role.buyer,
      verified: false,
      status: AccountStatus.active,
    );
    repo.sent = [q('Q1')];
    await pump(tester, const InboxTab());
    expect(find.text('Natanggap'), findsNothing);
    expect(find.text('Tungkol sa Kamatis'), findsOneWidget);
    expect(find.text('Tumawag'), findsNothing);
  });

  final listing = Listing(
    id: 'L1',
    farmerId: 'f2',
    farmerName: 'Juan',
    farmerPhone: '+639171234567',
    commodityId: 'kamatis',
    quantity: 50,
    unit: 'kg',
    askingPrice: 55,
    municipality: 'Bayombong',
    harvestDate: now,
    photoUrls: const [],
    status: ListingStatus.active,
    createdAt: now,
    expiresAt: now.add(const Duration(days: 5)),
  );

  testWidgets('ask sheet sends a prefilled message', (tester) async {
    await pump(tester, AskFarmerButton(listing: listing, commodityName: 'Kamatis'));
    await tester.tap(find.byKey(const Key('askFarmer')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Interesado po ako sa inyong Kamatis'), findsOneWidget);
    await tester.tap(find.byKey(const Key('askSend')));
    await tester.pumpAndSettle();
    expect(repo.lastSent!.$1, 'L1');
    expect(find.textContaining('Naipadala ang tanong'), findsOneWidget);
  });

  testWidgets('duplicate inquiry is explained', (tester) async {
    repo.fail = const SubmitFailure(SubmitError.duplicate);
    await pump(tester, AskFarmerButton(listing: listing, commodityName: 'Kamatis'));
    await tester.tap(find.byKey(const Key('askFarmer')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('askSend')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Nakapagtanong ka na'), findsOneWidget);
  });
}
