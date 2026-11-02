import '../../../shared/models/role.dart';

enum AccountStatus { active, suspended }

/// users/{uid}. Only name, phone and municipality are personal data (RA 10173).
class UserProfile {
  const UserProfile({
    required this.uid,
    required this.name,
    required this.phone,
    required this.municipality,
    required this.role,
    required this.verified,
    required this.status,
  });

  final String uid;
  final String name;
  final String phone;
  final String municipality;

  /// Display mirror of the custom claim. Never used for authorization.
  final Role role;
  final bool verified;
  final AccountStatus status;

  bool get isSuspended => status == AccountStatus.suspended;

  factory UserProfile.fromMap(String uid, Map<String, dynamic> m) => UserProfile(
    uid: uid,
    name: (m['name'] as String?) ?? '',
    phone: (m['phone'] as String?) ?? '',
    municipality: (m['municipality'] as String?) ?? '',
    role: Role.tryParse(m['role']) ?? Role.buyer,
    verified: m['verified'] == true,
    status: m['status'] == 'suspended' ? AccountStatus.suspended : AccountStatus.active,
  );
}

/// What a user submits at signup. Validation mirrors firestore.rules.
class NewProfile {
  const NewProfile({
    required this.name,
    required this.phone,
    required this.municipality,
    required this.role,
  });

  final String name;
  final String phone;
  final String municipality;
  final Role role;
}
