import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timbang/features/auth/application/session.dart';
import 'package:timbang/features/auth/data/auth_repository.dart';
import 'package:timbang/features/profile/domain/user_profile.dart';
import 'package:timbang/shared/models/role.dart';

import 'fakes.dart';

UserProfile _profile(Role mirror) => UserProfile(
  uid: 'u1',
  name: 'Juan',
  phone: '+639171234567',
  municipality: 'Bayombong',
  role: mirror,
  verified: false,
  status: AccountStatus.active,
);

Future<Session> _settle(ProviderContainer c) async {
  final sub = c.listen(sessionProvider, (_, _) {});
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
  final s = c.read(sessionProvider);
  sub.close();
  return s;
}

void main() {
  test('a forged admin role in Firestore is ignored without the claim', () async {
    final auth = FakeAuthRepository()..signIn(const AuthUser(uid: 'u1', phone: '+639171234567'));
    final profiles = FakeProfileRepository()..current = _profile(Role.admin);
    final c = ProviderContainer(overrides: fakeOverrides(auth, profiles));
    addTearDown(c.dispose);

    final s = await _settle(c);
    expect(s, isA<SignedIn>());
    expect((s as SignedIn).role, isNot(Role.admin));
    expect(s.isAdmin, isFalse);
  });

  test('admin role comes from the custom claim', () async {
    final auth = FakeAuthRepository()
      ..signIn(const AuthUser(uid: 'u1', phone: '+639171234567'))
      ..claim = Role.admin;
    final profiles = FakeProfileRepository()..current = _profile(Role.admin);
    final c = ProviderContainer(overrides: fakeOverrides(auth, profiles));
    addTearDown(c.dispose);

    final s = await _settle(c) as SignedIn;
    expect(s.isAdmin, isTrue);
  });

  test('signed in without profile needs setup', () async {
    final auth = FakeAuthRepository()..signIn(const AuthUser(uid: 'u1', phone: '+639171234567'));
    final c = ProviderContainer(overrides: fakeOverrides(auth, FakeProfileRepository()));
    addTearDown(c.dispose);
    expect(await _settle(c), isA<NeedsProfile>());
  });
}
