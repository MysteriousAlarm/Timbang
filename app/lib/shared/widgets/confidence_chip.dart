import 'package:flutter/material.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../core/theme/tokens.dart';
import '../models/confidence.dart';

/// Confidence as a 3-bar trust meter plus the word: like a signal meter, filled bars mean
/// more agreement. Shape (number of bars) and word carry the meaning, color only reinforces
/// it. Low is gray, not red: it is not an error.
class ConfidenceChip extends StatelessWidget {
  const ConfidenceChip({super.key, required this.confidence, this.compact = false});

  final Confidence confidence;

  /// Smaller meter and label for table rows.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final (int filled, String label, Color color) = switch (confidence) {
      Confidence.high => (3, l10n.confidenceHigh, SharedTokens.meterHigh),
      Confidence.medium => (2, l10n.confidenceMedium, SharedTokens.meterMedium),
      Confidence.low => (1, l10n.confidenceLow, SharedTokens.meterLow),
    };
    final t = Theme.of(context).textTheme;
    return Semantics(
      label: l10n.confidenceSemantics(label),
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TrustMeterBars(filled: filled, color: color, height: compact ? 12 : 15),
          SizedBox(width: compact ? 6 : 8),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: (compact ? t.labelMedium : t.labelLarge)?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Three ascending bars; [filled] of them in [color], the rest as empty outlines.
class TrustMeterBars extends StatelessWidget {
  const TrustMeterBars({super.key, required this.filled, required this.color, this.height = 15});

  final int filled;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final w = height * 0.3;
    return SizedBox(
      height: height,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < 3; i++) ...[
            if (i > 0) SizedBox(width: w * 0.55),
            Container(
              width: w,
              height: height * (0.45 + 0.275 * i),
              decoration: BoxDecoration(
                color: i < filled ? color : SharedTokens.meterEmpty,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
