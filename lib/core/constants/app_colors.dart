import 'package:flutter/material.dart';

class AppColors {
  // ── Marka / Primary ──────────────────────────────────────────────────────────
  static const primary     = Color(0xFF1B2A4A); // Lacivert
  static const primaryDark = Color(0xFF0F1D35); // Koyu lacivert
  static const primaryMid  = Color(0xFF243558); // Orta lacivert
  static const primaryLight= Color(0xFF3A5080); // Açık lacivert

  // ── Altın ────────────────────────────────────────────────────────────────────
  static const gold        = Color(0xFFC9A84C); // Ana altın
  static const goldLight   = Color(0xFFE2C97A); // Açık altın (metin, vurgu)
  static const goldBorder  = Color(0xFFD4B86A); // Kenarlık altını
  static const goldSubtle  = Color(0xFFEADEBB); // Çok açık altın (hover)
  static const goldBg      = Color(0xFFFDF6E3); // Altın zemin tonu (tablo header)

  // ── Arka Planlar ─────────────────────────────────────────────────────────────
  static const pageBg = Color(0xFFFFFFFF); // Sayfa zemini: beyaz
  static const cardBg = Color(0xFFFFFFFF); // Kart zemini: beyaz

  // ── Sidebar (Lacivert) ───────────────────────────────────────────────────────
  static const sidebarBg          = Color(0xFF1B2A4A);
  static const sidebarHover       = Color(0xFF243558);
  static const sidebarSelectedBg  = Color(0xFF0F1D35);
  static const sidebarSelected    = Color(0xFFE2C97A); // altın vurgu
  static const sidebarText        = Color(0xFFB0BDD4); // pastel mavi-gri
  static const sidebarTextActive  = Color(0xFFE2C97A); // açık altın

  // ── Ödeme / İşlem Renkleri ───────────────────────────────────────────────────
  static const cash         = Color(0xFF1B7A45); // Nakit – orman yeşili
  static const pos          = Color(0xFF1B6A9A); // POS – çelik mavi
  static const openAccount  = Color(0xFFC9A84C); // Açık Hesap – altın
  static const splitPayment = Color(0xFF6B4FA0); // Parçalı – mor

  // ── Durum Renkleri ───────────────────────────────────────────────────────────
  static const success = Color(0xFF1B7A45);
  static const danger  = Color(0xFFC0392B);
  static const warning = Color(0xFFD4930A);
  static const info    = Color(0xFF1B6A9A);

  // ── Yazı ─────────────────────────────────────────────────────────────────────
  static const textPrimary   = Color(0xFF1B2A4A); // Lacivert – ana metin
  static const textSecondary = Color(0xFF4A5568); // Koyu gri
  static const textMuted     = Color(0xFF8898AA); // Soluk gri
  static const textOnDark    = Color(0xFFFFFFFF); // Koyu zeminde beyaz

  // ── Kenarlık / Bölücü ────────────────────────────────────────────────────────
  static const border  = Color(0xFFD4B86A); // Altın kenarlık
  static const divider = Color(0xFFEADEBB); // Açık altın bölücü

  // ── Tablo ────────────────────────────────────────────────────────────────────
  static const tableHeader   = Color(0xFFFDF6E3); // Altın zemin tonu
  static const tableRowHover = Color(0xFFF5EBCC); // Hover altın
}
