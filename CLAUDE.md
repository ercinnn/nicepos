# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

## Supabase Kimlik Bilgileri

```
SUPABASE_URL=https://maogkrllltlxkfdwfsdj.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1hb2drcmxsbHRseGtmZHdmc2RqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODE1MDk3NjQsImV4cCI6MjA5NzA4NTc2NH0.BsPCU9Hx1OuMf-JI7TU4I6SRuSKsLcmL2MIpQc2gKp0
```

## Commands

```powershell
# Yerel geliştirme — web
flutter run -d chrome `
  --dart-define=SUPABASE_URL=https://maogkrllltlxkfdwfsdj.supabase.co `
  "--dart-define=SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1hb2drcmxsbHRseGtmZHdmc2RqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODE1MDk3NjQsImV4cCI6MjA5NzA4NTc2NH0.BsPCU9Hx1OuMf-JI7TU4I6SRuSKsLcmL2MIpQc2gKp0"

# Yerel geliştirme — Android (USB/emülatör)
flutter run -d android `
  --dart-define=SUPABASE_URL=https://maogkrllltlxkfdwfsdj.supabase.co `
  "--dart-define=SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1hb2drcmxsbHRseGtmZHdmc2RqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODE1MDk3NjQsImV4cCI6MjA5NzA4NTc2NH0.BsPCU9Hx1OuMf-JI7TU4I6SRuSKsLcmL2MIpQc2gKp0"

flutter analyze              # Lint / statik analiz
flutter test                 # Tüm testleri çalıştır
dart run build_runner build --delete-conflicting-outputs  # Riverpod kod üretimi

# GitHub Pages deploy
flutter build web --release --base-href /nicepos/ `
  --dart-define=SUPABASE_URL=https://maogkrllltlxkfdwfsdj.supabase.co `
  "--dart-define=SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1hb2drcmxsbHRseGtmZHdmc2RqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODE1MDk3NjQsImV4cCI6MjA5NzA4NTc2NH0.BsPCU9Hx1OuMf-JI7TU4I6SRuSKsLcmL2MIpQc2gKp0"
# Sonra: Remove-Item -Recurse -Force docs; Copy-Item -Recurse build\web docs; git add docs; git commit; git push

# Android release APK
flutter build apk --release `
  --dart-define=SUPABASE_URL=https://maogkrllltlxkfdwfsdj.supabase.co `
  "--dart-define=SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1hb2drcmxsbHRseGtmZHdmc2RqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODE1MDk3NjQsImV4cCI6MjA5NzA4NTc2NH0.BsPCU9Hx1OuMf-JI7TU4I6SRuSKsLcmL2MIpQc2gKp0"
# Çıktı: build\app\outputs\flutter-apk\app-release.apk
```

## Ortam Değişkenleri

`.env` kullanılmaz. Supabase değerleri dart-define ile build'e gömülür:

1. **Yerel geliştirme:** `flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`
2. **Web deploy / APK:** `flutter build ... --dart-define=...` ile derleme anında gömülür

`lib/core/supabase/supabase_config.dart` — `String.fromEnvironment()` ile okur, eksikse `ConfigMissingScreen` gösterir.

## Platformlar

| Platform | Durum | Notlar |
|---|---|---|
| Web (GitHub Pages) | ✅ | `docs/` klasörü, base-href `/nicepos/` |
| Android APK | ✅ | `android/` klasörü mevcut, INTERNET + CAMERA izinleri |

**Gradle heap:** `android/gradle.properties` → `-Xmx3G` (8GB RAM makine için düşürüldü, OOM crash önlenir)

## Mimari

### Katmanlar

```
lib/
  core/
    constants/     # AppColors, AppSizes
    theme/         # app_theme.dart + app_theme.g.dart (Riverpod provider)
    utils/
      formatters.dart
      responsive.dart   # isMobile (<650px), isDesktop extension on BuildContext
    supabase/      # SupabaseConfig, supabaseClientProvider
  app/             # Router, AppScaffold (web: sidebar; mobil: Drawer + BottomNav)
  features/
    auth/          # Login, ConfigMissingScreen
    home/          # Anasayfa — responsive kart grid (LayoutBuilder)
    products/      # Ürünler, Ürün Grupları
    customers/     # Müşteri listesi, detay, ödeme
    sales/         # Satış ekranı — 5 sekme, sepet, ödeme paneli, hızlı ürünler
    reports/       # Günlük / Tarihsel / Ürün raporları (3 sekme)
