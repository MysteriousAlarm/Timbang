import '../../../core/l10n/generated/app_localizations.dart';
import '../../../shared/models/role.dart';
import '../application/profile_controller.dart';

String profileErrorText(AppLocalizations l10n, ProfileFormError e) => switch (e) {
  ProfileFormError.name => l10n.errNameRequired,
  ProfileFormError.municipality => l10n.errMunicipalityRequired,
  ProfileFormError.role => l10n.errRoleRequired,
  ProfileFormError.consent => l10n.errConsentRequired,
  ProfileFormError.save => l10n.errGeneric,
};

String roleLabel(AppLocalizations l10n, Role r) => switch (r) {
  Role.farmer => l10n.roleFarmer,
  Role.buyer => l10n.roleBuyer,
  Role.reporter => l10n.roleReporter,
  Role.admin => l10n.roleAdmin,
};
