import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timbang/core/theme/forest_gold_theme.dart';
import 'package:timbang/core/theme/harvest_earth_theme.dart';
import 'package:timbang/core/theme/timbang_colors.dart';
import 'package:timbang/core/theme/tokens.dart';

double _luminance(Color c) => c.computeLuminance();
double contrast(Color a, Color b) {
  final l1 = _luminance(a), l2 = _luminance(b);
  final hi = l1 > l2 ? l1 : l2, lo = l1 > l2 ? l2 : l1;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  test('Harvest Earth uses its tokens', () {
    final s = harvestEarthTheme.colorScheme;
    expect(s.primary, HarvestEarthTokens.primary);
    expect(s.secondary, HarvestEarthTokens.secondary);
    expect(harvestEarthTheme.scaffoldBackgroundColor, HarvestEarthTokens.canvas);
    expect(harvestEarthTheme.extension<TimbangColors>()!.cta, HarvestEarthTokens.cta);
  });

  test('Forest and Gold uses its tokens', () {
    final s = forestGoldTheme.colorScheme;
    expect(s.primary, ForestGoldTokens.primary);
    expect(s.secondary, ForestGoldTokens.accent);
    expect(forestGoldTheme.scaffoldBackgroundColor, ForestGoldTokens.canvas);
    expect(forestGoldTheme.extension<TimbangColors>()!.cta, ForestGoldTokens.gold);
  });

  test('shared family: error, confidence colors, typography are identical', () {
    final a = harvestEarthTheme, b = forestGoldTheme;
    expect(a.colorScheme.error, b.colorScheme.error);
    final ca = a.extension<TimbangColors>()!, cb = b.extension<TimbangColors>()!;
    expect(ca.confidenceHigh, cb.confidenceHigh);
    expect(ca.confidenceMedium, cb.confidenceMedium);
    expect(ca.confidenceLow, cb.confidenceLow);
    expect(a.textTheme.bodyLarge!.fontSize, b.textTheme.bodyLarge!.fontSize);
  });

  test('WCAG AA: text pairs meet 4.5:1', () {
    final pairs = <(Color, Color)>[
      (HarvestEarthTokens.onPrimary, HarvestEarthTokens.primary),
      (HarvestEarthTokens.onSecondary, HarvestEarthTokens.secondary),
      (HarvestEarthTokens.onCta, HarvestEarthTokens.cta),
      (HarvestEarthTokens.text, HarvestEarthTokens.canvas),
      (HarvestEarthTokens.textMuted, HarvestEarthTokens.canvas),
      (HarvestEarthTokens.info, HarvestEarthTokens.surface),
      (ForestGoldTokens.onPrimary, ForestGoldTokens.primary),
      (ForestGoldTokens.onAccent, ForestGoldTokens.accent),
      (ForestGoldTokens.onGold, ForestGoldTokens.gold),
      (ForestGoldTokens.text, ForestGoldTokens.canvas),
      (ForestGoldTokens.textMuted, ForestGoldTokens.canvas),
      (SharedTokens.onConfidenceHigh, SharedTokens.confidenceHigh),
      (SharedTokens.onConfidenceMedium, SharedTokens.confidenceMedium),
      (SharedTokens.onConfidenceLow, SharedTokens.confidenceLow),
      (SharedTokens.onError, SharedTokens.error),
      (SharedTokens.error, HarvestEarthTokens.surface),
      // Derived tints and shades.
      (HarvestEarthTokens.onPrimary, HarvestEarthTokens.primaryDark),
      (HarvestEarthTokens.text, HarvestEarthTokens.primaryTint),
      (HarvestEarthTokens.textMuted, HarvestEarthTokens.surfaceMuted),
      (HarvestEarthTokens.primary, HarvestEarthTokens.primaryTint),
      (ForestGoldTokens.onPrimary, ForestGoldTokens.primaryDark),
      (ForestGoldTokens.text, ForestGoldTokens.primaryTint),
      (ForestGoldTokens.textMuted, ForestGoldTokens.surfaceMuted),
      (ForestGoldTokens.primary, ForestGoldTokens.primaryTint),
      (SharedTokens.onNotice, SharedTokens.notice),
    ];
    for (final (fg, bg) in pairs) {
      expect(contrast(fg, bg), greaterThanOrEqualTo(4.5), reason: '$fg on $bg');
    }
  });

  test('gold and harvest are never readable as text on white (fill only)', () {
    expect(contrast(ForestGoldTokens.gold, Colors.white), lessThan(4.5));
    expect(contrast(HarvestEarthTokens.cta, Colors.white), lessThan(4.5));
  });
}
