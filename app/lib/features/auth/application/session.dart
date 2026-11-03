import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../shared/models/role.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/domain/user_profile.dart';
import '../data/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => FirebaseAuthRepository(FirebaseAuth.instance),
);

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => FirestoreProfileRepository(
    FirebaseFirestore.instance,
    FirebaseFunctions.instanceFor(region: AppConfig.functionsRegion),
  ),
);

final authUserProvider = StreamProvider<AuthUser?>(
  (ref) => ref.watch(authRepositoryProvider).authStateChanges(),
);

final profileProvider = StreamProvider<UserProfile?>((ref) {
  final user = ref.watch(authUserProvider).value;
  if (user == null) return Stream.value(null);
  return ref.watch(profileRepositoryProvider).watch(user.uid);
});

/// Role from the ID token claim. Re-fetched (forced) whenever the display mirror changes,
/// so an admin's role change shows up without signing out.
final roleClaimProvider = FutureProvider<Role?>((ref) async {
  final user = ref.watch(authUserProvider).value;
  if (user == null) return null;
  final mirror = ref.watch(profileProvider.select((p) => p.value?.role));
  return ref.watch(authRepositoryProvider).roleClaim(forceRefresh: mirror != null);
});

/// Where the user is in the auth journey. Drives router redirects.
sealed class Session {
  const Session();
}

class SessionLoading extends Session {
  const SessionLoading();
}

class SignedOut extends Session {
  const SignedOut();
}

class NeedsProfile extends Session {
  const NeedsProfile(this.user);
  final AuthUser user;
}

class SignedIn extends Session {
  const SignedIn(this.user, this.profile, this.role);
  final AuthUser user;
  final UserProfile profile;

  /// From the custom claim; falls back to the signup mirror only for farmer/buyer display.
  final Role role;
  bool get isAdmin => role == Role.admin;
}

final sessionProvider = Provider<Session>((ref) {
  final auth = ref.watch(authUserProvider);
  if (auth.isLoading && !auth.hasValue) return const SessionLoading();
  final user = auth.value;
  if (user == null) return const SignedOut();

  final profile = ref.watch(profileProvider);
  if (profile.isLoading && !profile.hasValue) return const SessionLoading();
  final p = profile.value;
  if (p == null) return NeedsProfile(user);

  // Wait for the first token read so admins are not routed as farmers for a moment.
  final claimAsync = ref.watch(roleClaimProvider);
  if (claimAsync.isLoading && !claimAsync.hasValue) return const SessionLoading();
  final claim = claimAsync.value;
  // Self-signup users have no claim; they are farmer/buyer per their own profile.
  // Elevated roles (reporter/admin) are ONLY ever taken from the claim.
  final role = claim ?? (Role.selfSignup.contains(p.role) ? p.role : Role.buyer);
  return SignedIn(user, p, role);
});
