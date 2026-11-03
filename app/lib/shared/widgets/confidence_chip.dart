import 'package:flutter/material.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../core/theme/timbang_colors.dart';
import '../models/confidence.dart';

/// Shared across both themes. Always icon + word, never color alone.
/// Low is gray (not red): it is not an error.
class ConfidenceChip extends StatelessWidget {
  const ConfidenceChip({super.key, required this.confidence});

  final Confidence confidence;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = TimbangColors.of(context);
    final (IconData icon, String label, Color fill, Color onFill) = switch (confidence) {
      Confidence.high => (
        Icons.verified,
        l10n.confidenceHigh,
        c.confidenceHigh,
        c.onConfidenceHigh,
      ),
      Confidence.medium => (
        Icons.adjust,
        l10n.confidenceMedium,
        c.confidenceMedium,
        c.onConfidenceMedium,
      ),
      Confidence.low => (
        Icons.help_outline,
        l10n.confidenceLow,
        c.confidenceLow,
        c.onConfidenceLow,
      ),
    };
    return Semantics(
      label: l10n.confidenceSemantics(label),
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(999)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: onFill),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(color: onFill),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
