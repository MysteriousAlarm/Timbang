import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/router/redirect.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/sections.dart';
import '../../../shared/widgets/stat_grid.dart';
import '../../catalog/data/catalog_providers.dart';
import '../../catalog/domain/catalog_item.dart';
import 'admin_shell.dart';
import 'pilot_metrics.dart';

class AdminOverviewPage extends ConsumerWidget {
  const AdminOverviewPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final commodities = ref.watch(commoditiesProvider).value ?? const <Commodity>[];
    final markets = ref.watch(marketsProvider).value ?? const <Market>[];
    final demo = [...commodities, ...markets].where((i) => i.isDemo).length;
    final t = Theme.of(context).textTheme;

    return AdminPage(
      kicker: l10n.adminTitle,
      title: l10n.adminOverview,
      description: l10n.adminOverviewDesc,
      children: [
        if (demo > 0) ...[
          NoticeBanner(icon: Icons.science_outlined, message: l10n.demoDataBanner(demo)),
          const SizedBox(height: SharedTokens.space5),
        ],
        StatGrid(
          maxColumns: 3,
          stats: [
            Stat(
              label: l10n.kpiActiveCommodities,
              value: '${commodities.where((c) => c.active).length}',
              note: l10n.ofTotal(commodities.length),
              onTap: () => context.go(Routes.adminCommodities),
            ),
            Stat(
              label: l10n.kpiActiveMarkets,
              value: '${markets.where((m) => m.active).length}',
              note: l10n.ofTotal(markets.length),
              onTap: () => context.go(Routes.adminMarkets),
            ),
            Stat(label: l10n.kpiDemoItems, value: '$demo', note: l10n.kpiDemoNote),
          ],
        ),
        const SizedBox(height: SharedTokens.space6),
        const PilotMetricsSection(),
        const SizedBox(height: SharedTokens.space6),
        SectionHeader(kicker: l10n.dataSourcesKicker, title: l10n.dataSourcesTitle),
        const SizedBox(height: SharedTokens.space3),
        PanelCard(
          accent: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.dataSourcesBody, style: t.bodyMedium),
              const SizedBox(height: SharedTokens.space4),
              Wrap(
                spacing: SharedTokens.space3,
                runSpacing: SharedTokens.space3,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => context.go(Routes.adminCommodities),
                    icon: const Icon(Icons.upload_file),
                    label: Text(l10n.importCommoditiesCsv),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => context.go(Routes.adminMarkets),
                    icon: const Icon(Icons.upload_file),
                    label: Text(l10n.importMarketsCsv),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
