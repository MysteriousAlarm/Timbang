import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/router/redirect.dart';
import '../../../core/theme/timbang_colors.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/models/role.dart';
import '../../../shared/widgets/sections.dart';
import '../../../shared/widgets/state_views.dart';
import '../../auth/application/session.dart';
import '../../catalog/data/catalog_providers.dart';
import '../../catalog/domain/catalog_item.dart';
import '../../catalog/presentation/commodity_names.dart';
import '../../price_board/application/board_providers.dart';
import '../application/listing_providers.dart';
import '../data/listing_repository.dart';
import '../domain/listing.dart';
import 'listing_card.dart';

enum _View { browse, mine }

enum _Sort { newest, cheapest }

/// Buyers search produce; farmers also manage their own listings.
class ListingsTab extends ConsumerStatefulWidget {
  const ListingsTab({super.key});

  @override
  ConsumerState<ListingsTab> createState() => _ListingsTabState();
}

class _ListingsTabState extends ConsumerState<ListingsTab> {
  _View _view = _View.browse;
  _Sort _sort = _Sort.newest;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final session = ref.watch(sessionProvider);
    final isFarmer = session is SignedIn && session.role == Role.farmer;
    final c = TimbangColors.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: isFarmer
          ? FloatingActionButton.extended(
              key: const Key('postListing'),
              backgroundColor: c.cta,
              foregroundColor: c.onCta,
              onPressed: () => context.push(Routes.newListing),
              icon: const Icon(Icons.add),
              label: Text(l10n.actionPostProduce),
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          SharedTokens.space4,
          SharedTokens.space5,
          SharedTokens.space4,
          96,
        ),
        children: [
          SectionHeader(kicker: l10n.listingsKicker, title: l10n.listingsTitle),
          const SizedBox(height: SharedTokens.space3),
          if (isFarmer) ...[
            SegmentedButton<_View>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                  value: _View.browse,
                  label: Text(l10n.listingsAll),
                  icon: const Icon(Icons.storefront_outlined),
                ),
                ButtonSegment(
                  value: _View.mine,
                  label: Text(l10n.listingsMine),
                  icon: const Icon(Icons.inventory_2_outlined),
                ),
              ],
              selected: {_view},
              onSelectionChanged: (s) => setState(() => _view = s.first),
            ),
            const SizedBox(height: SharedTokens.space3),
          ],
          if (_view == _View.browse) ...[
            _Filters(sort: _sort, onSort: (s) => setState(() => _sort = s)),
            const SizedBox(height: SharedTokens.space3),
            _BrowseList(sort: _sort),
          ] else
            const _MineList(),
        ],
      ),
    );
  }
}

class _Filters extends ConsumerWidget {
  const _Filters({required this.sort, required this.onSort});
  final _Sort sort;
  final ValueChanged<_Sort> onSort;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final f = ref.watch(listingFilterProvider);
    final commodities = (ref.watch(commoditiesProvider).value ?? const <Commodity>[])
        .where((x) => x.active)
        .toList();
    final notifier = ref.read(listingFilterProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String?>(
                key: const Key('filterCommodity'),
                initialValue: f.commodityId,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: l10n.fieldCommodity,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
                items: [
                  DropdownMenuItem(value: null, child: Text(l10n.filterAll)),
                  for (final x in commodities)
                    DropdownMenuItem(value: x.id, child: Text(x.nameIn(context))),
                ],
                onChanged: (v) =>
                    notifier.set(ListingFilter(commodityId: v, municipality: f.municipality)),
              ),
            ),
            const SizedBox(width: SharedTokens.space2),
            Expanded(
              child: DropdownButtonFormField<String?>(
                key: const Key('filterTown'),
                initialValue: f.municipality,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: l10n.municipalityLabel,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
                items: [
                  DropdownMenuItem(value: null, child: Text(l10n.filterAll)),
                  for (final m in AppConfig.municipalities)
                    DropdownMenuItem(value: m, child: Text(m)),
                ],
                onChanged: (v) =>
                    notifier.set(ListingFilter(commodityId: f.commodityId, municipality: v)),
              ),
            ),
          ],
        ),
        const SizedBox(height: SharedTokens.space2),
        Align(
          alignment: Alignment.centerLeft,
          child: SegmentedButton<_Sort>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: _Sort.newest, label: Text(l10n.sortNewest)),
              ButtonSegment(value: _Sort.cheapest, label: Text(l10n.sortCheapest)),
            ],
            selected: {sort},
            onSelectionChanged: (s) => onSort(s.first),
          ),
        ),
      ],
    );
  }
}

class _BrowseList extends ConsumerWidget {
  const _BrowseList({required this.sort});
  final _Sort sort;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final f = ref.watch(listingFilterProvider);
    final async = ref.watch(activeListingsProvider(f));
    final now = ref.watch(clockProvider).value ?? DateTime.now();
    final names = {
      for (final x in ref.watch(commoditiesProvider).value ?? const <Commodity>[])
        x.id: x.nameIn(context),
    };
    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) =>
          MessageView(icon: Icons.cloud_off, title: l10n.boardErrorTitle, body: l10n.errNetwork),
      data: (all) {
        final list = all.where((x) => x.isLive(now)).toList();
        if (sort == _Sort.cheapest) list.sort((a, b) => a.askingPrice.compareTo(b.askingPrice));
        if (list.isEmpty) {
          return MessageView(
            icon: Icons.storefront_outlined,
            title: l10n.listingsEmptyTitle,
            body: l10n.listingsEmptyBody,
          );
        }
        return Column(
          children: [
            for (final x in list) ...[
              ListingCard(
                key: Key('listing_${x.id}'),
                listing: x,
                commodityName: names[x.commodityId] ?? x.commodityId,
                now: now,
                onTap: () => context.push(Routes.listing(x.id)),
              ),
              const SizedBox(height: SharedTokens.space3),
            ],
          ],
        );
      },
    );
  }
}

class _MineList extends ConsumerWidget {
  const _MineList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(myListingsProvider);
    final now = ref.watch(clockProvider).value ?? DateTime.now();
    final names = {
      for (final x in ref.watch(commoditiesProvider).value ?? const <Commodity>[])
        x.id: x.nameIn(context),
    };
    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) =>
          MessageView(icon: Icons.cloud_off, title: l10n.boardErrorTitle, body: l10n.errNetwork),
      data: (list) {
        final visible = list
            .where((x) => x.status != ListingStatus.removed || x.moderated)
            .toList();
        if (visible.isEmpty) {
          return MessageView(
            icon: Icons.inventory_2_outlined,
            title: l10n.myListingsEmptyTitle,
            body: l10n.myListingsEmptyBody,
          );
        }
        return Column(
          children: [
            for (final x in visible) ...[
              ListingCard(
                listing: x,
                commodityName: names[x.commodityId] ?? x.commodityId,
                now: now,
                showStatus: true,
                onTap: () => context.push(Routes.listing(x.id)),
              ),
              const SizedBox(height: SharedTokens.space3),
            ],
          ],
        );
      },
    );
  }
}
