import 'package:flutter/material.dart';

import 'base_theme.dart';
import 'timbang_colors.dart';
import 'tokens.dart';

/// Mobile app theme (main_app.dart) and farmer/buyer screens on the web.
final ThemeData harvestEarthTheme = buildTimbangTheme(
  scheme: timbangScheme(
    primary: HarvestEarthTokens.primary,
    onPrimary: HarvestEarthTokens.onPrimary,
    secondary: HarvestEarthTokens.secondary,
    onSecondary: HarvestEarthTokens.onSecondary,
    surface: HarvestEarthTokens.surface,
    text: HarvestEarthTokens.text,
    primaryContainer: HarvestEarthTokens.primaryTint,
    onPrimaryContainer: HarvestEarthTokens.text,
  ),
  colors: const TimbangColors(
    cta: HarvestEarthTokens.cta,
    onCta: HarvestEarthTokens.onCta,
    canvas: HarvestEarthTokens.canvas,
    textMuted: HarvestEarthTokens.textMuted,
    info: HarvestEarthTokens.info,
    border: HarvestEarthTokens.border,
    highlight: HarvestEarthTokens.cta,
    onHighlight: HarvestEarthTokens.onCta,
    primaryDark: HarvestEarthTokens.primaryDark,
    primaryTint: HarvestEarthTokens.primaryTint,
    surfaceMuted: HarvestEarthTokens.surfaceMuted,
    confidenceHigh: SharedTokens.confidenceHigh,
    onConfidenceHigh: SharedTokens.onConfidenceHigh,
    confidenceMedium: SharedTokens.confidenceMedium,
    onConfidenceMedium: SharedTokens.onConfidenceMedium,
    confidenceLow: SharedTokens.confidenceLow,
    onConfidenceLow: SharedTokens.onConfidenceLow,
  ),
  text: HarvestEarthTokens.text,
);
