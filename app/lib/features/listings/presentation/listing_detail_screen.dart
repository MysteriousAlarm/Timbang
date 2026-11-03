import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/router/redirect.dart';
import '../../../core/theme/timbang_colors.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/utils/contact.dart';
import '../../../shared/utils/phone.dart';
import '../../../shared/widgets/confidence_chip.dart';
import '../../../shared/widgets/sections.dart';
import '../../../shared/widgets/state_views.dart';
import '../../admin/presentation/admin_labels.dart';
import '../../auth/application/session.dart';
import '../../catalog/data/catalog_providers.dart';
import '../../catalog/domain/catalog_item.dart';
import '../../inquiries/presentation/ask_farmer.dart';
import '../../moderation/presentation/flag_sheet.dart';
import '../../price_board/application/board_providers.dart';
import '../../price_board/domain/board_entry.dart';
import '../../price_board/presentation/board_widgets.dart';
import '../application/listing_providers.dart';
import '../domain/listing.dart';
import 'listing_card.dart';

class ListingDetailScreen extends ConsumerWidget {
  const ListingDetailScreen({super.key, required this.listingId});
  final String listingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final c = TimbangColors.of(context);
    final async = ref.watch(listingProvider(listingId));
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 68,
        leading: BackButton(
          onPressed: () => context.canPop() ? context.pop() : context.go(Routes.listings),
        ),
        title: Text(l10n.listingDetailTitle),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: Container(height: 4, color: c.highlight),
        ),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => MessageView(
              icon: Icons.cloud_off,
              title: l10n.boardErrorTitle,
              body: l10n.errNetwork,
            ),
            data: (x) => x == null
                ? MessageView(
                    icon: Icons.search_off,
                    title: l10n.listingNotFound,
                    body: l10n.listingNotFoundBody,
                  )
                : _Body(listing: x),
          ),
        ),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.listing});
  final Listing listing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final c = TimbangColors.of(context);
    final now = ref.watch(clockProvider).value ?? DateTime.now();
    final session = ref.watch(sessionProvider);
    final isOwner = session is SignedIn && session.user.uid == listing.farmerId;
    Commodity? commodity;
    for (final x in ref.watch(commoditiesProvider).value ?? const <Commodity>[]) {
      if (x.id == listing.commodityId) commodity = x;
    }
    final locale = Localizations.localeOf(context).toLanguageTag();
    final status = listing.effectiveStatus(now);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        SharedTokens.space4,
        SharedTokens.space4,
        SharedTokens.space4,
        SharedTokens.space6,
      ),
      children: [
        _Photos(urls: listing.photoUrls),
        const SizedBox(height: SharedTokens.space4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(commodity?.nameFil ?? listing.commodityId, style: t.headlineSmall),
                  if (commodity != null) Text(commodity.nameEn, style: t.bodyMedium),
                ],
              ),
            ),
            PriceText(price: listing.askingPrice, unit: listing.unit, large: true),
          ],
        ),
        const SizedBox(height: SharedTokens.space2),
        Wrap(
          spacing: SharedTokens.space2,
          children: [ListingStatusPill(status: status)],
        ),
        const SizedBox(height: SharedTokens.space4),
        PanelCard(
          child: Column(
            children: [
              _Fact(
                icon: Icons.scale_outlined,
                label: l10n.fieldQuantity,
                value: '${quantityText(listing.quantity)} ${unitShort(l10n, listing.unit)}',
              ),
              const Divider(),
              _Fact(
                icon: Icons.location_on_outlined,
                label: l10n.municipalityLabel,
                value: '${listing.municipality}, Nueva Vizcaya',
              ),
              const Divider(),
              _Fact(
                icon: Icons.agriculture,
                label: l10n.fieldHarvestDate,
                value: DateFormat.yMMMMd(locale).format(listing.harvestDate),
              ),
              const Divider(),
              _Fact(
                icon: Icons.schedule,
                label: l10n.postedLabel,
                value: l10n.postedAgo(ageLabel(l10n, now, listing.createdAt)),
              ),
              if ((listing.note ?? '').isNotEmpty) ...[
                const Divider(),
                _Fact(icon: Icons.notes, label: l10n.fieldNote, value: listing.note!),
              ],
            ],
          ),
        ),
        const SizedBox(height: SharedTokens.space4),
        _MedianCompare(listing: listing, now: now),
        const SizedBox(height: SharedTokens.space5),
        if (isOwner)
          _OwnerActions(listing: listing, status: status)
        else ...[
          SectionHeader(kicker: l10n.contactKicker, title: listing.farmerName),
          const SizedBox(height: SharedTokens.space2),
          Text(l10n.contactPrivacyNote, style: t.bodySmall),
          const SizedBox(height: SharedTokens.space3),
          PanelCard(
            accent: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.phone_android, color: c.textMuted),
                    const SizedBox(width: SharedTokens.space3),
                    Expanded(
                      child: Text(formatPhMobile(listing.farmerPhone), style: t.titleMedium),
                    ),
                  ],
                ),
                const SizedBox(height: SharedTokens.space3),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => callNumber(listing.farmerPhone),
                        icon: const Icon(Icons.call),
                        label: Text(l10n.call),
                      ),
                    ),
                    const SizedBox(width: SharedTokens.space2),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => textNumber(listing.farmerPhone),
                        icon: const Icon(Icons.sms_outlined),
                        label: Text(l10n.text),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (status == ListingStatus.active) ...[
            const SizedBox(height: SharedTokens.space3),
            AskFarmerButton(
              listing: listing,
              commodityName: commodity?.nameFil ?? listing.commodityId,
            ),
          ],
          const SizedBox(height: SharedTokens.space2),
          Align(
            alignment: Alignment.centerLeft,
            child: FlagButton(targetType: 'listing', targetId: listing.id, label: l10n.flagListing),
          ),
        ],
      ],
    );
  }
}

