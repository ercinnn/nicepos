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
  app/             # Router, AppScaffold (web: sidebar + canlı saat; mobil: Drawer + BottomNav)
  features/
    auth/          # Login, ConfigMissingScreen
    home/          # Anasayfa — kısayol kart grid + Dashboard (stat kartları + grafikler)
    products/      # Ürünler, Ürün Grupları
    customers/     # Müşteri listesi, detay (geçmiş işlem yönetimi), ödeme
    sales/         # Satış ekranı — 5 sekme, sepet, ödeme paneli, hızlı ürünler
    reports/       # Günlük / Tarihsel / Ürün raporları (3 sekme)
```

### Responsive Tasarım

Breakpoint: `lib/core/utils/responsive.dart`
- `context.isMobile` → genişlik < 650px
- `context.isDesktop` → genişlik ≥ 650px

**AppScaffold:**
- Desktop: daraltılabilir sol sidebar (220px / 56px) + üst bar'da **canlı tarih+saat** (`_LiveClock`, her saniye `Timer.periodic`; eski arama kutusunun yerinde) · e-posta · Çıkış
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
| `dashboardRepositoryProvider` | `autoDispose` | Dashboard repository |
| `todaySummaryProvider` / `yesterdaySummaryProvider` / `monthSummaryProvider` / `lastMonthRevenueProvider` | `autoDispose` | Dashboard stat kartları |
| `dailySalesProvider(days)` / `monthlySalesProvider(months)` | `autoDispose family` | Dashboard grafikleri (seçilebilir aralık) |
| `customerSalesProvider(query)` / `customerPaymentsProvider(id)` | `autoDispose family` | Müşteri geçmiş işlemleri |

### Satış Akışı

`SalesCart` (Riverpod notifier) 5 müşteri sekmesini yönetir.

**Mobil satış ekranı:**
- Barkod alanı sağında kamera butonu (`mobile_scanner` paketi)
- Kamera açıldığında `BarcodeScannerModal` (tam ekran, torch + kamera çevirme)
- Sepet: kart listesi — adet kutusuna tıkla → dialog; sola kaydır → sil
- `Ödeme Al` butonu → `DraggableScrollableSheet` içinde `PaymentPanel`
- Müşteri sekmeleri: `SingleChildScrollView(horizontal)` ile kaydırılabilir

**Sepet miktar kontrolü (`cart_table.dart`):** Miktar kutusunun solunda kırmızı `−`, sağında lacivert `+` butonu (−1/+1, min 1). Kutuya yazılan değer her tuş vuruşunda satır tutarını **anında** günceller (ondalık destekli, ör. 2.50). Masaüstü: satır içi; mobil: adet kutusuna dokun → dialog (içinde canlı toplam + −/+).

İskonto: `DiscountType.percent` veya `DiscountType.tl` (enum `cart_item.dart`), hem satır hem sepet bazında.

Ödeme tamamlama: `SalesRepository.completeSale()` → RPC → sales + sale_items insert → stok düşür → borç hareketi. `sales` kaydına `discount_percent`, `discount_amount` (kesin TL) ve `discount_type` yazılır.

### Satış Düzenleme & Silme (`SaleEditScreen`)

Rapor ekranlarından (günlük/tarihsel/ürün) **ve müşteri detayından** bir satışa tıklayınca açılır; kalemleri + iskontoyu düzenler.
- **İskonto:** TL (₺) / yüzde (%) `SegmentedButton` ile düzenlenir; **Ara Toplam + İskonto + İndirimli Toplam** birlikte gösterilir. İskonto **birebir** saklanır (bkz. Veritabanı notu).
- **Satışı Sil:** `SalesRepository.deleteSale()` → stok iadesi (`increment_product_stock` RPC) + satışa bağlı `customer_payments` (borç) silme + sale_items/sales silme. Çağıran ekran `updated == true` ile listeyi yeniler.

### Dashboard (Anasayfa)

`lib/features/home/.../widgets/dashboard_section.dart` — kısayol kartlarının altında:
- **4 stat kartı:** Toplam Satış / Net Kazanç (Bugün · Bu Ay) + önceki döneme göre % değişim rozeti
- **2 çizgi grafik** (`fl_chart`): Günlük Satış (seçilebilir gün) ve Aylık Satış (seçilebilir ay) — `dailySalesProvider(days)` / `monthlySalesProvider(months)`

### Müşteri Detayı — Geçmiş İşlem Yönetimi

`customer_detail_screen.dart`:
- **Alışverişler** ve **Ödeme/Borç Hareketleri** listelerinde her satırda kırmızı **tekil silme** + bölüm başlığında **"Tümünü Sil"** (toplu)
- Geçmiş satışa tıkla → `SaleEditScreen` (düzenle)
- `CustomerRepository.deletePayment(id)`; silme/düzenleme sonrası `_invalidateHistory()` ile satış/ödeme/bakiye provider'ları yenilenir

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

### Veritabanı (Supabase)

Şema migration'ları: `supabase/migrations/` (DDL anon key ile çalıştırılamaz → Supabase SQL Editor'da uygulanır).
- `sales` tablosu iskontoyu **birebir** saklar: `discount_percent` (geriye dönük uyumluluk) + `discount_amount` (kesin TL) + `discount_type` (`'percent'` | `'tl'`). Bkz. `0008_discount_amount.sql`. `SaleEditScreen` kaydedilen tür/değerle açılır → yuvarlama farkı olmaz.
- `customer_balances` görünümü borcu `customer_payments` hareketlerinden hesaplar; bu yüzden bir hareketi/satışı silmek borcu doğrudan günceller.
- RPC'ler: `generate_sale_code`, `increment_product_stock` (stok iadesi), stok düşürme.

### Deploy — GitHub Pages

Site: `https://ercinnn.github.io/nicepos`
Repo: `https://github.com/ercinnn/nicepos`
- Branch: `master`, Folder: `/docs`
- `docs/main.dart.js` build'den sonra mutlaka güncellenmelidir (kod değişikliği sonrası rebuild zorunlu)
- `.gitignore` `/build/*` yoksayar ama `!/build/web` izler → repo HEM `build/web` HEM `docs` tutar; deploy'da ikisi de güncellenir.
- **Bağımlılık uyarısı:** `supabase_flutter` 2.15.x web'de açılış hatası veriyordu (`passkeys_web`/`ua_client_hints` → `dart:html`). Çalışan sürüm **2.14.2**; `pubspec.lock` bu sürümde tutulmalı.

## Önemli Konvansiyonlar

- **Model sınıfları:** `fromMap()` + `toInsertMap()`, ORM yoktur
- **Repository'ler:** `Supabase.instance.client` doğrudan — tekil örüntü
- **Dil:** UI metinleri ve yorumlar Türkçedir
- **Tarih:** `initializeDateFormatting('tr_TR')`, formatlama `lib/core/utils/formatters.dart`
- **Dialog context:** `showDialog(builder: (dialogContext) => ...)` — `Navigator.pop` için her zaman `dialogContext` kullan, parent `context` değil. State güncellemesi pop'tan SONRA yapılmalı.
- **Kamera:** `mobile_scanner` — `kIsWeb` guard ile sadece native'de gösterilir
- **CartItem:** `barcode` alanı var — `addProduct` çağrısında `product.barcode` iletilir
