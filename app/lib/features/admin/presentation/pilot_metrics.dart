import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/widgets/sections.dart';
import '../../../shared/widgets/stat_grid.dart';
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
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                StatGrid(
                  stats: [
                    Stat(
                      label: l10n.metricPriceAge,
                      value: fmt(m['medianPriceAgeHours'], ' h'),
                      note: l10n.metricPriceAgeNote,
                    ),
                    Stat(
                      label: l10n.metricActiveFarmers,
                      value: fmt(m['activeFarmers30d']),
                      note: l10n.metricOfFarmers(fmt(m['farmersTotal'])),
                    ),
                    Stat(
                      label: l10n.metricListings,
                      value: fmt(m['listings30d']),
                      note: l10n.metricLast30,
                    ),
                    Stat(
                      label: l10n.metricInquiriesPerListing,
                      value: fmt(m['inquiriesPerListing']),
                      note: l10n.metricInquiries(fmt(m['inquiries30d'])),
                    ),
                  ],
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
                  LayoutBuilder(
                    builder: (context, box) {
                      final rows = [
                        for (final raw in perMarket) Map<String, dynamic>.from(raw as Map),
                      ];
                      if (box.maxWidth < 600) {
                        return PanelCard(
                          padding: EdgeInsets.zero,
                          child: Column(
                            children: [
                              for (var i = 0; i < rows.length; i++) ...[
                                if (i > 0) const Divider(height: 1),
                                ListTile(
                                  title: Text('${rows[i]['name']}'),
                                  subtitle: Text(
                                    '${l10n.metricEntries}: ${rows[i]['entries']} · '
                                    '${l10n.metricFresh}: ${fmt(rows[i]['freshShare'], '%')}',
                                  ),
                                  trailing: Text(
                                    fmt(rows[i]['medianAgeHours'], ' h'),
                                    style: t.titleMedium?.copyWith(fontFeatures: tabularFigures),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      }
                      return PanelCard(
                        padding: EdgeInsets.zero,
                        child: DataTable(
                          columns: [
                            DataColumn(label: Text(l10n.colMarket)),
                            DataColumn(numeric: true, label: Text(l10n.metricEntries)),
                            DataColumn(numeric: true, label: Text(l10n.metricMedianAge)),
                            DataColumn(numeric: true, label: Text(l10n.metricFresh)),
                          ],
                          rows: [
                            for (final r in rows)
                              DataRow(
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
                              ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
