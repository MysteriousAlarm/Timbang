import 'package:flutter/material.dart';

/// Shared typography for both themes: large, high-contrast, low-end Android friendly.
/// Uses the platform font (Roboto on Android) so nothing is downloaded.
TextTheme timbangTextTheme(Color text, Color muted) {
  return TextTheme(
    displaySmall: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: text, height: 1.15),
    headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: text),
    headlineSmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: text),
    titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: text),
    titleMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: text),
    titleSmall: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: text),
    bodyLarge: TextStyle(fontSize: 18, color: text, height: 1.4),
    bodyMedium: TextStyle(fontSize: 16, color: text, height: 1.4),
    bodySmall: TextStyle(fontSize: 14, color: muted, height: 1.35),
    labelLarge: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
    labelMedium: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
    labelSmall: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
  );
}
