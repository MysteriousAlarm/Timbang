import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/timbang_colors.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/widgets/sections.dart';
import '../data/admin_repository.dart';

/// Section 12 pilot metrics: price age per market, active farmers, listings, inquiries per listing.
class PilotMetricsSection extends ConsumerWidget {
  const PilotMetricsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final async = ref.watch(pilotMetricsProvider);
    String fmt(Object? v, [String suffix = '']) => v == null ? '—' : '$v$suffix';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          kicker: l10n.metricsKicker,
          title: l10n.metricsTitle,
          trailing: IconButton(
            tooltip: l10n.refresh,
            onPressed: () => ref.invalidate(pilotMetricsProvider),
            icon: const Icon(Icons.refresh),
          ),
        ),
        const SizedBox(height: SharedTokens.space3),
        async.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => NoticeBanner(
            icon: Icons.error_outline,
            message: l10n.metricsError,
            kind: NoticeKind.error,
          ),
          data: (m) {
            final perMarket = (m['perMarket'] as List?) ?? const [];
            final reports = Map<String, dynamic>.from((m['reports7d'] as Map?) ?? const {});
            final tiles = [
              _Metric(
                label: l10n.metricPriceAge,
                value: fmt(m['medianPriceAgeHours'], ' h'),
                note: l10n.metricPriceAgeNote,
              ),
              _Metric(
                label: l10n.metricActiveFarmers,
                value: fmt(m['activeFarmers30d']),
                note: l10n.metricOfFarmers(fmt(m['farmersTotal'])),
              ),
              _Metric(
                label: l10n.metricListings,
                value: fmt(m['listings30d']),
                note: l10n.metricLast30,
              ),
              _Metric(
                label: l10n.metricInquiriesPerListing,
                value: fmt(m['inquiriesPerListing']),
                note: l10n.metricInquiries(fmt(m['inquiries30d'])),
              ),
            ];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LayoutBuilder(
                  builder: (context, box) {
                    final cols = box.maxWidth >= 900 ? 4 : 2;
                    return GridView.count(
                      crossAxisCount: cols,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: SharedTokens.space3,
                      mainAxisSpacing: SharedTokens.space3,
                      childAspectRatio: cols == 4 ? 1.9 : 1.6,
                      children: tiles,
                    );
                  },
                ),
                const SizedBox(height: SharedTokens.space3),
                Text(
                  l10n.metricReports7d(
                    '${reports['official'] ?? 0}',
                    '${reports['reporter'] ?? 0}',
                    '${reports['community'] ?? 0}',
                  ),
                  style: t.bodyMedium,
                ),
                const SizedBox(height: SharedTokens.space3),
                if (perMarket.isNotEmpty)
                  PanelCard(
                    padding: EdgeInsets.zero,
                    child: DataTable(
                      columns: [
                        DataColumn(label: Text(l10n.colMarket.toUpperCase())),
                        DataColumn(numeric: true, label: Text(l10n.metricEntries.toUpperCase())),
                        DataColumn(numeric: true, label: Text(l10n.metricMedianAge.toUpperCase())),
                        DataColumn(numeric: true, label: Text(l10n.metricFresh.toUpperCase())),
                      ],
                      rows: [
                        for (final raw in perMarket)
                          () {
                            final r = Map<String, dynamic>.from(raw as Map);
                            return DataRow(
                              cells: [
                                DataCell(Text('${r['name']}')),
                                DataCell(
                                  Text(
                                    '${r['entries']}',
                                    style: const TextStyle(fontFeatures: tabularFigures),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    fmt(r['medianAgeHours'], ' h'),
                                    style: const TextStyle(fontFeatures: tabularFigures),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    fmt(r['freshShare'], '%'),
                                    style: const TextStyle(fontFeatures: tabularFigures),
                                  ),
                                ),
                              ],
                            );
                          }(),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, required this.note});
  final String label;
  final String value;
  final String note;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(SharedTokens.space4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(SharedTokens.radius),
        border: Border.all(color: TimbangColors.of(context).border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label.toUpperCase(), style: t.labelSmall, maxLines: 2),
          Text(value, style: t.headlineMedium?.copyWith(fontFeatures: tabularFigures)),
          Text(note, style: t.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}
