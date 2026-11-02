import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/timbang_colors.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/widgets/sections.dart';
import '../../../shared/widgets/source_tag.dart';
import '../../../shared/widgets/state_views.dart';
import '../../catalog/data/catalog_providers.dart';
import '../../catalog/domain/catalog_item.dart';
import '../../reports/data/price_report_repository.dart';
import '../../reports/domain/price_report.dart';
import 'admin_labels.dart';
import 'admin_shell.dart';
import 'official_import_dialog.dart';

/// Admin: import official prices and watch incoming reports.
class AdminPricesPage extends ConsumerWidget {
  const AdminPricesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final c = TimbangColors.of(context);
    final reports = ref.watch(recentReportsProvider);
    return AdminPage(
      kicker: l10n.adminPricesKicker,
      title: l10n.adminPrices,
      description: l10n.adminPricesDesc,
      actions: [
        FilledButton.icon(
          key: const Key('importOfficial'),
          style: FilledButton.styleFrom(backgroundColor: c.cta, foregroundColor: c.onCta),
          onPressed: () => showOfficialImportDialog(context),
          icon: const Icon(Icons.upload_file),
          label: Text(l10n.importOfficialPrices),
        ),
      ],
      children: [
        SectionHeader(kicker: l10n.recentReportsKicker, title: l10n.recentReportsTitle),
        const SizedBox(height: SharedTokens.space3),
        PanelCard(
          padding: EdgeInsets.zero,
          child: reports.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(SharedTokens.space6),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, _) =>
                MessageView(icon: Icons.cloud_off, title: l10n.errGeneric, body: l10n.errNetwork),
            data: (list) => list.isEmpty
                ? MessageView(
                    icon: Icons.receipt_long_outlined,
                    title: l10n.noReportsTitle,
                    body: l10n.noReportsBody,
                  )
                : _ReportsTable(reports: list),
          ),
        ),
      ],
    );
  }
}

class _ReportsTable extends ConsumerWidget {
  const _ReportsTable({required this.reports});
  final List<PriceReport> reports;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final c = TimbangColors.of(context);
    final commodities = {
      for (final x in ref.watch(commoditiesProvider).value ?? const <Commodity>[]) x.id: x,
    };
    final markets = {for (final x in ref.watch(marketsProvider).value ?? const <Market>[]) x.id: x};
    final fmt = DateFormat('MMM d, h:mm a', Localizations.localeOf(context).toLanguageTag());

    Widget status(ReportStatus s) {
      final (Color fill, Color on, IconData icon, String label) = switch (s) {
        ReportStatus.valid => (
          c.confidenceHigh,
          c.onConfidenceHigh,
          Icons.check_circle,
          l10n.statusValid,
        ),
        ReportStatus.outlier => (
          c.confidenceMedium,
          c.onConfidenceMedium,
          Icons.report_outlined,
          l10n.statusOutlier,
        ),
        ReportStatus.rejected => (
          c.confidenceLow,
          c.onConfidenceLow,
          Icons.block,
          l10n.statusRejected,
        ),
      };
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(999)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: on),
            const SizedBox(width: 4),
            Text(label, style: t.labelMedium?.copyWith(color: on)),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, box) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: box.maxWidth),
          child: DataTable(
            columnSpacing: 28,
            columns: [
              for (final h in [
                l10n.colTime,
                l10n.colCommodity,
                l10n.colMarket,
                l10n.colPrice,
                l10n.colSource,
                l10n.colStatus,
              ])
                DataColumn(label: Text(h.toUpperCase())),
            ],
            rows: [
              for (final r in reports)
                DataRow(
                  cells: [
                    DataCell(
                      Text(
                        fmt.format(r.timestamp),
                        style: t.bodySmall?.copyWith(color: t.bodyMedium?.color),
                      ),
                    ),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            commodities[r.commodityId]?.nameFil ?? r.commodityId,
                            style: t.titleSmall,
                          ),
                          if (r.isDemo) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: SharedTokens.notice,
                                border: Border.all(color: SharedTokens.noticeRule),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'DEMO',
                                style: t.labelSmall?.copyWith(color: SharedTokens.onNotice),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    DataCell(Text(markets[r.marketId]?.name ?? r.marketId)),
                    DataCell(
                      Text(
                        '₱${r.price.toStringAsFixed(2)} / ${unitLabel(l10n, r.unit)}',
                        style: t.titleSmall?.copyWith(fontFeatures: tabularFigures),
                      ),
                    ),
                    DataCell(
                      Tooltip(
                        message: r.sourceNote ?? '',
                        child: SourceTag(source: r.source, compact: true),
                      ),
                    ),
                    DataCell(status(r.status)),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
