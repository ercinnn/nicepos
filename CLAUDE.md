# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## ⚑ Oturum Başlangıcı — Tasarım (ÖNCE BUNU OKU)

Bu proje **tasarım-lideri** agent mimarisiyle yürür (varsayılan agent: `tasarim-lideri`,
bkz. `.claude/settings.json`). Her tasarım oturumuna şu sırayla başla:

1. **`design/design-tokens.md`** — tek doğru kaynak (TEK SOURCE OF TRUTH). Palet, tipografi,
   spacing ve **imza öğesi (Hero Tutar + Altın Ray)** burada. Durum: **v1 ONAYLANDI** +
   §5'e "Ödeme türü butonu" ve "Altın ekonomisi" maddeleri eklendi.
2. **Memory'i oku** (kaldığın yer + sıradaki iş burada tutulur):
   - `memory/MEMORY.md` (indeks)
   - `memory/design-agent-workflow.md` (tasarım turunun güncel ilerleme durumu)

**Güncel durum (özet):** Satış ekranı tasarımı **bitti** (2 görsel QA turu PASS + masaüstü
sepet tablosu responsive kırılması düzeltildi). 🔴 **Sıradaki ilk iş:** son doğrulama QA
turunu (`gorsel-elestirmen`) tekrar çalıştır — **1280/1366/1440px** responsive teyidi +
`flutter analyze`. Ardından sıradaki ekran: **satış grafikleri**. Detaylar memory'de.

> Kural: kod yazmadan önce yön ve token kararı `tasarim-lideri` üzerinden geçer; ekran
> tasarımcıları token'ı okur ama değiştirmez.

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
| `dailySalesProvider(days)` | `autoDispose family` | Dashboard günlük satış grafiği (8/15/30 gün). `monthlySalesProvider` hâlâ tanımlı ama dashboard'da artık kullanılmıyor |
| `customerSalesProvider(query)` / `customerPaymentsProvider(id)` | `autoDispose family` | Müşteri geçmiş işlemleri |

### Satış Akışı

`SalesCart` (Riverpod notifier) 5 müşteri sekmesini yönetir.

**Canlı ürün arama (`_LiveProductSearchField`, `sales_screen.dart`):** Üstteki uzun arama
çubuğu hem web hem mobilde. Tam barkod okutulup Enter'a basılınca ürün doğrudan sepete eklenir
(`onSubmitted` → `_onBarcodeSubmitted`). Kullanıcı harf/rakam yazdıkça (250 ms debounce) girilen
metni **içeren** ürünler çubuğun altında açılan canlı listede gösterilir (`OverlayPortal` +
`CompositedTransformFollower`; `productRepository.fetchAll(query)` substring + Türkçe-duyarlı).
Listeye dokunmak `TextFieldTapRegion` ile odağı düşürmeden seçimi işler → sepete ekler, alanı
temizler, odağı geri verir.

**Hızlı ürünler grup sekmeleri (`quick_products_panel.dart`):** Grup (kategori) sekmeleri yatay
kaydırma yerine **`Wrap`** ile dizilir — sığmayan sekmeler alt satıra geçer (`_GroupChip`).

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
- **Barkod gösterimi:** Satılan ürünlerin barkodu görünür (web: tabloda **Barkod** kolonu; mobil: ürün adı altında). `SaleItem.barcode` alanı `sale_items` tablosunda saklanmaz — `fetchItems` sorgusunda `products(barcode)` join'i ile gelir (muhtelif kalemlerde null).
- **Yazdır (yalnızca web):** Masaüstü dialog'da `kIsWeb` korumalı **Yazdır** butonu → A4 dikey sepet detayını yeni pencerede açıp otomatik yazdırır. `sale_print.dart` conditional export: `sale_print_web.dart` (`package:web` Blob URL + `<body onload>` print) / `sale_print_stub.dart` (mobil no-op). Excel export ile aynı desen.
- **Satışı Sil:** `SalesRepository.deleteSale()` → stok iadesi (`increment_product_stock` RPC) + satışa bağlı `customer_payments` (borç) silme + sale_items/sales silme. Çağıran ekran `updated == true` ile listeyi yeniler.

