import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/router/redirect.dart';
import '../../../core/theme/timbang_colors.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/widgets/sections.dart';
import '../../admin/presentation/admin_labels.dart';
import '../../catalog/data/catalog_providers.dart';
import '../../catalog/domain/catalog_item.dart';
import '../../catalog/presentation/commodity_names.dart';
import '../application/board_providers.dart';
import '../domain/board_entry.dart';
import 'board_widgets.dart';

/// Home price bulletin. Default: the whole province (every market summarised per commodity).
/// With a municipality chosen in the header: that town's market(s).
class PriceBoardSection extends ConsumerWidget {
  const PriceBoardSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final scope = ref.watch(priceScopeProvider);
    final now = ref.watch(clockProvider).value ?? DateTime.now();
    const pad = EdgeInsets.symmetric(horizontal: SharedTokens.space4);

    if (scope == null) {
      final markets = ref.watch(orderedMarketsProvider);
      if (markets.isEmpty) {
        return Padding(
          padding: pad,
          child: _Empty(
            icon: Icons.storefront_outlined,
            title: l10n.noMarketsTitle,
            body: l10n.noMarketsBody,
          ),
        );
      }
      final board = ref.watch(provinceBoardProvider);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Masthead(
            place: 'Nueva Vizcaya',
            sub: Text(
              '${l10n.scopeProvinceSub} · ${l10n.townMarketsCount(markets.length)}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            now: now,
            snapshot: board.value,
          ),
          _ProvinceBoard(now: now),
        ],
      );
    }

    final scoped = ref.watch(scopedMarketsProvider);
    if (scoped.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Masthead(place: scope, now: now),
          Padding(
            padding: pad.copyWith(top: SharedTokens.space3),
            child: _Empty(
              icon: Icons.storefront_outlined,
              title: l10n.noMarketsInTown(scope),
              body: l10n.noMarketsInTownBody,
              action: OutlinedButton.icon(
                key: const Key('seeProvince'),
                onPressed: () => ref.read(priceScopeProvider.notifier).choose(null),
                icon: const Icon(Icons.map_outlined),
                label: Text(l10n.seeProvince),
              ),
            ),
          ),
        ],
      );
    }
    final market = ref.watch(activeMarketProvider)!;
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Masthead(
          place: scope,
          sub: scoped.length > 1
              ? _MarketPicker(market: market, markets: scoped)
              : Text(market.name, style: t.bodyMedium),
          now: now,
          snapshot: ref.watch(marketBoardProvider(market.id)).value,
        ),
        _Board(market: market, now: now),
      ],
    );
  }
}

/// Bulletin masthead: what this is, the place, the market line, and the date, over a
/// double rule like a printed price bulletin.
class _Masthead extends StatelessWidget {
  const _Masthead({required this.place, required this.now, this.sub, this.snapshot});
  final String place;
  final Widget? sub;
  final DateTime now;
  final BoardSnapshot? snapshot;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final ink = Theme.of(context).colorScheme.onSurface;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final entries = snapshot?.entries ?? const <BoardEntry>[];
    final latest = entries.isEmpty
        ? null
        : entries.map((e) => e.latestReportAt).reduce((a, b) => a.isAfter(b) ? a : b);
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
          Text(l10n.bulletinKicker.toUpperCase(), style: dataLabelStyle(context)),
          const SizedBox(height: SharedTokens.space1),
          Semantics(header: true, child: Text(place, style: t.headlineMedium)),
          if (sub != null) ...[const SizedBox(height: 2), sub!],
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

/// Picks one market when the chosen town has more than one.
class _MarketPicker extends ConsumerWidget {
  const _MarketPicker({required this.market, required this.markets});
  final Market market;
  final List<Market> markets;

  Future<void> _pick(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
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
              Flexible(child: Text(market.name, style: t.bodyLarge)),
              const SizedBox(width: SharedTokens.space2),
              Text(l10n.change, style: t.labelLarge?.copyWith(color: c.info)),
              Icon(Icons.expand_more, size: 20, color: c.info),
            ],
          ),
        ),
      ),
    );
  }
}

List<Widget> _banners(BuildContext context, BoardSnapshot snap) {
  final l10n = AppLocalizations.of(context);
  const pad = EdgeInsets.fromLTRB(SharedTokens.space4, SharedTokens.space3, SharedTokens.space4, 0);
  return [
    if (snap.fromCache)
      Padding(
        padding: pad,
        child: NoticeBanner(
          icon: Icons.wifi_off,
          message: l10n.offlineBanner,
          kind: NoticeKind.info,
        ),
      ),
    if (snap.hasDemo)
      Padding(
        padding: pad,
        child: NoticeBanner(icon: Icons.science_outlined, message: l10n.demoPricesBanner),
      ),
  ];
}

