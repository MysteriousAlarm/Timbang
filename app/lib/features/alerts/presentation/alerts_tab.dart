import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/timbang_colors.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/sections.dart';
import '../../../shared/widgets/state_views.dart';
import '../../catalog/data/catalog_providers.dart';
import '../../catalog/domain/catalog_item.dart';
import '../../price_board/application/board_providers.dart';
import '../../price_board/domain/board_entry.dart';
import '../../price_board/presentation/board_widgets.dart';
import '../data/alert_repository.dart';
import '../domain/price_alert.dart';
import 'alert_sheet.dart';

class AlertsTab extends ConsumerWidget {
  const AlertsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final c = TimbangColors.of(context);
    final async = ref.watch(myAlertsProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('addAlert'),
        backgroundColor: c.cta,
        foregroundColor: c.onCta,
        onPressed: () => showAlertSheet(context),
        icon: const Icon(Icons.add_alert_outlined),
        label: Text(l10n.addAlert),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          SharedTokens.space4,
          SharedTokens.space5,
          SharedTokens.space4,
          96,
        ),
        children: [
          SectionHeader(kicker: l10n.alertsKicker, title: l10n.alertsTitle),
          const SizedBox(height: SharedTokens.space2),
          Text(l10n.alertsHelp, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: SharedTokens.space3),
          ...async.when(
            loading: () => [
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              ),
            ],
            error: (_, _) => [
              MessageView(
                icon: Icons.cloud_off,
                title: l10n.boardErrorTitle,
                body: l10n.errNetwork,
              ),
            ],
            data: (list) => list.isEmpty
                ? [
                    MessageView(
                      icon: Icons.notifications_none,
                      title: l10n.alertsEmptyTitle,
                      body: l10n.alertsEmptyBody,
                    ),
                  ]
                : [
                    for (final a in list) ...[
                      _AlertCard(key: Key('alert_${a.id}'), alert: a),
                      const SizedBox(height: SharedTokens.space3),
                    ],
                  ],
          ),
        ],
      ),
    );
  }
}

class _AlertCard extends ConsumerWidget {
  const _AlertCard({super.key, required this.alert});
  final PriceAlert alert;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final c = TimbangColors.of(context);
    final now = ref.watch(clockProvider).value ?? DateTime.now();
    final repo = ref.read(alertRepositoryProvider);
    String name = alert.commodityId;
    for (final x in ref.watch(commoditiesProvider).value ?? const <Commodity>[]) {
      if (x.id == alert.commodityId) name = x.nameFil;
    }
    String market = alert.marketId;
    for (final m in ref.watch(marketsProvider).value ?? const <Market>[]) {
      if (m.id == alert.marketId) market = m.name;
    }
    BoardEntry? current;
    for (final e
        in ref.watch(commodityBoardProvider(alert.commodityId)).value?.entries ??
            const <BoardEntry>[]) {
      if (e.marketId == alert.marketId) current = e;
    }
    final met = current != null && alert.isMet(current.medianPrice);
    return PanelCard(
      accent: alert.active && met,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                alert.direction == AlertDirection.above ? Icons.arrow_upward : Icons.arrow_downward,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: SharedTokens.space2),
              Expanded(child: Text('$name · $market', style: t.titleMedium)),
              Switch(value: alert.active, onChanged: (v) => repo.setActive(alert.id, v)),
            ],
          ),
          Text(
            alert.direction == AlertDirection.above
                ? l10n.alertWhenAbove(peso(alert.threshold))
                : l10n.alertWhenBelow(peso(alert.threshold)),
            style: t.bodyLarge,
          ),
          const SizedBox(height: SharedTokens.space1),
          Text(
            current == null
                ? l10n.noMedianYet
                : '${l10n.currentMedian(peso(current.medianPrice))} · ${ageLabel(l10n, now, current.latestReportAt)}',
            style: t.bodySmall,
          ),
          if (alert.lastTriggeredAt != null)
            Text(
              l10n.alertLastTriggered(
                peso(alert.lastTriggeredMedian ?? 0),
                ageLabel(l10n, now, alert.lastTriggeredAt!),
              ),
              style: t.bodySmall?.copyWith(color: c.textMuted),
            ),
          if (!alert.active)
            Text(l10n.alertPaused, style: t.bodySmall?.copyWith(fontWeight: FontWeight.w700)),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
              onPressed: () => repo.delete(alert.id),
              icon: const Icon(Icons.delete_outline),
              label: Text(l10n.delete),
            ),
          ),
        ],
      ),
    );
  }
}
