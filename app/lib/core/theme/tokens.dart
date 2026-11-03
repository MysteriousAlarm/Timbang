import 'package:flutter/material.dart';

/// The ONLY place hex colors live (CLAUDE.md Section 11).
/// Widgets read colors from `Theme.of(context)` or [TimbangColors], never from here directly.

/// Harvest Earth: mobile app.
abstract final class HarvestEarthTokens {
  static const primary = Color(0xFF2F6F3A);
  static const onPrimary = Color(0xFFFFFFFF);
  static const secondary = Color(0xFF6B4A2B); // soil
  static const onSecondary = Color(0xFFFFFFFF);
  static const cta = Color(0xFFE8892B); // harvest; fill only, never text on white
  static const onCta = Color(0xFF2B2118);
  static const canvas = Color(0xFFF7F4EE); // newsprint: warm, not yellow
  static const surface = Color(0xFFFFFFFF);
  static const text = Color(0xFF2B2118);
  static const textMuted = Color(0xFF6B5A48);
  static const info = Color(0xFF2A6F97);
  // Derived tints/shades of the palette above (contrast-checked in test/theme_test.dart).
  static const border = Color(0xFFDDD6C9); // rules and outlines, decoration only
  static const primaryDark = Color(0xFF235229); // header bands, top strip
  static const primaryTint = Color(0xFFE7F0E8); // selected rows, soft headers
  static const surfaceMuted = Color(0xFFF1EDE5); // table headers, grouped list bg
}

/// Forest and Gold: website (landing page + admin dashboard).
abstract final class ForestGoldTokens {
  static const primary = Color(0xFF1F4D2B);
  static const onPrimary = Color(0xFFFFFFFF);
  static const accent = Color(0xFF2E7D4F);
  static const onAccent = Color(0xFFFFFFFF);
  static const gold = Color(0xFFC9A227); // fill only, with dark text
  static const onGold = Color(0xFF1B2A21);
  static const canvas = Color(0xFFF4F7F2);
  static const surface = Color(0xFFFFFFFF);
  static const text = Color(0xFF1B2A21);
  static const textMuted = Color(0xFF4A6B57);
  static const border = Color(0xFFD5E0D6);
  // Derived tints/shades (contrast-checked in test/theme_test.dart).
  static const primaryDark = Color(0xFF163A20); // top utility strip, footer
  static const primaryTint = Color(0xFFE6EFE8); // selected nav, soft headers
  static const surfaceMuted = Color(0xFFEEF3EC); // table headers
}

/// Shared across both themes so the product feels like one family.
abstract final class SharedTokens {
  static const confidenceHigh = Color(0xFF1F7A3A);
  static const onConfidenceHigh = Color(0xFFFFFFFF);
  static const confidenceMedium = Color(0xFFF2B84B);
  static const onConfidenceMedium = Color(0xFF1B2A21);

  /// Trust-meter bars (non-text, >= 3:1 on white). Medium uses a deeper amber than the
  /// fill above so the bars stay visible in sunlight.
  static const meterHigh = Color(0xFF1F7A3A);
  static const meterMedium = Color(0xFFA86A00);
  static const meterLow = Color(0xFF5B6770);
  static const meterEmpty = Color(0xFFD9D3C7);
  static const confidenceLow = Color(0xFF5B6770);
  static const onConfidenceLow = Color(0xFFFFFFFF);
  static const error = Color(0xFFB3261E);
  static const onError = Color(0xFFFFFFFF);

  /// Notices such as the "demo data" banner: pale gold fill, dark text, gold rule.
  static const notice = Color(0xFFFFF4D6);
  static const onNotice = Color(0xFF1B2A21);
  static const noticeRule = Color(0xFFC9A227);

  // Spacing (dp) and shape.
  static const space1 = 4.0;
  static const space2 = 8.0;
  static const space3 = 12.0;
  static const space4 = 16.0;
  static const space5 = 24.0;
  static const space6 = 32.0;
  static const radiusSmall = 6.0;
  static const radius = 10.0;
  static const radiusLarge = 16.0;

  /// Minimum touch target (WCAG / Material): 48x48 dp.
  static const minTouchTarget = 48.0;
}
