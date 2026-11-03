enum AlertDirection { above, below }

/// alerts/{id}: notify me when the median at a market crosses my price.
class PriceAlert {
  const PriceAlert({
    required this.id,
    required this.commodityId,
    required this.marketId,
    required this.threshold,
    required this.direction,
    required this.active,
    this.lastTriggeredAt,
    this.lastTriggeredMedian,
  });

  final String id;
  final String commodityId;
  final String marketId;
  final double threshold;
  final AlertDirection direction;
  final bool active;
  final DateTime? lastTriggeredAt;
  final double? lastTriggeredMedian;

  /// Whether the given median currently satisfies the alert condition.
  bool isMet(double median) =>
      direction == AlertDirection.above ? median >= threshold : median <= threshold;
}

/// Client-side cap (rules cannot count documents).
const maxAlertsPerUser = 20;
