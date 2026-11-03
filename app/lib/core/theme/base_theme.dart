import 'package:flutter/material.dart';

import 'timbang_colors.dart';
import 'tokens.dart';
import 'typography.dart';

/// Builds a ThemeData from a palette. Shapes, spacing, sizes and typography are shared,
/// so both themes read as one family: flat surfaces, 1px rules, no drop shadows.
ThemeData buildTimbangTheme({
  required ColorScheme scheme,
  required TimbangColors colors,
  required Color text,
}) {
  final radius = BorderRadius.circular(SharedTokens.radius);
  final shape = RoundedRectangleBorder(borderRadius: radius);
  const minSize = Size(SharedTokens.minTouchTarget, 52);
  const padding = EdgeInsets.symmetric(horizontal: 22, vertical: 14);
  final textTheme = timbangTextTheme(text, colors.textMuted);
  OutlineInputBorder outline(Color c, [double w = 1.2]) => OutlineInputBorder(
    borderRadius: radius,
    borderSide: BorderSide(color: c, width: w),
  );

  return ThemeData(
    useMaterial3: true,
    fontFamily: kFontFamily,
    colorScheme: scheme,
    scaffoldBackgroundColor: colors.canvas,
    textTheme: textTheme,
    extensions: [colors],
    materialTapTargetSize: MaterialTapTargetSize.padded,
    visualDensity: VisualDensity.standard,
    splashFactory: InkSparkle.splashFactory,
    appBarTheme: AppBarTheme(
      backgroundColor: colors.primaryDark,
      foregroundColor: scheme.onPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleSpacing: SharedTokens.space4,
      titleTextStyle: textTheme.titleLarge?.copyWith(color: scheme.onPrimary),
    ),
    cardTheme: CardThemeData(
      color: scheme.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
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
        minimumSize: const Size(SharedTokens.minTouchTarget, SharedTokens.minTouchTarget),
        foregroundColor: colors.info,
        textStyle: textTheme.labelLarge,
        shape: shape,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: const Size(SharedTokens.minTouchTarget, SharedTokens.minTouchTarget),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      border: outline(colors.textMuted),
      enabledBorder: outline(colors.textMuted),
      focusedBorder: outline(scheme.primary, 2.2),
      errorBorder: outline(scheme.error, 1.5),
      focusedErrorBorder: outline(scheme.error, 2.2),
      labelStyle: textTheme.bodyLarge?.copyWith(color: colors.textMuted),
      floatingLabelStyle: textTheme.labelLarge?.copyWith(color: scheme.primary),
      prefixIconColor: colors.textMuted,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: colors.primaryTint,
      height: 74,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(
          color: s.contains(WidgetState.selected) ? scheme.primary : colors.textMuted,
          size: 26,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => textTheme.labelMedium?.copyWith(
          color: s.contains(WidgetState.selected) ? scheme.primary : colors.textMuted,
          fontWeight: s.contains(WidgetState.selected) ? FontWeight.w800 : FontWeight.w600,
        ),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: scheme.surface,
      indicatorColor: colors.primaryTint,
      selectedIconTheme: IconThemeData(color: scheme.primary),
      unselectedIconTheme: IconThemeData(color: colors.textMuted),
      selectedLabelTextStyle: textTheme.labelLarge?.copyWith(color: scheme.primary),
      unselectedLabelTextStyle: textTheme.labelLarge?.copyWith(color: colors.textMuted),
    ),
    dataTableTheme: DataTableThemeData(
      headingRowColor: WidgetStatePropertyAll(colors.surfaceMuted),
      headingTextStyle: textTheme.labelMedium?.copyWith(color: text, fontWeight: FontWeight.w800),
      dataTextStyle: textTheme.bodyMedium,
      dividerThickness: 1,
      headingRowHeight: 52,
      dataRowMinHeight: 56,
      dataRowMaxHeight: 64,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SharedTokens.radiusLarge)),
      titleTextStyle: textTheme.titleLarge,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(SharedTokens.radiusLarge)),
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      side: BorderSide(color: colors.textMuted, width: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    ),
    switchTheme: SwitchThemeData(trackOutlineColor: WidgetStatePropertyAll(colors.textMuted)),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: text,
      contentTextStyle: textTheme.bodyMedium?.copyWith(color: scheme.surface),
      shape: shape,
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(color: text, borderRadius: BorderRadius.circular(6)),
      textStyle: textTheme.labelMedium?.copyWith(color: scheme.surface),
    ),
    dividerTheme: DividerThemeData(color: colors.border, thickness: 1, space: 1),
    listTileTheme: ListTileThemeData(
      minVerticalPadding: 12,
      iconColor: colors.textMuted,
      titleTextStyle: textTheme.titleSmall,
      subtitleTextStyle: textTheme.bodySmall,
    ),
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
    surfaceTint: Colors.transparent,
  );
}
