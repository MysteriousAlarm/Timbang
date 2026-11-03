import 'package:flutter/material.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/timbang_colors.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/widgets/confidence_chip.dart';
import '../../../shared/widgets/source_tag.dart';
import '../../admin/presentation/admin_labels.dart';
import '../../reports/domain/price_report.dart';
import '../domain/board_entry.dart';

/// "Ngayon lang", "15 minuto na ang nakalipas", "3 oras ...", "2 araw ..."
String ageLabel(AppLocalizations l10n, DateTime now, DateTime t) {
  final d = now.difference(t);
  if (d.inMinutes < 1) return l10n.agoJustNow;
  if (d.inHours < 1) return l10n.agoMinutes(d.inMinutes);
  if (d.inDays < 1) return l10n.agoHours(d.inHours);
  return l10n.agoDays(d.inDays);
}

/// Highest tier present, which is what the confidence label rests on.
PriceSource topSource(BoardEntry e) => e.official > 0
    ? PriceSource.official
    : e.reporter > 0
    ? PriceSource.reporter
    : PriceSource.community;

/// Arrow + word; never color alone.
class TrendLabel extends StatelessWidget {
  const TrendLabel({super.key, required this.trend});
  final Trend trend;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final (IconData icon, String label) = switch (trend) {
      Trend.up => (Icons.arrow_upward, l10n.trendUp),
      Trend.down => (Icons.arrow_downward, l10n.trendDown),
      Trend.flat => (Icons.trending_flat, l10n.trendFlat),
    };
    final color = Theme.of(context).colorScheme.onSurface;
    return Semantics(
      label: l10n.trendSemantics(label),
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 2),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

/// Gray "Luma na" tag for entries with no report in 24 hours.
class StaleTag extends StatelessWidget {
  const StaleTag({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = TimbangColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: c.textMuted),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.history, size: 16, color: c.textMuted),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              l10n.staleTag,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(color: c.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

/// Big tabular price with its unit.
class PriceText extends StatelessWidget {
  const PriceText({super.key, required this.price, required this.unit, this.large = false});
  final double price;
  final String unit;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          peso(price),
          style: (large ? t.headlineMedium : t.titleLarge)?.copyWith(
            fontFeatures: tabularFigures,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(l10n.perUnit(unitShort(l10n, unit)), style: t.bodySmall),
      ],
    );
  }
}

/// One line of the price board. Always shows median, confidence, source and age.
class PriceRowCard extends StatelessWidget {
  const PriceRowCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.entry,
    required this.now,
    this.onTap,
    this.badge,
  });

  final String title;
  final String subtitle;
  final BoardEntry entry;
  final DateTime now;
  final VoidCallback? onTap;

  /// Extra label such as "Pinakamababa" or "Iyong bayan".
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final c = TimbangColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    final stale = entry.isStale(now);
    return Material(
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(SharedTokens.radius),
        side: BorderSide(color: c.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(SharedTokens.radius),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            SharedTokens.space4,
            SharedTokens.space3,
            SharedTokens.space3,
            SharedTokens.space3,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: t.titleMedium),
                        Text(subtitle, style: t.bodySmall),
                        const SizedBox(height: SharedTokens.space2),
                        Wrap(
                          spacing: SharedTokens.space2,
                          runSpacing: SharedTokens.space1,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            ConfidenceChip(confidence: entry.confidence),
                            if (stale) const StaleTag(),
                            ?badge,
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: SharedTokens.space3),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      PriceText(price: entry.medianPrice, unit: entry.unit),
                      const SizedBox(height: SharedTokens.space1),
                      TrendLabel(trend: entry.trend),
                    ],
                  ),
                  if (onTap != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 4, top: 8),
                      child: Icon(Icons.chevron_right, color: c.textMuted),
                    ),
                ],
              ),
              const SizedBox(height: SharedTokens.space2),
              const Divider(),
              const SizedBox(height: SharedTokens.space2),
              Wrap(
                spacing: SharedTokens.space2,
                runSpacing: SharedTokens.space1,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SourceTag(source: topSource(entry), compact: true),
                  Text(l10n.reportCount(entry.reportCount), style: t.bodySmall),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.schedule, size: 15, color: c.textMuted),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          l10n.updatedAgo(ageLabel(l10n, now, entry.latestReportAt)),
                          style: t.bodySmall?.copyWith(
                            fontWeight: stale ? FontWeight.w700 : null,
                            color: stale ? scheme.onSurface : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