class _Photos extends StatelessWidget {
  const _Photos({required this.urls});
  final List<String> urls;

  @override
  Widget build(BuildContext context) {
    if (urls.isEmpty) return const Center(child: ListingThumb(url: null, size: 140));
    return SizedBox(
      height: 240,
      child: PageView(
        children: [
          for (final u in urls)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(SharedTokens.radius),
                child: Image.network(
                  u,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const ListingThumb(url: null, size: 240),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: SharedTokens.space2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: TimbangColors.of(context).textMuted),
          const SizedBox(width: SharedTokens.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: t.bodySmall),
                Text(value, style: t.titleSmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "Actionable": pair the asking price with the verified market median.
class _MedianCompare extends ConsumerWidget {
  const _MedianCompare({required this.listing, required this.now});
  final Listing listing;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final board = ref.watch(commodityBoardProvider(listing.commodityId)).value;
    final markets = ref.watch(orderedMarketsProvider);
    final rows = compareRows(board?.entries ?? const [], markets, listing.municipality);
    if (rows.isEmpty) return const SizedBox.shrink();
    final r = rows.first;
    final BoardEntry e = r.entry;
    final diff = listing.askingPrice - e.medianPrice;
    return PanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.medianAt(r.market.name).toUpperCase(), style: t.labelSmall),
          const SizedBox(height: SharedTokens.space1),
          Row(
            children: [
              Text(peso(e.medianPrice), style: t.titleLarge),
              const SizedBox(width: SharedTokens.space2),
              ConfidenceChip(confidence: e.confidence),
              if (e.isStale(now)) ...[const SizedBox(width: 6), const StaleTag()],
            ],
          ),
          const SizedBox(height: SharedTokens.space1),
          Text(
            diff.abs() < 0.005
                ? l10n.askingSameAsMedian
                : diff > 0
                ? l10n.askingAboveMedian(peso(diff))
                : l10n.askingBelowMedian(peso(-diff)),
            style: t.bodyMedium,
          ),
          Text(l10n.updatedAgo(ageLabel(l10n, now, e.latestReportAt)), style: t.bodySmall),
        ],
      ),
    );
  }
}

class _OwnerActions extends ConsumerWidget {
  const _OwnerActions({required this.listing, required this.status});
  final Listing listing;
  final ListingStatus status;

  Future<void> _run(BuildContext context, Future<void> Function() action) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
      messenger.showSnackBar(SnackBar(content: Text(l10n.saved)));
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.errGeneric)));
    }
  }

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final qty = TextEditingController(text: quantityText(listing.quantity));
    final price = TextEditingController(text: listing.askingPrice.toStringAsFixed(2));
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.editListing),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: qty,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: l10n.fieldQuantity),
            ),
            const SizedBox(height: SharedTokens.space3),
            TextField(
              controller: price,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: l10n.fieldAskingPrice, prefixText: '₱ '),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.save)),
        ],
      ),
    );
    final q = double.tryParse(qty.text.trim());
    final p = double.tryParse(price.text.trim());
    if (ok != true || !context.mounted) return;
    if (q == null || q <= 0 || p == null || p < 0.01) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.errGeneric)));
      return;
    }
    await _run(
      context,
      () => ref.read(listingActionsProvider).edit(listing.id, quantity: q, askingPrice: p),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final actions = ref.read(listingActionsProvider);
    if (listing.moderated) {
      return NoticeBanner(
        icon: Icons.block,
        message: l10n.listingModerated,
        kind: NoticeKind.notice,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(kicker: l10n.ownerKicker, title: l10n.ownerTitle),
        const SizedBox(height: SharedTokens.space3),
        if (status == ListingStatus.active) ...[
          FilledButton.icon(
            key: const Key('markSold'),
            onPressed: () => _run(context, () => actions.markSold(listing.id)),
            icon: const Icon(Icons.handshake),
            label: Text(l10n.markSold),
          ),
          const SizedBox(height: SharedTokens.space2),
          OutlinedButton.icon(
            onPressed: () => _edit(context, ref),
            icon: const Icon(Icons.edit_outlined),
            label: Text(l10n.editListing),
          ),
        ],
        if (status == ListingStatus.expired || status == ListingStatus.sold) ...[
          FilledButton.icon(
            key: const Key('renew'),
            onPressed: () => _run(context, () => actions.renew(listing.id)),
            icon: const Icon(Icons.refresh),
            label: Text(l10n.renewListing),
          ),
        ],
        if (status != ListingStatus.removed) ...[
          const SizedBox(height: SharedTokens.space2),
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => _run(context, () => actions.remove(listing.id)),
            icon: const Icon(Icons.delete_outline),
            label: Text(l10n.removeListing),
          ),
        ],
      ],
    );
  }
}
