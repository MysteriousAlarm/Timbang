import '../../../core/config/app_config.dart';

enum ListingStatus {
  active,
  sold,
  expired,
  removed;

  static ListingStatus parse(Object? v) =>
      ListingStatus.values.firstWhere((s) => s.name == v, orElse: () => ListingStatus.active);
}

/// listings/{id}. Contact fields are copied from the farmer's profile (rules enforce it).
class Listing {
  const Listing({
    required this.id,
    required this.farmerId,
    required this.farmerName,
    required this.farmerPhone,
    required this.commodityId,
    required this.quantity,
    required this.unit,
    required this.askingPrice,
    required this.municipality,
    required this.harvestDate,
    required this.photoUrls,
    required this.status,
    required this.createdAt,
    required this.expiresAt,
    this.note,
    this.moderated = false,
  });

  final String id;
  final String farmerId;
  final String farmerName;
  final String farmerPhone;
  final String commodityId;
  final double quantity;
  final String unit;
  final double askingPrice;
  final String municipality;
  final DateTime harvestDate;
  final List<String> photoUrls;
  final ListingStatus status;
  final DateTime createdAt;
  final DateTime expiresAt;
  final String? note;

  /// Removed by an admin: the owner cannot revive it.
  final bool moderated;

  /// Active and not past its expiry (the hourly job may not have run yet).
  bool isLive(DateTime now) => status == ListingStatus.active && expiresAt.isAfter(now);

  /// What the UI should treat the listing as right now.
  ListingStatus effectiveStatus(DateTime now) =>
      status == ListingStatus.active && !expiresAt.isAfter(now) ? ListingStatus.expired : status;
}

/// Form input for a new listing. Validation mirrors firestore.rules.
class ListingDraft {
  const ListingDraft({
    required this.commodityId,
    required this.quantity,
    required this.unit,
    required this.askingPrice,
    required this.municipality,
    required this.harvestDate,
    this.note,
  });

  final String? commodityId;
  final double? quantity;
  final String unit;
  final double? askingPrice;
  final String? municipality;
  final DateTime? harvestDate;
  final String? note;
}

enum DraftIssue { commodity, quantity, price, municipality, harvestDate, note }

List<DraftIssue> validateDraft(ListingDraft d, {DateTime? now}) {
  final today = now ?? DateTime.now();
  return [
    if (d.commodityId == null) DraftIssue.commodity,
    if (d.quantity == null || d.quantity! <= 0 || d.quantity! > AppConfig.quantityMax)
      DraftIssue.quantity,
    if (d.askingPrice == null ||
        d.askingPrice! < AppConfig.priceMin ||
        d.askingPrice! > AppConfig.priceMax)
      DraftIssue.price,
    if (d.municipality == null || !AppConfig.municipalities.contains(d.municipality))
      DraftIssue.municipality,
    // Harvest date: up to 60 days ago or up to 60 days ahead (expected harvest).
    if (d.harvestDate == null ||
        d.harvestDate!.isBefore(today.subtract(const Duration(days: 60))) ||
        d.harvestDate!.isAfter(today.add(const Duration(days: 60))))
      DraftIssue.harvestDate,
    if ((d.note ?? '').length > AppConfig.listingNoteMax) DraftIssue.note,
  ];
}

/// "50", "12.5" -> number; null if invalid.
double? parseQuantity(String s) {
  final v = double.tryParse(s.trim().replaceAll(',', ''));
  if (v == null || v <= 0 || v > AppConfig.quantityMax) return null;
  return (v * 100).roundToDouble() / 100;
}
