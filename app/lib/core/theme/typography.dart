import 'package:flutter/material.dart';

/// Bundled typeface shared by both themes (Public Sans, SIL OFL).
const kFontFamily = 'PublicSans';

/// Shared typography for both themes: large, high-contrast, low-end Android friendly.
TextTheme timbangTextTheme(Color text, Color muted) {
  TextStyle s(double size, FontWeight w, {Color? color, double? height, double? spacing}) =>
      TextStyle(
        fontFamily: kFontFamily,
        fontSize: size,
        fontWeight: w,
        color: color,
        height: height,
        letterSpacing: spacing,
      );
  return TextTheme(
    displaySmall: s(36, FontWeight.w800, color: text, height: 1.12, spacing: -0.5),
    headlineMedium: s(28, FontWeight.w800, color: text, height: 1.2, spacing: -0.25),
    headlineSmall: s(24, FontWeight.w700, color: text, height: 1.25),
    titleLarge: s(21, FontWeight.w700, color: text, height: 1.3),
    titleMedium: s(18, FontWeight.w600, color: text, height: 1.3),
    titleSmall: s(16, FontWeight.w600, color: text, height: 1.3),
    bodyLarge: s(17, FontWeight.w400, color: text, height: 1.5),
    bodyMedium: s(16, FontWeight.w400, color: text, height: 1.5),
    bodySmall: s(14, FontWeight.w400, color: muted, height: 1.45),
    labelLarge: s(16, FontWeight.w700, spacing: 0.2),
    labelMedium: s(14, FontWeight.w600, spacing: 0.2),
    labelSmall: s(13, FontWeight.w700, color: muted, spacing: 1.1),
  );
}

/// Section kicker above a title, e.g. "PRESYO NGAYON".
TextStyle overline(BuildContext context) => Theme.of(context).textTheme.labelSmall!;

/// Prices and counts: tabular digits so columns line up.
const tabularFigures = [FontFeature.tabularFigures()];
