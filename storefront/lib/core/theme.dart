import 'package:flutter/material.dart';

// NicePOS marka paleti — nicepos/lib/core/constants/app_colors.dart ile aynı
// hex değerleri (storefront ayrı bir Flutter projesi olduğundan paylaşılan
// bir paket yerine kopyalanır, bkz. storefront/README kararı: "ayrı hedef").
class StoreColors {
  static const navy = Color(0xFF1B2A4A);
  static const navyMid = Color(0xFF2E4270);
  static const gold = Color(0xFFD4B86A);
  static const goldLight = Color(0xFFE3CD94);
  static const pageBg = Color(0xFFF7F7F8);
  static const cardBg = Colors.white;
  static const border = Color(0xFFE4E4E7);
  static const textPrimary = Color(0xFF1F2430);
  static const textMuted = Color(0xFF767B8A);
  static const danger = Color(0xFFB3412C);
  static const success = Color(0xFF1B7A45);
}

ThemeData buildStoreTheme() {
  return ThemeData(
    useMaterial3: true,
    colorSchemeSeed: StoreColors.navy,
    scaffoldBackgroundColor: StoreColors.pageBg,
    fontFamily: 'Roboto',
    appBarTheme: const AppBarTheme(
      backgroundColor: StoreColors.navy,
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: StoreColors.navy,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: StoreColors.border),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
  );
}