/// Rows grouped under their category, categories in alphabetical order.
List<(String, List<Widget>)> _grouped<T>(
  List<T> rows,
  Commodity Function(T) commodityOf,
  Widget Function(T) build,
) {
  final groups = <String, List<T>>{};
  for (final r in rows) {
    groups.putIfAbsent(commodityOf(r).category.trim(), () => []).add(r);
  }
  final keys = groups.keys.toList()..sort();
  return [
    for (final k in keys) (keys.length > 1 ? k : '', [for (final r in groups[k]!) build(r)]),
  ];
}

Widget _loadingOrError(BuildContext context, AsyncValue<BoardSnapshot> board) {
  final l10n = AppLocalizations.of(context);
  if (board.hasError && !board.hasValue) {
    return Padding(
      padding: const EdgeInsets.all(SharedTokens.space4),
      child: _Empty(icon: Icons.cloud_off, title: l10n.boardErrorTitle, body: l10n.errNetwork),
    );
  }
  return const Padding(
    padding: EdgeInsets.all(SharedTokens.space6),
    child: Center(child: CircularProgressIndicator()),
  );
}

class _ProvinceBoard extends ConsumerWidget {
  const _ProvinceBoard({required this.now});
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final board = ref.watch(provinceBoardProvider);
    if (!board.hasValue) return _loadingOrError(context, board);
    final snap = board.value!;
    final commodities = ref.watch(commoditiesProvider).value ?? const <Commodity>[];
    final markets = ref.watch(marketsProvider).value ?? const <Market>[];
    final rows = provinceRows(snap.entries, commodities, markets);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ..._banners(context, snap),
        if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              SharedTokens.space4,
              SharedTokens.space3,
              SharedTokens.space4,
              0,
            ),
            child: _Empty(
              icon: Icons.price_change_outlined,
              title: l10n.priceBoardEmptyTitle,
              body: l10n.priceBoardEmptyBody,
            ),
          )
        else
          BulletinList(
            groups: _grouped<ProvinceRow>(
              rows,
              (r) => r.commodity,
              (r) => PriceRowCard(
                key: Key('row_${r.commodity.id}'),
                title: r.commodity.nameIn(context),
                subtitle: r.commodity.altNameIn(context),
                entry: r.entry,
                now: now,
                lead: r.markets == 1
                    ? l10n.provinceOneMarket
                    : l10n.provinceRange(peso(r.low), peso(r.high), r.markets),
                onTap: () => context.push(Routes.commodity(r.commodity.id)),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            SharedTokens.space4,
            SharedTokens.space3,
            SharedTokens.space4,
            0,
          ),
          child: Text(l10n.provinceFootnote, style: Theme.of(context).textTheme.bodySmall),
        ),
      ],
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
    if (!board.hasValue) return _loadingOrError(context, board);
    final snap = board.value!;
    final commodities = ref.watch(commoditiesProvider).value ?? const <Commodity>[];
    final rows = joinRows(snap.entries, commodities);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ..._banners(context, snap),
        if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              SharedTokens.space4,
              SharedTokens.space3,
              SharedTokens.space4,
              0,
            ),
            child: _Empty(
              icon: Icons.price_change_outlined,
              title: l10n.priceBoardEmptyTitle,
              body: l10n.priceBoardEmptyBody,
            ),
          )
        else
          BulletinList(
            groups: _grouped<BoardRow>(
              rows,
              (r) => r.commodity,
              (r) => PriceRowCard(
                key: Key('row_${r.commodity.id}'),
                title: r.commodity.nameIn(context),
                subtitle: r.commodity.altNameIn(context),
                entry: r.entry,
                now: now,
                onTap: () => context.push(Routes.commodity(r.commodity.id)),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            SharedTokens.space4,
            SharedTokens.space3,
            SharedTokens.space4,
            0,
          ),
          child: Text(l10n.boardFootnote, style: Theme.of(context).textTheme.bodySmall),
        ),
      ],
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.icon, required this.title, required this.body, this.action});
  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

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
          if (action != null) ...[const SizedBox(height: SharedTokens.space4), action!],
        ],
      ),
    );
  }
}
