import '../../../core/l10n/generated/app_localizations.dart';
import '../../catalog/domain/catalog_item.dart';
import '../../catalog/domain/catalog_validation.dart';

String unitLabel(AppLocalizations l10n, String unit) => switch (unit) {
  'kg' => l10n.unitKg,
  'bundle' => l10n.unitBundle,
  'piece' => l10n.unitPiece,
  _ => unit,
};

String marketTypeLabel(AppLocalizations l10n, String type) => switch (type) {
  'public_market' => l10n.marketTypePublic,
  'trading_post' => l10n.marketTypeTrading,
  'farmgate_area' => l10n.marketTypeFarmgate,
  _ => type,
};

String kindTitle(AppLocalizations l10n, CatalogKind kind) => switch (kind) {
  CatalogKind.commodities => l10n.adminCommodities,
  CatalogKind.markets => l10n.adminMarkets,
};

String issueText(AppLocalizations l10n, RowIssue i) {
  final problem = switch (i.kind) {
    IssueKind.missing => l10n.issueMissing,
    IssueKind.tooLong => l10n.issueTooLong,
    IssueKind.tooShort => l10n.issueTooShort,
    IssueKind.badId => l10n.issueBadId,
    IssueKind.notAllowed => l10n.issueNotAllowed,
    IssueKind.badBool => l10n.issueBadBool,
    IssueKind.duplicate => l10n.issueDuplicate,
    IssueKind.missingColumn => l10n.issueMissingColumn,
  };
  return '${i.field}: $problem';
}