```

### Responsive Tasarım

Breakpoint: `lib/core/utils/responsive.dart`
- `context.isMobile` → genişlik < 650px
- `context.isDesktop` → genişlik ≥ 650px

**AppScaffold:**
- Desktop: daraltılabilir sol sidebar (220px / 56px)
- Mobil: AppBar + `Drawer` (tüm nav) + `BottomNavigationBar` (4 ana sekme)

### Tasarım Sistemi

Tek kaynak: `lib/core/theme/app_theme.dart`
- **`appThemeProvider`** — `@Riverpod(keepAlive: true)`
- **Palet:** Beyaz arka plan, lacivert (#1B2A4A) butonlar, altın (#D4B86A) kenarlıklar
- Renk sabitleri: `lib/core/constants/app_colors.dart`

### State Yönetimi — Riverpod Generator

TÜM provider'lar `@riverpod` / `@Riverpod(keepAlive: true)` annotation ile üretilir. Her dosyada `part '...g.dart'` direktifi zorunludur.

| Provider | Tür | Açıklama |
|---|---|---|
| `appThemeProvider` | `keepAlive` | MaterialApp teması |
| `salesCartProvider` | `keepAlive Notifier` | 5 müşteri sekmesi, sepet, iskonto |
| `paymentInputProvider` | `keepAlive Notifier` | Ödeme modu seçimi |
| `productColumnsProvider` | `keepAlive Notifier` | Ürün tablosu görünür kolonlar |
| `reportRepositoryProvider` | `keepAlive` | Rapor repository |
| `dailyReportProvider` | `autoDispose family` | Günlük rapor |

### Satış Akışı

`SalesCart` (Riverpod notifier) 5 müşteri sekmesini yönetir.

**Mobil satış ekranı:**
- Barkod alanı sağında kamera butonu (`mobile_scanner` paketi)
- Kamera açıldığında `BarcodeScannerModal` (tam ekran, torch + kamera çevirme)
- Sepet: kart listesi — adet kutusuna tıkla → dialog; sola kaydır → sil
- `Ödeme Al` butonu → `DraggableScrollableSheet` içinde `PaymentPanel`
- Müşteri sekmeleri: `SingleChildScrollView(horizontal)` ile kaydırılabilir

**Sepet kart layout (mobil):**
- %15 sol: adet (dokunarak düzenle — `dialogContext` ile pop, state sonra güncellenir)
- %65 orta: ürün adı (üst) + barkod sol · birim fiyat sağ (alt)
- %20 sağ: satır tutarı

İskonto: `DiscountType.percent` veya `DiscountType.tl`, hem satır hem sepet bazında.

Ödeme tamamlama: `SalesRepository.completeSale()` → RPC → sales + sale_items insert → stok düşür → borç hareketi.

### Ürünler Sayfası

**Desktop:** DataTable + kolon seçici (`productColumnsProvider`) + checkbox seçim + toplu silme

**Mobil:** Kart listesi — her kart:
- Sol üst: ürün adı
- Sol alt: barkod
- Sağ: Stok · Alış · Fiyat 1
- Karta tıkla → `/products/:id` düzenleme ekranı

Varsayılan kolonlar (desktop): Barkod, Stok, Alış Fiyatı, Fiyat 1

### Excel Export

`lib/features/products/presentation/widgets/excel_export.dart` — conditional export:
- **Web** (`dart.library.js_interop`): `excel_export_web.dart` → `package:web` blob download
- **Mobil** (`dart.library.io`): `excel_export_mobile.dart` → `path_provider` temp dizinine yazar, yolu SnackBar'da gösterir

### Raporlar

`/reports` rotası 3 sekme:
1. **Günlük Rapor** — tarih seçimi, nakit/POS/açık hesap özeti
2. **Tarihsel Rapor** — iki tarih arası ciro
3. **Ürün Raporları** — ürün arama, zamana göre fiyat ve satış geçmişi

### Deploy — GitHub Pages

Site: `https://ercinnn.github.io/nicepos`
Repo: `https://github.com/ercinnn/nicepos`
- Branch: `master`, Folder: `/docs`
- `docs/main.dart.js` build'den sonra mutlaka güncellenmelidir (kod değişikliği sonrası rebuild zorunlu)

## Önemli Konvansiyonlar

- **Model sınıfları:** `fromMap()` + `toInsertMap()`, ORM yoktur
- **Repository'ler:** `Supabase.instance.client` doğrudan — tekil örüntü
- **Dil:** UI metinleri ve yorumlar Türkçedir
- **Tarih:** `initializeDateFormatting('tr_TR')`, formatlama `lib/core/utils/formatters.dart`
- **Dialog context:** `showDialog(builder: (dialogContext) => ...)` — `Navigator.pop` için her zaman `dialogContext` kullan, parent `context` değil. State güncellemesi pop'tan SONRA yapılmalı.
- **Kamera:** `mobile_scanner` — `kIsWeb` guard ile sadece native'de gösterilir
- **CartItem:** `barcode` alanı var — `addProduct` çağrısında `product.barcode` iletilir
