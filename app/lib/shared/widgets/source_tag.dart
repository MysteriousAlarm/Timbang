import 'package:flutter/material.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../core/theme/timbang_colors.dart';
import '../../features/reports/domain/price_report.dart';

/// Credits a price to its source tier (CLAUDE.md Section 12). Icon + word, neutral colors.
class SourceTag extends StatelessWidget {
  const SourceTag({super.key, required this.source, this.compact = false});
  final PriceSource source;

  /// Short label for dense tables ("Tagapag-ulat" instead of "Beripikadong tagapag-ulat").
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = TimbangColors.of(context);
    final (IconData icon, String label) = switch (source) {
      PriceSource.official => (Icons.account_balance_outlined, l10n.sourceOfficial),
      PriceSource.reporter => (
        Icons.verified_user_outlined,
        compact ? l10n.sourceReporterShort : l10n.sourceReporter,
      ),
      PriceSource.community => (Icons.groups_outlined, l10n.sourceCommunity),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.surfaceMuted,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Theme.of(context).colorScheme.onSurface),
          const SizedBox(width: 4),
          Text(label, style: Theme.of(context).textTheme.labelMedium),
        ],
      ),
    );
  }
}

String sourceLabel(AppLocalizations l10n, PriceSource s) => switch (s) {
  PriceSource.official => l10n.sourceOfficial,
  PriceSource.reporter => l10n.sourceReporter,
  PriceSource.community => l10n.sourceCommunity,
};
