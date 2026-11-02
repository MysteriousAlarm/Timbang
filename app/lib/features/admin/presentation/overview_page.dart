import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/router/redirect.dart';
import '../../../core/theme/timbang_colors.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/widgets/sections.dart';
import '../../catalog/data/catalog_providers.dart';
import '../../catalog/domain/catalog_item.dart';
import 'admin_shell.dart';

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
        LayoutBuilder(
          builder: (context, box) {
            final tiles = [
              _Kpi(
                icon: Icons.eco_outlined,
                label: l10n.kpiActiveCommodities,
                value: commodities.where((c) => c.active).length,
                total: commodities.length,
                onTap: () => context.go(Routes.adminCommodities),
              ),
              _Kpi(
                icon: Icons.storefront_outlined,
                label: l10n.kpiActiveMarkets,
                value: markets.where((m) => m.active).length,
                total: markets.length,
                onTap: () => context.go(Routes.adminMarkets),
              ),
              _Kpi(
                icon: Icons.science_outlined,
                label: l10n.kpiDemoItems,
                value: demo,
                note: l10n.kpiDemoNote,
              ),
            ];
            if (box.maxWidth < 720) {
              return Column(
                children: [
                  for (final k in tiles)
                    Padding(
                      padding: const EdgeInsets.only(bottom: SharedTokens.space3),
                      child: k,
                    ),
                ],
              );
            }
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < tiles.length; i++) ...[
                    if (i > 0) const SizedBox(width: SharedTokens.space4),
                    Expanded(child: tiles[i]),
                  ],
                ],
              ),
            );
          },
        ),
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

class _Kpi extends StatelessWidget {
  const _Kpi({
    required this.icon,
    required this.label,
    required this.value,
    this.total,
    this.note,
    this.onTap,
  });

  final String? note;

  final IconData icon;
  final String label;
  final int value;
  final int? total;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = TimbangColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
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
          padding: const EdgeInsets.all(SharedTokens.space5),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: c.primaryTint,
                  borderRadius: BorderRadius.circular(SharedTokens.radius),
                ),
                child: Icon(icon, color: scheme.primary, size: 28),
              ),
              const SizedBox(width: SharedTokens.space4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label.toUpperCase(), style: t.labelSmall),
                    Text('$value', style: t.headlineMedium?.copyWith(fontFeatures: tabularFigures)),
                    if (total != null) Text(l10n.ofTotal(total!), style: t.bodySmall),
                    if (note != null) Text(note!, style: t.bodySmall),
                  ],
                ),
              ),
              if (onTap != null) Icon(Icons.chevron_right, color: c.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
