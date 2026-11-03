import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timbang/core/theme/harvest_earth_theme.dart';
import 'package:timbang/features/auth/data/auth_repository.dart';
import 'package:timbang/features/profile/presentation/profile_setup_screen.dart';
import 'package:timbang/shared/models/role.dart';

import 'fakes.dart';

void main() {
  late FakeAuthRepository auth;
  late FakeProfileRepository profiles;

  setUp(() {
    auth = FakeAuthRepository()..signIn(const AuthUser(uid: 'u1', phone: '+639171234567'));
    profiles = FakeProfileRepository();
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      harness(
        const ProfileSetupScreen(),
        theme: harvestEarthTheme,
        overrides: fakeOverrides(auth, profiles),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('offers only farmer and buyer, plus the RA 10173 notice', (tester) async {
    await pump(tester);
    expect(find.byKey(const Key('role_farmer')), findsOneWidget);
    expect(find.byKey(const Key('role_buyer')), findsOneWidget);
    expect(find.byKey(const Key('role_reporter')), findsNothing);
    expect(find.byKey(const Key('role_admin')), findsNothing);
    expect(find.textContaining('RA 10173'), findsWidgets);
  });

  testWidgets('validates before saving', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('saveProfile')));
    await tester.pumpAndSettle();
    expect(find.text('Ilagay ang pangalan (2 hanggang 80 letra).'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('nameField')), 'Juan Dela Cruz');
    await tester.tap(find.byKey(const Key('saveProfile')));
    await tester.pumpAndSettle();
    expect(find.text('Pumili ng bayan.'), findsOneWidget);
    expect(profiles.created, isEmpty);
  });

  testWidgets('saves a farmer profile after consent', (tester) async {
    await pump(tester);
    await tester.enterText(find.byKey(const Key('nameField')), 'Juan Dela Cruz');
    await tester.tap(find.byKey(const Key('municipalityField')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bayombong').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('role_farmer')));
    await tester.pump();

    // Consent is required.
    await tester.tap(find.byKey(const Key('saveProfile')));
    await tester.pumpAndSettle();
    expect(find.text('Kailangang sumang-ayon bago magpatuloy.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('consentCheckbox')));
    await tester.tap(find.byKey(const Key('saveProfile')));
    await tester.pumpAndSettle();

    final p = profiles.created['u1']!;
    expect(p.name, 'Juan Dela Cruz');
    expect(p.municipality, 'Bayombong');
    expect(p.role, Role.farmer);
    expect(p.phone, '+639171234567');
  });
}
