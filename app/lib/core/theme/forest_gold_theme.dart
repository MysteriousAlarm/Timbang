import 'package:flutter/material.dart';

import 'base_theme.dart';
import 'timbang_colors.dart';
import 'tokens.dart';

/// Website theme (main_web.dart): public landing page and admin dashboard.
final ThemeData forestGoldTheme = buildTimbangTheme(
  scheme: timbangScheme(
    primary: ForestGoldTokens.primary,
    onPrimary: ForestGoldTokens.onPrimary,
    secondary: ForestGoldTokens.accent,
    onSecondary: ForestGoldTokens.onAccent,
    surface: ForestGoldTokens.surface,
    text: ForestGoldTokens.text,
    primaryContainer: ForestGoldTokens.primaryTint,
    onPrimaryContainer: ForestGoldTokens.text,
  ),
  colors: const TimbangColors(
    // On the website the single main action uses the gold fill with dark text.
    cta: ForestGoldTokens.gold,
    onCta: ForestGoldTokens.onGold,
    canvas: ForestGoldTokens.canvas,
    textMuted: ForestGoldTokens.textMuted,
    info: ForestGoldTokens.accent,
    border: ForestGoldTokens.border,
    highlight: ForestGoldTokens.gold,
    onHighlight: ForestGoldTokens.onGold,
    primaryDark: ForestGoldTokens.primaryDark,
    primaryTint: ForestGoldTokens.primaryTint,
    surfaceMuted: ForestGoldTokens.surfaceMuted,
    confidenceHigh: SharedTokens.confidenceHigh,
    onConfidenceHigh: SharedTokens.onConfidenceHigh,
    confidenceMedium: SharedTokens.confidenceMedium,
    onConfidenceMedium: SharedTokens.onConfidenceMedium,
    confidenceLow: SharedTokens.confidenceLow,
    onConfidenceLow: SharedTokens.onConfidenceLow,
  ),
  text: ForestGoldTokens.text,
);
