import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/timbang_colors.dart';
import '../../../core/theme/tokens.dart';
import '../../admin/presentation/admin_labels.dart';
import '../../price_board/domain/board_entry.dart';
import '../../price_board/presentation/board_widgets.dart';
import '../domain/listing.dart';

String quantityText(double q) =>
    q == q.roundToDouble() ? q.toStringAsFixed(0) : q.toStringAsFixed(2);

class ListingStatusPill extends StatelessWidget {
  const ListingStatusPill({super.key, required this.status});
  final ListingStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = TimbangColors.of(context);
    final (Color fill, Color on, IconData icon, String label) = switch (status) {
      ListingStatus.active => (
        c.confidenceHigh,
        c.onConfidenceHigh,
        Icons.check_circle,
        l10n.listingActive,
      ),
      ListingStatus.sold => (
        Theme.of(context).colorScheme.secondary,
        Theme.of(context).colorScheme.onSecondary,
        Icons.handshake,
        l10n.listingSold,
      ),
      ListingStatus.expired => (
        c.confidenceLow,
        c.onConfidenceLow,
        Icons.history,
        l10n.listingExpired,
      ),
      ListingStatus.removed => (
        c.confidenceLow,
        c.onConfidenceLow,
        Icons.block,
        l10n.listingRemoved,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(4)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: on),
          const SizedBox(width: 4),
          Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: on)),
        ],
      ),
    );
  }
}

/// Photo, or a neutral produce icon when there is none (or it fails to load offline).
class ListingThumb extends StatelessWidget {
  const ListingThumb({super.key, required this.url, this.size = 88});
  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = TimbangColors.of(context);
    final fallback = Container(
      color: c.primaryTint,
      alignment: Alignment.center,
      child: Icon(Icons.eco, color: Theme.of(context).colorScheme.primary, size: size * 0.4),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(SharedTokens.radius),
      child: SizedBox.square(
        dimension: size,
        child: url == null
            ? fallback
            : Image.network(url!, fit: BoxFit.cover, errorBuilder: (_, _, _) => fallback),
      ),
    );
  }
}

class ListingCard extends StatelessWidget {
  const ListingCard({
    super.key,
    required this.listing,
    required this.commodityName,
    required this.now,
    required this.onTap,
    this.showStatus = false,
  });

  final Listing listing;
  final String commodityName;
  final DateTime now;
  final VoidCallback onTap;
  final bool showStatus;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final c = TimbangColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).toLanguageTag();
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
          padding: const EdgeInsets.all(SharedTokens.space3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListingThumb(url: listing.photoUrls.isEmpty ? null : listing.photoUrls.first),
              const SizedBox(width: SharedTokens.space3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(commodityName, style: t.titleMedium)),
                        Text(
                          peso(listing.askingPrice),
                          style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${quantityText(listing.quantity)} ${unitShort(l10n, listing.unit)}',
                            style: t.bodyMedium,
                          ),
                        ),
                        Text(l10n.perUnit(unitShort(l10n, listing.unit)), style: t.bodySmall),
                      ],
                    ),
                    const SizedBox(height: SharedTokens.space1),
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined, size: 16, color: c.textMuted),
                        const SizedBox(width: 2),
                        Flexible(child: Text(listing.municipality, style: t.bodySmall)),
                        const SizedBox(width: SharedTokens.space2),
                        Icon(Icons.agriculture, size: 16, color: c.textMuted),
                        const SizedBox(width: 2),
                        Flexible(
                          child: Text(
                            DateFormat.MMMd(locale).format(listing.harvestDate),
                            style: t.bodySmall,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: SharedTokens.space1),
                    Wrap(
                      spacing: SharedTokens.space2,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (showStatus) ListingStatusPill(status: listing.effectiveStatus(now)),
                        Text(
                          l10n.postedAgo(ageLabel(l10n, now, listing.createdAt)),
                          style: t.bodySmall,
                        ),
                      ],
                    ),
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
