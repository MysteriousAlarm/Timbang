import 'package:flutter/material.dart';

/// Colors that Material's ColorScheme has no slot for. Read with `TimbangColors.of(context)`.
@immutable
class TimbangColors extends ThemeExtension<TimbangColors> {
  const TimbangColors({
    required this.cta,
    required this.onCta,
    required this.canvas,
    required this.textMuted,
    required this.info,
    required this.border,
    required this.highlight,
    required this.onHighlight,
    required this.primaryDark,
    required this.primaryTint,
    required this.surfaceMuted,
    required this.confidenceHigh,
    required this.onConfidenceHigh,
    required this.confidenceMedium,
    required this.onConfidenceMedium,
    required this.confidenceLow,
    required this.onConfidenceLow,
  });

  /// The ONE main action per screen.
  final Color cta;
  final Color onCta;
  final Color canvas;
  final Color textMuted;
  final Color info;
  final Color border;

  /// Badge/highlight fill (gold on web, harvest on mobile). Always paired with [onHighlight].
  final Color highlight;
  final Color onHighlight;

  /// Darker band for top strips/footers (white text on it).
  final Color primaryDark;

  /// Soft tint for selected states and section headers (body text on it).
  final Color primaryTint;

  /// Table headers and grouped-list backgrounds.
  final Color surfaceMuted;

  final Color confidenceHigh;
  final Color onConfidenceHigh;
  final Color confidenceMedium;
  final Color onConfidenceMedium;
  final Color confidenceLow;
  final Color onConfidenceLow;

  static TimbangColors of(BuildContext context) => Theme.of(context).extension<TimbangColors>()!;

  @override
  TimbangColors copyWith() => this;

  @override
  TimbangColors lerp(ThemeExtension<TimbangColors>? other, double t) => this;
}