### Dashboard (Anasayfa)

`lib/features/home/.../widgets/dashboard_section.dart` — kısayol kartlarının altında:
- **Hero bandı:** bugünkü ciro (büyük tabular rakam + altın ray) + dünden % değişim rozeti
- **Stat kartları satırı (`_StatCardsRow`):** Satış Adedi / Aylık Ciro / Aylık Adet. Masaüstünde
  `IntrinsicHeight(Row(crossAxisAlignment: stretch, [Expanded...]))`.
  ⚠️ **Önemli:** Bu Row kaydırılabilir sayfada (sınırsız yükseklik) `IntrinsicHeight` olmadan
  "BoxConstraints forces an infinite height" hatası verir ve **tüm dashboard'u çökertir** (grafik
  dahil hiçbir şey render olmaz). Stretch'li/Expanded'lı her Row için aynı kural geçerli.
- **Tek çizgi grafik (`_DailySalesChartCard`, `fl_chart`):** son N günün günlük cirosu —
  `dailySalesProvider(days)`. Web: 8/15/30 gün seçilebilir (varsayılan 30), grafik ekran
  genişliğinin %90'ı (`LayoutBuilder + Center + SizedBox(width: maxWidth*0.9)` — `FractionallySizedBox`
  dikey Column'da sonsuz yükseklik verdiği için kullanılmaz). Mobil (`compact: true`): sabit son
  8 gün, seçici yok. X ekseninde her gün için **GG/AA/YY** tarihi + altında Türkçe gün kısaltması
  (Pzt..Pzr, `DateTime.weekday`). Eski Aylık Satış grafiği kaldırıldı.
- **Regresyon testi:** `test/dashboard_render_test.dart` — masaüstü genişliğinde dashboard'u sahte
  provider'larla render edip "infinite height" hatası atmadığını + grafiğin göründüğünü doğrular.

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
- Arama barının sağında **kamera ile barkod okutma** butonu (`mobile_scanner`, `kIsWeb` guard)

Varsayılan kolonlar (desktop): Barkod, Stok, Alış Fiyatı, Fiyat 1

**Arama (`ProductRepository`):** `fetchAll(query)` Türkçe-duyarlı (İ/i, I/ı katlaması) — `name`/`barcode`/`stock_code` üzerinde `ilike` OR varyantları (`_buildSearchOr`).

**Ürün formu (`product_form_screen.dart`):** Kâr alanı düzenlenebilir; kâr ↔ satış fiyatı çift yönlü hesaplanır. Sayısal girişlerde virgül **ve** nokta ondalık ayıracı kabul edilir.

### Excel Export

`lib/features/products/presentation/widgets/excel_export.dart` — conditional export:
- **Web** (`dart.library.js_interop`): `excel_export_web.dart` → `package:web` blob download
- **Mobil** (`dart.library.io`): `excel_export_mobile.dart` → `path_provider` temp dizinine yazar, yolu SnackBar'da gösterir

### Raporlar

`/reports` rotası 3 sekme:
1. **Günlük Rapor** — tarih seçimi, nakit/POS/açık hesap özeti
2. **Tarihsel Rapor** — iki tarih arası ciro
3. **Ürün Raporları** — ürün arama, zamana göre fiyat ve satış geçmişi

Günlük ve Tarihsel rapor tablolarında iskonto sütunu **`% 82.25`** formatında gösterilir
(`'% ${s.discountPercent.toStringAsFixed(2)}'`, noktadan sonra 2 hane).

### Veritabanı (Supabase)

