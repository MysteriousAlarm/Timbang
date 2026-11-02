/// User roles. The source of truth is the `role` custom claim on the ID token;
/// the copy in users/{uid} is display-only.
enum Role {
  farmer,
  buyer,
  reporter,
  admin;

  static Role? tryParse(Object? value) {
    for (final r in Role.values) {
      if (r.name == value) return r;
    }
    return null;
  }

  /// Roles a user may choose at signup. reporter/admin are granted by an admin only.
  static const selfSignup = [Role.farmer, Role.buyer];
}
