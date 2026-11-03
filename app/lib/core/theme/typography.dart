import 'package:flutter/material.dart';

import 'timbang_colors.dart';

/// Bundled typefaces shared by both themes (all SIL OFL, all with the peso sign):
/// - IBM Plex Sans: text and UI. Engineered, institutional, very legible at small sizes.
/// - Fraunces: headlines and the wordmark. A warm, soft serif: the "bulletin" voice.
/// - IBM Plex Mono: prices and data labels, like the readout of a weighing scale (timbang).
const kFontFamily = 'IBMPlexSans';
const kSerifFamily = 'Fraunces';
const kMonoFamily = 'IBMPlexMono';

/// Price figures: mono, so digits and decimal points line up down a column.
TextStyle priceStyle(BuildContext context, double size) => TextStyle(
  fontFamily: kMonoFamily,
  fontSize: size,
  fontWeight: FontWeight.w600,
  height: 1.1,
  letterSpacing: -0.6,
  color: Theme.of(context).colorScheme.onSurface,
);

/// Small data label (column headers, the bulletin kicker): mono caps, tracked out.
TextStyle dataLabelStyle(BuildContext context, {Color? color}) => TextStyle(
  fontFamily: kMonoFamily,
  fontSize: 12,
  fontWeight: FontWeight.w600,
  letterSpacing: 1.2,
  height: 1.3,
  color: color ?? TimbangColors.of(context).textMuted,
);

/// Shared typography for both themes: large, high-contrast, low-end Android friendly.
TextTheme timbangTextTheme(Color text, Color muted) {
  TextStyle s(
    double size,
    FontWeight w, {
    Color? color,
    double? height,
    double? spacing,
    bool serif = false,
  }) => TextStyle(
    fontFamily: serif ? kSerifFamily : kFontFamily,
    fontSize: size,
    fontWeight: w,
    color: color,
    height: height,
    letterSpacing: spacing,
  );
  return TextTheme(
    displaySmall: s(38, FontWeight.w600, color: text, height: 1.1, spacing: -0.6, serif: true),
    headlineMedium: s(30, FontWeight.w600, color: text, height: 1.15, spacing: -0.4, serif: true),
    headlineSmall: s(26, FontWeight.w600, color: text, height: 1.2, spacing: -0.3, serif: true),
    titleLarge: s(22, FontWeight.w600, color: text, height: 1.25, spacing: -0.2, serif: true),
    titleMedium: s(18, FontWeight.w600, color: text, height: 1.3),
    titleSmall: s(16, FontWeight.w600, color: text, height: 1.3),
    bodyLarge: s(17, FontWeight.w400, color: text, height: 1.5),
    bodyMedium: s(16, FontWeight.w400, color: text, height: 1.5),
    bodySmall: s(14, FontWeight.w400, color: muted, height: 1.45),
    labelLarge: s(16, FontWeight.w700, spacing: 0.2),
    labelMedium: s(14, FontWeight.w600, spacing: 0.2),
    labelSmall: s(13, FontWeight.w600, color: muted, spacing: 0.2),
  );
}

/// Section kicker above a title, e.g. "PRESYO NGAYON".
TextStyle overline(BuildContext context) => Theme.of(context).textTheme.labelSmall!;

/// Prices and counts: tabular digits so columns line up.
const tabularFigures = [FontFeature.tabularFigures()];
