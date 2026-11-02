import '../../../core/l10n/generated/app_localizations.dart';
import '../data/auth_repository.dart';

String authErrorText(AppLocalizations l10n, AuthErrorCode code) => switch (code) {
  AuthErrorCode.invalidPhone => l10n.errInvalidPhone,
  AuthErrorCode.invalidCode => l10n.errInvalidCode,
  AuthErrorCode.codeExpired => l10n.errCodeExpired,
  AuthErrorCode.tooManyRequests => l10n.errTooManyRequests,
  AuthErrorCode.network => l10n.errNetwork,
  AuthErrorCode.generic => l10n.errGeneric,
};
