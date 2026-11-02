import '../../../core/config/app_config.dart';
import '../../../shared/models/role.dart';

/// Client-side checks that mirror firestore.rules (rules remain the real guard).
abstract final class ProfileValidation {
  static bool validName(String? v) {
    final t = v?.trim() ?? '';
    return t.length >= AppConfig.nameMinLength && t.length <= AppConfig.nameMaxLength;
  }

  static bool validMunicipality(String? v) => v != null && AppConfig.municipalities.contains(v);

  static bool validSignupRole(Role? r) => r != null && Role.selfSignup.contains(r);
}
