import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/router/redirect.dart';
import '../../../core/theme/timbang_colors.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/confidence_chip.dart';
import '../../../shared/widgets/sections.dart';
import '../../../shared/widgets/source_tag.dart';
import '../../../shared/widgets/state_views.dart';
import '../../admin/presentation/admin_labels.dart';
import '../../alerts/presentation/alert_sheet.dart';
import '../../auth/application/session.dart';
import '../../catalog/data/catalog_providers.dart';
import '../../catalog/domain/catalog_item.dart';
import '../application/board_providers.dart';
import '../domain/board_entry.dart';
import 'board_widgets.dart';

/// Commodity detail: price at the selected market + the same commodity across markets.
class CommodityDetailScreen extends ConsumerWidget {
  const CommodityDetailScreen({super.key, required this.commodityId});
  final String commodityId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final c = TimbangColors.of(context);
    final commodities = ref.watch(commoditiesProvider).value ?? const <Commodity>[];
    Commodity? commodity;
    for (final x in commodities) {
      if (x.id == commodityId) commodity = x;
    }
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 68,
        leading: BackButton(
          onPressed: () => context.canPop() ? context.pop() : context.go(Routes.prices),
        ),
        title: Text(commodity?.nameFil ?? l10n.navPrices),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: Container(height: 4, color: c.highlight),
        ),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: commodity == null
              ? MessageView(
                  icon: Icons.search_off,
                  title: l10n.commodityNotFound,
                  body: l10n.commodityNotFoundBody,
                )
              : _Body(commodity: commodity),
        ),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.commodity});
  final Commodity commodity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final c = TimbangColors.of(context);
    final now = ref.watch(clockProvider).value ?? DateTime.now();
    final session = ref.watch(sessionProvider);
    final town = session is SignedIn ? session.profile.municipality : null;
    final selected = ref.watch(activeMarketProvider);
    final markets = ref.watch(orderedMarketsProvider);
    final board = ref.watch(commodityBoardProvider(commodity.id));

    if (board.isLoading && !board.hasValue) {
      return const Center(child: CircularProgressIndicator());
    }
    if (board.hasError && !board.hasValue) {
      return MessageView(icon: Icons.cloud_off, title: l10n.boardErrorTitle, body: l10n.errNetwork);
    }
    final snap = board.value!;
    final rows = compareRows(snap.entries, markets, town);
    BoardEntry? mine;
    for (final r in rows) {
      if (r.market.id == selected?.id) mine = r.entry;
    }
    final fresh = rows.where((r) => !r.entry.isStale(now)).toList();
    final cheapest = fresh.isEmpty
        ? null
        : fresh.reduce((a, b) => a.entry.medianPrice <= b.entry.medianPrice ? a : b).market.id;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        SharedTokens.space4,
        SharedTokens.space5,
        SharedTokens.space4,
        SharedTokens.space6,
      ),
      children: [
        Text(commodity.category.toUpperCase(), style: t.labelSmall),
        Text('${commodity.nameFil} · ${commodity.nameEn}', style: t.headlineSmall),
        Text(l10n.perUnit(unitShort(l10n, commodity.unit)), style: t.bodyMedium),
        const SizedBox(height: SharedTokens.space4),
        if (snap.fromCache) ...[
          NoticeBanner(icon: Icons.wifi_off, message: l10n.offlineBanner, kind: NoticeKind.info),
          const SizedBox(height: SharedTokens.space3),
        ],
        if (snap.hasDemo) ...[
          NoticeBanner(icon: Icons.science_outlined, message: l10n.demoPricesBanner),
          const SizedBox(height: SharedTokens.space3),
        ],
        if (selected != null) _Headline(entry: mine, marketName: selected.name, now: now),
        const SizedBox(height: SharedTokens.space6),
        SectionHeader(kicker: l10n.compareKicker, title: l10n.compareTitle),
        const SizedBox(height: SharedTokens.space2),
        Text(l10n.compareHelp, style: t.bodySmall),
        const SizedBox(height: SharedTokens.space3),
        if (rows.isEmpty)
          PanelCard(
            child: Text(l10n.compareEmpty, style: t.bodyMedium, textAlign: TextAlign.center),
          )
        else
          for (final r in rows) ...[
            PriceRowCard(
              key: Key('cmp_${r.market.id}'),
              title: r.market.name,
              subtitle: '${r.market.municipality} · ${marketTypeLabel(l10n, r.market.type)}',
              entry: r.entry,
              now: now,
              badge: Wrap(
                spacing: SharedTokens.space2,
                children: [
                  if (r.ownTown) _Tag(icon: Icons.home_outlined, label: l10n.ownTownTag),
                  if (r.market.id == cheapest && rows.length > 1)
                    _Tag(icon: Icons.south, label: l10n.cheapestTag, strong: true),
                  if (mine != null && r.market.id != selected?.id)
                    _Tag(
                      icon: r.entry.medianPrice >= mine.medianPrice ? Icons.add : Icons.remove,
                      label: _diff(l10n, r.entry.medianPrice - mine.medianPrice),
                    ),
                ],
              ),
            ),
            const SizedBox(height: SharedTokens.space3),
          ],
        const SizedBox(height: SharedTokens.space3),
        OutlinedButton.icon(
          key: const Key('setAlert'),
          onPressed: () =>
              showAlertSheet(context, commodityId: commodity.id, marketId: selected?.id),
          icon: const Icon(Icons.notifications_active_outlined),
          label: Text(l10n.setAlertHere),
        ),
        const SizedBox(height: SharedTokens.space2),
        OutlinedButton.icon(
          onPressed: () => context.push(Routes.report),
          icon: const Icon(Icons.edit_note),
          label: Text(l10n.reportThisPrice),
        ),
        const SizedBox(height: SharedTokens.space3),
        Text(l10n.landingDisclaimer, style: t.bodySmall, textAlign: TextAlign.center),
        const SizedBox(height: SharedTokens.space2),
        Center(child: Icon(Icons.balance, color: c.textMuted)),
      ],
    );
  }

  String _diff(AppLocalizations l10n, double d) {
    if (d.abs() < 0.005) return l10n.sameAsYours;
    return d > 0 ? l10n.higherBy(peso(d)) : l10n.lowerBy(peso(-d));
  }
}

