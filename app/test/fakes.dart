import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:timbang/core/l10n/generated/app_localizations.dart';
import 'package:timbang/features/auth/application/session.dart';
import 'package:timbang/features/auth/data/auth_repository.dart';
import 'package:timbang/features/profile/data/profile_repository.dart';
import 'package:timbang/features/profile/domain/user_profile.dart';
import 'package:timbang/shared/models/role.dart';

class FakeVerification implements PhoneVerification {
  FakeVerification(this.repo);
  final FakeAuthRepository repo;
  static const validCode = '123456';

  @override
  Future<void> confirm(String code) async {
    if (code != validCode) throw const AuthFailure(AuthErrorCode.invalidCode);
    repo.signIn(const AuthUser(uid: 'u1', phone: '+639171234567'));
  }
}

class FakeAuthRepository implements AuthRepository {
  final _ctrl = StreamController<AuthUser?>.broadcast();
  AuthUser? _user;
  Role? claim;
  String? lastPhone;
  AuthFailure? failNext;

  void signIn(AuthUser u) {
    _user = u;
    _ctrl.add(u);
  }

  @override
  Stream<AuthUser?> authStateChanges() async* {
    yield _user;
    yield* _ctrl.stream;
  }

  @override
  AuthUser? get currentUser => _user;

  @override
  Future<PhoneVerification?> startPhoneVerification(String e164) async {
    lastPhone = e164;
    if (failNext != null) throw failNext!;
    return FakeVerification(this);
  }

  @override
  Future<Role?> roleClaim({bool forceRefresh = false}) async => claim;

  @override
  Future<void> signOut() async {
    _user = null;
    _ctrl.add(null);
  }
}

class FakeProfileRepository implements ProfileRepository {
  final created = <String, NewProfile>{};
  final _ctrl = StreamController<UserProfile?>.broadcast();
  UserProfile? current;

  @override
  Stream<UserProfile?> watch(String uid) async* {
    yield current;
    yield* _ctrl.stream;
  }

  @override
  Future<void> create(String uid, NewProfile p) async {
    created[uid] = p;
    current = UserProfile(
      uid: uid,
      name: p.name,
      phone: p.phone,
      municipality: p.municipality,
      role: p.role,
      verified: false,
      status: AccountStatus.active,
    );
    _ctrl.add(current);
  }

  @override
  Future<void> update(String uid, {required String name, required String municipality}) async {}

  @override
  Future<void> deleteMyAccount() async {}

  @override
  Future<Map<String, dynamic>> exportMyData() async => {
    'profile': {'name': current?.name},
  };
}

List<Override> fakeOverrides(FakeAuthRepository auth, FakeProfileRepository profiles) => [
  authRepositoryProvider.overrideWithValue(auth),
  profileRepositoryProvider.overrideWithValue(profiles),
];

/// Wraps a widget with l10n (Filipino) and the given theme.
Widget harness(Widget child, {required ThemeData theme, List<Override> overrides = const []}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      theme: theme,
      locale: const Locale('fil'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: child,
    ),
  );
}
