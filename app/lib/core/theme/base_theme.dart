import 'package:flutter/material.dart';

import 'timbang_colors.dart';
import 'tokens.dart';
import 'typography.dart';

/// Builds a ThemeData from a palette. Shapes, spacing, sizes and typography are shared.
ThemeData buildTimbangTheme({
  required ColorScheme scheme,
  required TimbangColors colors,
  required Color text,
}) {
  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(SharedTokens.radius));
  const minSize = Size(SharedTokens.minTouchTarget, SharedTokens.minTouchTarget + 4);
  const padding = EdgeInsets.symmetric(horizontal: 20, vertical: 14);
  final textTheme = timbangTextTheme(text, colors.textMuted);

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: colors.canvas,
    textTheme: textTheme,
    extensions: [colors],
    materialTapTargetSize: MaterialTapTargetSize.padded,
    visualDensity: VisualDensity.standard,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      centerTitle: false,
      titleTextStyle: textTheme.titleLarge?.copyWith(color: scheme.onPrimary),
    ),
    cardTheme: CardThemeData(
      color: scheme.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(SharedTokens.radius),
        side: BorderSide(color: colors.border),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: minSize,
        padding: padding,
        shape: shape,
        textStyle: textTheme.labelLarge,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: minSize,
        padding: padding,
        shape: shape,
        foregroundColor: scheme.primary,
        side: BorderSide(color: scheme.primary, width: 1.5),
        textStyle: textTheme.labelLarge,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: minSize,
        foregroundColor: colors.info,
        textStyle: textTheme.labelLarge,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(SharedTokens.radius),
        borderSide: BorderSide(color: colors.textMuted),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(SharedTokens.radius),
        borderSide: BorderSide(color: colors.textMuted),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(SharedTokens.radius),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
      labelStyle: textTheme.bodyLarge?.copyWith(color: colors.textMuted),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surface,
      indicatorColor: scheme.primaryContainer,
      height: 72,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      labelTextStyle: WidgetStatePropertyAll(textTheme.labelMedium),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    dividerTheme: DividerThemeData(color: colors.border, thickness: 1),
  );
}

ColorScheme timbangScheme({
  required Color primary,
  required Color onPrimary,
  required Color secondary,
  required Color onSecondary,
  required Color surface,
  required Color text,
  required Color primaryContainer,
  required Color onPrimaryContainer,
}) {
  return ColorScheme(
    brightness: Brightness.light,
    primary: primary,
    onPrimary: onPrimary,
    primaryContainer: primaryContainer,
    onPrimaryContainer: onPrimaryContainer,
    secondary: secondary,
    onSecondary: onSecondary,
    error: SharedTokens.error,
    onError: SharedTokens.onError,
    surface: surface,
    onSurface: text,
  );
}
