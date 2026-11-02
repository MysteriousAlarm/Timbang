import 'package:flutter_test/flutter_test.dart';
import 'package:timbang/core/router/redirect.dart';
import 'package:timbang/features/auth/application/session.dart';
import 'package:timbang/features/auth/data/auth_repository.dart';
import 'package:timbang/features/profile/domain/user_profile.dart';
import 'package:timbang/shared/models/role.dart';

const _user = AuthUser(uid: 'u1', phone: '+639171234567');
const _profile = UserProfile(
  uid: 'u1',
  name: 'Juan',
  phone: '+639171234567',
  municipality: 'Bayombong',
  role: Role.farmer,
  verified: false,
  status: AccountStatus.active,
);
const _farmer = SignedIn(_user, _profile, Role.farmer);
const _admin = SignedIn(_user, _profile, Role.admin);

void main() {
  const m = AppTarget.mobile;
  const w = AppTarget.web;

  test('loading goes to splash, except the public web landing page', () {
    expect(resolveRedirect(const SessionLoading(), Routes.prices, m), Routes.splash);
    expect(resolveRedirect(const SessionLoading(), Routes.landing, w), isNull);
  });

  test('signed out goes to login; web landing stays public', () {
    expect(resolveRedirect(const SignedOut(), Routes.prices, m), Routes.login);
    expect(resolveRedirect(const SignedOut(), Routes.admin, w), Routes.login);
    expect(resolveRedirect(const SignedOut(), Routes.login, m), isNull);
    expect(resolveRedirect(const SignedOut(), Routes.otp, m), isNull);
    expect(resolveRedirect(const SignedOut(), Routes.landing, w), isNull);
    expect(resolveRedirect(const SignedOut(), Routes.landing, m), Routes.login);
  });

  test('signed in without profile must finish setup', () {
    expect(resolveRedirect(const NeedsProfile(_user), Routes.prices, m), Routes.setup);
    expect(resolveRedirect(const NeedsProfile(_user), Routes.setup, m), isNull);
  });

  test('signed in leaves auth screens', () {
    expect(resolveRedirect(_farmer, Routes.login, m), Routes.prices);
    expect(resolveRedirect(_farmer, Routes.setup, m), Routes.prices);
    expect(resolveRedirect(_farmer, Routes.splash, m), Routes.prices);
    expect(resolveRedirect(_farmer, Routes.profile, m), isNull);
    expect(resolveRedirect(_admin, Routes.login, w), Routes.admin);
  });

  test('admin route needs the admin claim and the web build', () {
    expect(resolveRedirect(_farmer, Routes.admin, w), Routes.prices);
    expect(resolveRedirect(_admin, Routes.admin, w), isNull);
    expect(resolveRedirect(_admin, Routes.admin, m), Routes.prices);
    expect(resolveRedirect(_farmer, Routes.adminCommodities, w), Routes.prices);
    expect(resolveRedirect(_admin, Routes.adminMarkets, w), isNull);
  });
}
