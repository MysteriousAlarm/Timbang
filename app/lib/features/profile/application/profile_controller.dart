import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/role.dart';
import '../../auth/application/session.dart';
import '../domain/profile_validation.dart';
import '../domain/user_profile.dart';

enum ProfileFormError { name, municipality, role, consent, save }

/// Profile actions. Business logic stays here, not in widgets.
class ProfileController {
  ProfileController(this._ref);
  final Ref _ref;

  /// Validates and creates the signup profile. Returns the first error, or null on success.
  Future<ProfileFormError?> createProfile({
    required String name,
    required String? municipality,
    required Role? role,
    required bool consent,
  }) async {
    if (!ProfileValidation.validName(name)) return ProfileFormError.name;
    if (!ProfileValidation.validMunicipality(municipality)) return ProfileFormError.municipality;
    if (!ProfileValidation.validSignupRole(role)) return ProfileFormError.role;
    if (!consent) return ProfileFormError.consent;

    final user = _ref.read(authRepositoryProvider).currentUser;
    if (user == null || user.phone == null) return ProfileFormError.save;
    try {
      await _ref
          .read(profileRepositoryProvider)
          .create(
            user.uid,
            NewProfile(name: name, phone: user.phone!, municipality: municipality!, role: role!),
          );
      return null;
    } catch (_) {
      return ProfileFormError.save;
    }
  }

  Future<ProfileFormError?> updateProfile({
    required String name,
    required String? municipality,
  }) async {
    if (!ProfileValidation.validName(name)) return ProfileFormError.name;
    if (!ProfileValidation.validMunicipality(municipality)) return ProfileFormError.municipality;
    final user = _ref.read(authRepositoryProvider).currentUser;
    if (user == null) return ProfileFormError.save;
    try {
      await _ref
          .read(profileRepositoryProvider)
          .update(user.uid, name: name, municipality: municipality!);
      return null;
    } catch (_) {
      return ProfileFormError.save;
    }
  }

  Future<void> signOut() => _ref.read(authRepositoryProvider).signOut();

  Future<bool> deleteAccount() async {
    try {
      await _ref.read(profileRepositoryProvider).deleteMyAccount();
      await _ref.read(authRepositoryProvider).signOut();
      return true;
    } catch (_) {
      return false;
    }
  }
}

final profileControllerProvider = Provider<ProfileController>(ProfileController.new);