class _Headline extends StatelessWidget {
  const _Headline({required this.entry, required this.marketName, required this.now});
  final BoardEntry? entry;
  final String marketName;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final c = TimbangColors.of(context);
    final e = entry;
    return PanelCard(
      accent: true,
      padding: const EdgeInsets.all(SharedTokens.space5),
      child: e == null
          ? Text(l10n.noPriceAtMarket(marketName), style: t.bodyLarge)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.medianAt(marketName).toUpperCase(), style: t.labelSmall),
                const SizedBox(height: SharedTokens.space2),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            peso(e.medianPrice),
                            style: t.displaySmall?.copyWith(
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                          Text(l10n.perUnit(unitShort(l10n, e.unit)), style: t.bodyMedium),
                        ],
                      ),
                    ),
                    TrendLabel(trend: e.trend),
                  ],
                ),
                const SizedBox(height: SharedTokens.space3),
                Wrap(
                  spacing: SharedTokens.space2,
                  runSpacing: SharedTokens.space2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ConfidenceChip(confidence: e.confidence),
                    if (e.isStale(now)) const StaleTag(),
                    SourceTag(source: topSource(e)),
                  ],
                ),
                const SizedBox(height: SharedTokens.space3),
                Text(
                  '${l10n.reportCount(e.reportCount)} · ${l10n.updatedAgo(ageLabel(l10n, now, e.latestReportAt))}',
                  style: t.bodySmall,
                ),
                if (e.previousMedian != null)
                  Text(l10n.yesterdayMedian(peso(e.previousMedian!)), style: t.bodySmall),
                if (e.isStale(now)) ...[
                  const SizedBox(height: SharedTokens.space2),
                  Text(l10n.staleExplain, style: t.bodySmall?.copyWith(color: c.textMuted)),
                ],
              ],
            ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.icon, required this.label, this.strong = false});
  final IconData icon;
  final String label;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final c = TimbangColors.of(context);
    final fill = strong ? c.primaryTint : c.surfaceMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: fill,
        border: Border.all(color: strong ? Theme.of(context).colorScheme.primary : c.border),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Theme.of(context).colorScheme.onSurface),
          const SizedBox(width: 3),
          Text(label, style: Theme.of(context).textTheme.labelMedium),
        ],
      ),
    );
  }
}