Şema migration'ları: `supabase/migrations/` (DDL anon key ile çalıştırılamaz → Supabase SQL Editor'da uygulanır).
- `sales` tablosu iskontoyu **birebir** saklar: `discount_percent` (geriye dönük uyumluluk) + `discount_amount` (kesin TL) + `discount_type` (`'percent'` | `'tl'`). Bkz. `0008_discount_amount.sql`. `SaleEditScreen` kaydedilen tür/değerle açılır → yuvarlama farkı olmaz.
- `customer_balances` görünümü borcu `customer_payments` hareketlerinden hesaplar; bu yüzden bir hareketi/satışı silmek borcu doğrudan günceller.
- RPC'ler: `generate_sale_code`, `increment_product_stock` (stok iadesi), stok düşürme.

### Deploy — GitHub Pages

Site: `https://ercinnn.github.io/nicepos`
Repo: `https://github.com/ercinnn/nicepos`
- Branch: `master`, Folder: `/docs`
- **Yerel klasör (`C:\Projects\nice-pos`) artık remote'un birebir aynası olan gerçek bir git deposu**
  (`origin` → nicepos, `core.autocrlf false`). Deploy **doğrudan** bu klasörden yapılır — eski
  clone+copy+push fallback'ine artık gerek yok. Akış: `flutter build web ...` → `Remove-Item -Recurse
  -Force docs; Copy-Item -Recurse build\web docs` → `git add -A; git commit; git push origin master`.
- Push öncesi `git fetch` + `git log origin/master..master` ile fast-forward olduğunu teyit et.
- `docs/main.dart.js` build'den sonra mutlaka güncellenmelidir (kod değişikliği sonrası rebuild zorunlu).
- `.gitignore` `/build/*` yoksayar ama `!/build/web` izler → repo HEM `build/web` HEM `docs` tutar; deploy'da ikisi de güncellenir.
- **PowerShell commit mesajı uyarısı:** Çok satırlı / çift tırnak içeren mesajlarda `git commit -m @'...'@`
  here-string'i bozulabilir (kapanış `'@` sütun 0'da olmalı; çift tırnak parse'ı bozar). Güvenlisi:
  tek satırlık `git commit -m '...'` (çift tırnaksız).
- Service worker önbelleği: kullanıcı yeni deploy'u göremezse genelde tarayıcı/SW cache'idir → hard
  refresh / SW unregister / gizli pencere. (Ama "göremiyorum" şikâyetinde önce **render hatası**
  ihtimalini ele: kaydırılabilir sayfada stretch'li Row'lar için yukarıdaki IntrinsicHeight notuna bak.)
- **Bağımlılık uyarısı:** `supabase_flutter` 2.15.x web'de açılış hatası veriyordu (`passkeys_web`/`ua_client_hints` → `dart:html`). Çalışan sürüm **2.14.2**; `pubspec.lock` bu sürümde tutulmalı.

## Önemli Konvansiyonlar

- **Model sınıfları:** `fromMap()` + `toInsertMap()`, ORM yoktur
- **Repository'ler:** `Supabase.instance.client` doğrudan — tekil örüntü
- **Dil:** UI metinleri ve yorumlar Türkçedir
- **Tarih:** `initializeDateFormatting('tr_TR')`, formatlama `lib/core/utils/formatters.dart`
- **Dialog context:** `showDialog(builder: (dialogContext) => ...)` — `Navigator.pop` için her zaman `dialogContext` kullan, parent `context` değil. State güncellemesi pop'tan SONRA yapılmalı.
- **Kamera:** `mobile_scanner` — `kIsWeb` guard ile sadece native'de gösterilir
- **CartItem:** `barcode` alanı var — `addProduct` çağrısında `product.barcode` iletilir
- **Layout (kaydırılabilir sayfa = sınırsız yükseklik):** `SingleChildScrollView > Column` içinde
  `crossAxisAlignment: stretch` + `Expanded` çocuklu `Row` → "infinite height" hatası; `IntrinsicHeight`
  ile sar. `FractionallySizedBox` (heightFactor null) dikey Column'da aynı sonsuz yükseklik hatasını
  verir → genişlik için `LayoutBuilder + SizedBox(width: ...)` kullan. Bu tür render hataları
  `flutter analyze`'da görünmez; widget testiyle yakalanır.
