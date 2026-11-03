import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/router/redirect.dart';
import '../../../core/theme/timbang_colors.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/sections.dart';
import '../../admin/presentation/admin_labels.dart';
import '../../catalog/data/catalog_providers.dart';
import '../../catalog/domain/catalog_item.dart';
import '../application/board_providers.dart';
import 'board_widgets.dart';

/// Home: today's prices at the chosen market (default: first market in the user's town).
class PriceBoardSection extends ConsumerWidget {
  const PriceBoardSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final market = ref.watch(activeMarketProvider);
    final now = ref.watch(clockProvider).value ?? DateTime.now();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(kicker: l10n.pricesKicker, title: l10n.pricesTitle),
        const SizedBox(height: SharedTokens.space3),
        if (market == null)
          _Empty(
            icon: Icons.storefront_outlined,
            title: l10n.noMarketsTitle,
            body: l10n.noMarketsBody,
          )
        else ...[
          _MarketPicker(market: market),
          const SizedBox(height: SharedTokens.space3),
          _Board(market: market, now: now),
        ],
      ],
    );
  }
}

class _MarketPicker extends ConsumerWidget {
  const _MarketPicker({required this.market});
  final Market market;

  Future<void> _pick(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final markets = ref.read(orderedMarketsProvider);
    final chosen = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.7),
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: Text(l10n.chooseMarket, style: Theme.of(ctx).textTheme.titleLarge),
              ),
              for (final m in markets)
                ListTile(
                  leading: Icon(
                    m.id == market.id ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                    color: m.id == market.id ? Theme.of(ctx).colorScheme.primary : null,
                  ),
                  title: Text(m.name),
                  subtitle: Text('${m.municipality} · ${marketTypeLabel(l10n, m.type)}'),
                  onTap: () => Navigator.pop(ctx, m.id),
                ),
            ],
          ),
        ),
      ),
    );
    if (chosen != null) ref.read(selectedMarketIdProvider.notifier).select(chosen);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final c = TimbangColors.of(context);
    final t = Theme.of(context).textTheme;
    return Material(
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(SharedTokens.radius),
        side: BorderSide(color: Theme.of(context).colorScheme.primary, width: 1.5),
      ),
      child: InkWell(
        key: const Key('marketPicker'),
        borderRadius: BorderRadius.circular(SharedTokens.radius),
        onTap: () => _pick(context, ref),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: SharedTokens.space4, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.storefront, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: SharedTokens.space3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.marketLabel.toUpperCase(), style: t.labelSmall),
                    Text(market.name, style: t.titleMedium),
                  ],
                ),
              ),
              Text(l10n.change, style: t.labelLarge?.copyWith(color: c.info)),
              Icon(Icons.expand_more, color: c.info),
            ],
          ),
        ),
      ),
    );
  }
}

class _Board extends ConsumerWidget {
  const _Board({required this.market, required this.now});
  final Market market;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final board = ref.watch(marketBoardProvider(market.id));
    final commodities = ref.watch(commoditiesProvider).value ?? const <Commodity>[];

    if (board.isLoading && !board.hasValue) {
      return const Padding(
        padding: EdgeInsets.all(SharedTokens.space6),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (board.hasError && !board.hasValue) {
      return _Empty(icon: Icons.cloud_off, title: l10n.boardErrorTitle, body: l10n.errNetwork);
    }
    final snap = board.value!;
    final rows = joinRows(snap.entries, commodities);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (snap.fromCache) ...[
          NoticeBanner(icon: Icons.wifi_off, message: l10n.offlineBanner, kind: NoticeKind.info),
          const SizedBox(height: SharedTokens.space3),
        ],
        if (snap.hasDemo) ...[
          NoticeBanner(icon: Icons.science_outlined, message: l10n.demoPricesBanner),
          const SizedBox(height: SharedTokens.space3),
        ],
        if (rows.isEmpty)
          _Empty(
            icon: Icons.price_change_outlined,
            title: l10n.priceBoardEmptyTitle,
            body: l10n.priceBoardEmptyBody,
          )
        else
          for (final r in rows) ...[
            PriceRowCard(
              key: Key('row_${r.commodity.id}'),
              title: r.commodity.nameFil,
              subtitle: r.commodity.nameEn,
              entry: r.entry,
              now: now,
              onTap: () => context.push(Routes.commodity(r.commodity.id)),
            ),
            const SizedBox(height: SharedTokens.space3),
          ],
        Text(l10n.boardFootnote, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.icon, required this.title, required this.body});
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return PanelCard(
      padding: const EdgeInsets.symmetric(
        horizontal: SharedTokens.space5,
        vertical: SharedTokens.space6,
      ),
      child: Column(
        children: [
          Icon(icon, size: 48, color: TimbangColors.of(context).textMuted),
          const SizedBox(height: SharedTokens.space3),
          Text(title, style: t.titleMedium, textAlign: TextAlign.center),
          const SizedBox(height: SharedTokens.space1),
          Text(body, style: t.bodyMedium, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
