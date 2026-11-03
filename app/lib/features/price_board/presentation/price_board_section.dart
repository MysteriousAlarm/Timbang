import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/router/redirect.dart';
import '../../../core/theme/timbang_colors.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/sections.dart';
import '../../admin/presentation/admin_labels.dart';
import '../../catalog/data/catalog_providers.dart';
import '../../catalog/domain/catalog_item.dart';
import '../../catalog/presentation/commodity_names.dart';
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

    if (market == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: SharedTokens.space4),
        child: _Empty(
          icon: Icons.storefront_outlined,
          title: l10n.noMarketsTitle,
          body: l10n.noMarketsBody,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Masthead(market: market, now: now),
        _Board(market: market, now: now),
      ],
    );
  }
}

/// Bulletin masthead: what this is, which market (tap to change), and the date, over a
/// double rule like a printed price bulletin.
class _Masthead extends ConsumerWidget {
  const _Masthead({required this.market, required this.now});
  final Market market;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final c = TimbangColors.of(context);
    final ink = Theme.of(context).colorScheme.onSurface;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final board = ref.watch(marketBoardProvider(market.id)).value;
    final latest = board == null || board.entries.isEmpty
        ? null
        : board.entries.map((e) => e.latestReportAt).reduce((a, b) => a.isAfter(b) ? a : b);
    final dateline = [
      DateFormat.yMMMMEEEEd(locale).format(now),
      if (latest != null) l10n.asOf(DateFormat.jm(locale).format(latest)),
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SharedTokens.space4,
        SharedTokens.space5,
        SharedTokens.space4,
        SharedTokens.space2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.bulletinKicker, style: t.labelMedium?.copyWith(color: c.textMuted)),
          const SizedBox(height: SharedTokens.space1),
          _MarketPicker(market: market),
          const SizedBox(height: SharedTokens.space1),
          Text(dateline, style: t.bodySmall),
          const SizedBox(height: SharedTokens.space3),
          Container(height: 2, color: ink),
          const SizedBox(height: 2),
          Container(height: 1, color: ink),
        ],
      ),
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
    return Semantics(
      button: true,
      label: l10n.marketChangeSemantics(market.name),
      excludeSemantics: true,
      child: InkWell(
        key: const Key('marketPicker'),
        borderRadius: BorderRadius.circular(SharedTokens.radiusSmall),
        onTap: () => _pick(context, ref),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: SharedTokens.minTouchTarget),
          child: Row(
            children: [
              Flexible(child: Text(market.name, style: t.headlineSmall)),
              const SizedBox(width: SharedTokens.space2),
              Container(
                padding: const EdgeInsets.fromLTRB(8, 2, 4, 2),
                decoration: BoxDecoration(
                  border: Border.all(color: c.info),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(l10n.change, style: t.labelMedium?.copyWith(color: c.info)),
                    Icon(Icons.expand_more, size: 18, color: c.info),
                  ],
                ),
              ),
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
    final groups = <String, List<BoardRow>>{};
    for (final r in rows) {
      groups.putIfAbsent(r.commodity.category.trim(), () => []).add(r);
    }
    final keys = groups.keys.toList()..sort();
    const pad = EdgeInsets.symmetric(horizontal: SharedTokens.space4);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (snap.fromCache)
          Padding(
            padding: pad.copyWith(top: SharedTokens.space3),
            child: NoticeBanner(
              icon: Icons.wifi_off,
              message: l10n.offlineBanner,
              kind: NoticeKind.info,
            ),
          ),
        if (snap.hasDemo)
          Padding(
            padding: pad.copyWith(top: SharedTokens.space3),
            child: NoticeBanner(icon: Icons.science_outlined, message: l10n.demoPricesBanner),
          ),
        if (rows.isEmpty)
          Padding(
            padding: pad.copyWith(top: SharedTokens.space3),
            child: _Empty(
              icon: Icons.price_change_outlined,
              title: l10n.priceBoardEmptyTitle,
              body: l10n.priceBoardEmptyBody,
            ),
          )
        else
          BulletinList(
            groups: [
              for (final k in keys)
                (
                  keys.length > 1 ? k : '',
                  [
                    for (final r in groups[k]!)
                      PriceRowCard(
                        key: Key('row_${r.commodity.id}'),
                        title: r.commodity.nameIn(context),
                        subtitle: r.commodity.altNameIn(context),
                        entry: r.entry,
                        now: now,
                        onTap: () => context.push(Routes.commodity(r.commodity.id)),
                      ),
                  ],
                ),
            ],
          ),
        Padding(
          padding: pad.copyWith(top: SharedTokens.space3),
          child: Text(l10n.boardFootnote, style: Theme.of(context).textTheme.bodySmall),
        ),
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
