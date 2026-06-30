import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Tasarım token'ları — boşluk, yarıçap, gölge tek kaynağı.
///
/// Katman 1 (tasarım temeli): 4'lük boşluk ölçeği + tutarlı yarıçap
/// kademeleri + markaya uygun (lacivert-tint) yumuşak gölgeler.
class AppSizes {
  // ── Sidebar ──────────────────────────────────────────────────────────────
  static const sidebarWidth = 220.0;
  static const sidebarCollapsedWidth = 56.0;

  // ── Üst bar ──────────────────────────────────────────────────────────────
  static const topBarHeight = 56.0;

  // ── Boşluk ölçeği (4'lük grid) ───────────────────────────────────────────
  static const space2 = 2.0;
  static const space4 = 4.0;
  static const space6 = 6.0;
  static const space8 = 8.0;
  static const space12 = 12.0;
  static const space16 = 16.0;
  static const space20 = 20.0;
  static const space24 = 24.0;
  static const space32 = 32.0;

  // ── Sayfa içi boşluklar (geriye dönük uyumluluk) ─────────────────────────
  static const pagePadding = 20.0;
  static const cardPadding = 16.0;
  static const sectionGap = 16.0;

  // ── Yarıçap ölçeği ───────────────────────────────────────────────────────
  static const radiusSm = 8.0;
  static const radiusMd = 12.0;
  static const radiusLg = 16.0;
  static const radiusXl = 20.0;
  static const radiusPill = 999.0;

  // Bileşen yarıçapları (yükseltilmiş — daha yumuşak, premium his)
  static const cardRadius = 16.0;
  static const buttonRadius = 12.0;
  static const inputRadius = 12.0;
  static const chipRadius = 999.0; // pill chip

  // ── Gölge ────────────────────────────────────────────────────────────────
  static const cardElevation = 0.5;

  /// Kartlar için yumuşak, lacivert-tint gölge (düz görünümden çıkış).
  static const List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Color(0x0F1B2A4A), // ~%6 lacivert
      blurRadius: 16,
      offset: Offset(0, 6),
      spreadRadius: -4,
    ),
    BoxShadow(
      color: Color(0x0A1B2A4A), // ~%4 lacivert
      blurRadius: 6,
      offset: Offset(0, 2),
      spreadRadius: -2,
    ),
  ];

  /// Yükseltilmiş yüzeyler (sticky bar, bottom sheet, FAB) için daha belirgin.
  static const List<BoxShadow> elevatedShadow = [
    BoxShadow(
      color: Color(0x1F1B2A4A), // ~%12 lacivert
      blurRadius: 24,
      offset: Offset(0, 10),
      spreadRadius: -6,
    ),
    BoxShadow(
      color: Color(0x0F1B2A4A),
      blurRadius: 8,
      offset: Offset(0, 3),
      spreadRadius: -3,
    ),
  ];

  /// Standart kart kutusu dekorasyonu — gölge + altın kenarlık + yuvarlatma.
  static BoxDecoration cardDecoration({
    Color? color,
    double radius = cardRadius,
    Color borderColor = AppColors.goldBorder,
  }) {
    return BoxDecoration(
      color: color ?? AppColors.cardBg,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: borderColor, width: 1),
      boxShadow: cardShadow,
    );
  }
}
