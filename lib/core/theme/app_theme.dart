import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';

part 'app_theme.g.dart';

// ── Riverpod provider — tek kaynak ──────────────────────────────────────────
@Riverpod(keepAlive: true)
ThemeData appTheme(AppThemeRef ref) => _buildTheme();

// ── Tema inşaatı ────────────────────────────────────────────────────────────
ThemeData _buildTheme() {
  const colorScheme = ColorScheme(
    brightness: Brightness.light,
    // Primary: Lacivert
    primary: AppColors.primary,
    onPrimary: AppColors.goldLight,
    primaryContainer: AppColors.primaryMid,
    onPrimaryContainer: AppColors.goldLight,
    // Secondary: Altın
    secondary: AppColors.gold,
    onSecondary: AppColors.primary,
    secondaryContainer: AppColors.goldBg,
    onSecondaryContainer: AppColors.primary,
    // Surface: Beyaz
    surface: AppColors.cardBg,
    onSurface: AppColors.textPrimary,
    surfaceContainerHighest: AppColors.goldBg,
    // Error
    error: AppColors.danger,
    onError: Colors.white,
    // Outline
    outline: AppColors.goldBorder,
    outlineVariant: AppColors.goldSubtle,
    // Shadow / Scrim
    shadow: Color(0x1A1B2A4A),
    scrim: Color(0x801B2A4A),
    // Inverse
    inversePrimary: AppColors.goldLight,
    inverseSurface: AppColors.primaryDark,
    onInverseSurface: AppColors.goldLight,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: AppColors.pageBg,
    fontFamily: 'Roboto',

    // ── AppBar ───────────────────────────────────────────────────────────────
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.cardBg,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    ),

    // ── Card ─────────────────────────────────────────────────────────────────
    cardTheme: CardThemeData(
      color: AppColors.cardBg,
      elevation: 0,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
        side: const BorderSide(color: AppColors.goldBorder, width: 1),
      ),
    ),

    // ── Divider ──────────────────────────────────────────────────────────────
    dividerTheme: const DividerThemeData(
      color: AppColors.divider,
      thickness: 1,
      space: 1,
    ),

    // ── Input ────────────────────────────────────────────────────────────────
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: AppColors.cardBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSizes.inputRadius),
        borderSide: const BorderSide(color: AppColors.goldBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSizes.inputRadius),
        borderSide: const BorderSide(color: AppColors.goldBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSizes.inputRadius),
        borderSide: const BorderSide(color: AppColors.gold, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSizes.inputRadius),
        borderSide: const BorderSide(color: AppColors.danger),
      ),
    ),

    // ── FilledButton (ana eylem — lacivert zemin, altın metin) ───────────────
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.goldLight,
        disabledBackgroundColor: AppColors.primaryMid,
        disabledForegroundColor: AppColors.goldSubtle,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.buttonRadius),
        ),
      ),
    ),

    // ── ElevatedButton (lacivert zemin, altın metin) ─────────────────────────
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.goldLight,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.buttonRadius),
        ),
      ),
    ),

    // ── OutlinedButton (beyaz zemin, altın kenarlık, lacivert metin) ─────────
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        backgroundColor: AppColors.cardBg,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        textStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.buttonRadius),
        ),
        side: const BorderSide(color: AppColors.goldBorder, width: 1),
      ),
    ),

    // ── TextButton ───────────────────────────────────────────────────────────
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        textStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.buttonRadius),
        ),
      ),
    ),

    // ── DataTable ────────────────────────────────────────────────────────────
    dataTableTheme: DataTableThemeData(
      headingRowColor: WidgetStateProperty.all(AppColors.tableHeader),
      headingTextStyle: const TextStyle(
        fontWeight: FontWeight.w700,
        color: AppColors.primary,
        fontSize: 13,
        letterSpacing: 0.3,
      ),
      dataTextStyle: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 13,
      ),
      dataRowMinHeight: 44,
      dataRowMaxHeight: 56,
      dividerThickness: 1,
      decoration: const BoxDecoration(color: AppColors.cardBg),
    ),

    // ── Chip ─────────────────────────────────────────────────────────────────
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.goldBg,
      selectedColor: AppColors.primary.withValues(alpha: 0.12),
      labelStyle: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
      side: const BorderSide(color: AppColors.goldBorder),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.chipRadius),
      ),
    ),

    // ── Dialog ───────────────────────────────────────────────────────────────
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.cardBg,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
        side: const BorderSide(color: AppColors.goldBorder),
      ),
      titleTextStyle: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: AppColors.primary,
      ),
    ),

    // ── SnackBar ─────────────────────────────────────────────────────────────
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.primaryDark,
      contentTextStyle: const TextStyle(color: AppColors.goldLight),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.buttonRadius),
        side: const BorderSide(color: AppColors.goldBorder),
      ),
    ),

    // ── ListTile ─────────────────────────────────────────────────────────────
    listTileTheme: const ListTileThemeData(
      titleTextStyle: TextStyle(
        color: AppColors.textPrimary,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      subtitleTextStyle: TextStyle(
        color: AppColors.textMuted,
        fontSize: 12,
      ),
    ),

    // ── TabBar ───────────────────────────────────────────────────────────────
    tabBarTheme: const TabBarThemeData(
      labelColor: AppColors.primary,
      unselectedLabelColor: AppColors.textMuted,
      indicatorColor: AppColors.gold,
      dividerColor: Colors.transparent,
      labelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
      unselectedLabelStyle: TextStyle(fontSize: 13),
    ),

    // ── FloatingActionButton ─────────────────────────────────────────────────
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.goldLight,
      elevation: 2,
    ),

    // ── ProgressIndicator ────────────────────────────────────────────────────
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.gold,
    ),
  );
}
