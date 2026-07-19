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
    labels/        # Etiket — raf etiketi A4 yazdırma (24-hane barkod + Code128 + logo)
    kasa/          # Kasa — gelir-gider defteri + mutabakat + firma giderleri
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
| `yearToDateRevenueProvider` / `last365DaysRevenueProvider` | `autoDispose` | "Yıllık Ciro" (YTD) / "Son 365 Günlük Ciro" kartları — `sales_revenue_between` RPC (bkz. Veritabanı notu) |
| `dailySalesProvider(days)` | `autoDispose family` | Dashboard günlük satış grafiği (8/15/30 gün). `monthlySalesProvider` hâlâ tanımlı ama dashboard'da artık kullanılmıyor |
| `currentYearMonthlyProvider` / `historicalYearlyProvider` | `keepAlive` | Yıllık aylık toplamlar (cari yıl / geçmiş yıllar) — hem "Yıllık Ciro Karşılaştırma" hem "Yıllık Ortalama Ciro" grafiği bu ikisini paylaşır |
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

Rapor ekranlarından (günlük/tarihsel/ürün) **ve müşteri detayından** bir satışa tıklayınca açılır; kalemleri + iskontoyu + **ödeme türünü** düzenler.
- **İskonto:** TL (₺) / yüzde (%) `SegmentedButton` ile düzenlenir; **Ara Toplam + İskonto + İndirimli Toplam** birlikte gösterilir. İskonto **birebir** saklanır (bkz. Veritabanı notu).
- **Ödeme türü:** Nakit / Pos / Açık Hesap / Parçalı `_PaymentTypeButton` ile seçilir (satış ekranı `payment_panel.dart` buton dili birebir tekrar; design-tokens §5 — nötr beyaz zemin + sol renk şeridi, seçiliyken türün renginde dolgu). Parçalı seçiliyken "Nakit Tutarı" + "Kart/POS Tutarı" ayrı girilir. Net toplam (`_netTotal`) seçili türe göre yeniden dağıtılır: nakit→cash=net · pos→card=net · açık hesap→debt=net · parçalı→cash/card girilen, debt=(net−paid).clamp(0,∞). "Kalan Borç" önizlemesi borç varsa `AppColors.danger` ile gösterilir. Hem web (sağ kolon) hem mobil (alt çubuk). `updateSale`'e `paymentType` (+ `customerId`, `saleCode`) geçer.
- **Borç mutabakatı (`updateSale`):** `sales.payment_type` güncellenir. Önce bu satışa ait otomatik borç hareketi silinir (`customer_payments.delete().eq('sale_id', saleId)`) — ödeme türü değişince (ör. açık hesap → nakit) hayalet borç kalmaz. Sonra `customerId != null && remainingDebt > 0` ise yeni `borc` hareketi eklenir (`completeSale`/`deleteSale` ile tutarlı; müşteri yoksa borç sadece `sales.remaining_debt`'te kalır).
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
- **Yıllık Ciro / Son 365 Günlük Ciro kartları — sunucu tarafı SUM:** `DashboardRepository.fetchYearToDateRevenue()`,
  `fetchLast365DaysRevenue()`, `fetchLastMonthRevenue()` eskiden o tarih aralığındaki TÜM `sales`
  satırlarını sayfalayarak çekip Dart'ta topluyordu (~5sn). Artık `sales_revenue_between(start_ts,
  end_ts)` RPC'sini (bkz. Veritabanı notu, `0015_sales_revenue_rpc.sql`) çağırıyor — Postgres
  `sale_date` index'i ile tek `SUM()` sorgusu, istemci tek sayı alır (~1sn).
- **Yıllık Ortalama Ciro grafiği (`_YillikOrtalamaCiroCard`):** Kümülatif günlük ortalama —
  her yıl KENDİ İÇİNDE değerlendirilir (Ocak'ta sıfırlanır). Ay sonu noktası = o yılın Ocak'ından o
  aya kadarki TOPLAM ciro ÷ o tarihe kadarki TOPLAM gün sayısı (o ayın kendi ortalaması DEĞİL).
  Cari yılın bitmemiş ayı (ör. bugün 17 Temmuzsa Temmuz noktası yalnız ilk 17 günü kapsar) —
  `sales_monthly_totals` view'ı zaten yalnızca gerçekleşmiş satışları içerdiği için ekstra sorguya
  gerek yok; "Yıllık Ciro Karşılaştırma" kartıyla AYNI iki provider (`currentYearMonthlyProvider` /
  `historicalYearlyProvider`) yeniden kullanılır (`_kumulatifOrtalamaSpots` helper'ı,
  `dashboard_section.dart`). Yıl seçimi sabit 3 yılla sınırlı: bu yıl + önceki 2 yıl, chip'lerle
  aç/kapa (varsayılan hepsi açık).

### Müşteri Detayı — Geçmiş İşlem Yönetimi

`customer_detail_screen.dart`:
- **Alışverişler** ve **Ödeme/Borç Hareketleri** listelerinde her satırda kırmızı **tekil silme** + bölüm başlığında **"Tümünü Sil"** (toplu)
- Geçmiş satışa tıkla → `SaleEditScreen` (düzenle)
- `CustomerRepository.deletePayment(id)`; silme/düzenleme sonrası `_invalidateHistory()` ile satış/ödeme/bakiye provider'ları yenilenir

### Ürünler Sayfası

**Desktop:** `DataTable` + kolon seçici (`productColumnsProvider`) + checkbox seçim + toplu silme.
Sabit kolonlar sırası: Checkbox · **Durum** · # · Ürün Adı · (dinamik kolonlar) · İşlem.

- **Satır içi düzenleme (tıkla-düzenle, `_ProductsTable`/`products_list_screen.dart`):** Ürün Adı,
  Stok, Alış, Fiyat 1 hücreleri varsayılan olarak sade `Text` (ucuz); birine **dokununca** o SATIR
  düzenleme moduna geçer ve o 4 hane canlı `TextField`'a döner (`_editingIds` seti,
  `_RowControllers` yalnız düzenlenen satır için lazy kurulur). ⚠️ Performans notu: `DataTable`
  sanallaştırma YAPMAZ — sayfadaki TÜM satırları her zaman `TextField` yapmak (50 satır × 4 hane)
  ilk açılışı gözle görülür yavaşlatır; bu yüzden yalnız dokunulan satır düzenlenebilir.
  İşlem sütununda düzenleme sırasında yeşil **Güncelle** (kaydet) + gri **Vazgeç** (X, iptal) çıkar;
  kaydedince satır otomatik display moduna döner. Başarılı güncellemede sağ üstte **2 saniyelik**
  toast bildirimi (`_showTopRightToast` — `SnackBar` değil, `OverlayEntry`; alt köşede değil sağ
  üstte çıkması için).
- **Durum sütunu (`_StatusBadge`):** Çok Satan (yeşil) / Tükendi (kırmızı) / Pasif (gri) / boş.
  Sunucuda `product_status` view'ından (`0016_product_status.sql`) tek sorguyla çekilir
  (`ProductRepository.fetchStatuses(ids)`, sayfadaki ürün id'leriyle filtreli — ana ürün sorgusundan
  AYRI, ikinci bir istek). Öncelik: Çok Satan > Tükendi > Pasif > boş — tanımlar migration
  dosyasında. Stok/fiyat güncellendiğinde (`_updateProduct`) durum yeniden çekilir.
- **Yoğunlaştırılmış tablo:** `columnSpacing: 28` (varsayılan 56'nın yarısı), hücre fontu 1 kademe
  küçük (`dataTextStyle` fontSize 12, başlık 11), Ürün Adı hücresi 516px (eski 220'nin ~2 katı + 2cm).
- **Arama debounce:** 250ms (`_onSearchChanged`, `Timer`) — Durum sorgusu eklendiğinden beri her
  yükleme 2 ardışık istek attığı için debounce olmadan her tuş vuruşu bu maliyeti tekrarlardı.

**Mobil:** Kart listesi — her kart:
- Sol üst: ürün adı
- Sol alt: barkod
- Sağ: Stok · Alış · Fiyat 1
- Karta tıkla → `/products/:id` düzenleme ekranı
- Arama barının sağında **kamera ile barkod okutma** butonu (`mobile_scanner`, `kIsWeb` guard)

Varsayılan kolonlar (desktop): Barkod, Stok, Alış Fiyatı, Fiyat 1

**Arama (`ProductRepository`):** `fetchAll(query)` Türkçe-duyarlı (İ/i, I/ı katlaması) — `name`/`barcode`/`stock_code` üzerinde `ilike` OR varyantları (`_buildSearchOr`).

**Ürün adı büyük harf zorlaması:** `Product.toInsertMap()` ürün adını `trUpperCase()` (bkz. `core/utils/formatters.dart` — Türkçe-duyarlı i→İ, ı→I) ile kaydeder. `create()`/`update()` HER ikisi `toInsertMap()` üzerinden yazdığı için kaynak farketmeksizin (elle ürün formu, Excel İçe Aktar, Liste Gir, tablo satır içi düzenleme) tek noktadan uygulanır — ayrıca dokunmaya gerek yok. Mevcut küçük/karışık harfle kayıtlı ürünler geriye dönük otomatik güncellenmez, bir sonraki kayıtta düzelir.

**Sütun Filtreleri ve Sıralama (masaüstü, `products_list_screen.dart`):**
- Her sütun başlığında küçük bir filtre ikonu (`_headerWithFilter`) — tıklayınca sütuna özel dialog açılır: metin sütunları (Stok Kodu, Birim, Üst Grup, Grup Adı) "içerir" (ilike), **Barkod BİREBİR eşleşme** (`eq` — "002" yazınca yalnız barkodu tam "002" olan ürün gelir, `.ilike` DEĞİL), sayısal sütunlar (Stok, Kritik Stok, KDV, Alış, Fiyat 1/2) Min/Maks aralık, **Durum** sabit seçenek listesi (Tümü/Çok Satan/Tükendi/Pasif/Boş — `_StatusChoice` sarmalayıcı "Tümü" seçimini dialog'un doğal `null` iptal dönüşünden ayırt eder). Aktif filtreli ikon lacivert dolu görünür. Durum: `ProductFilters` (mutable, `data/models/product_filters.dart` — Liste Gir'deki `ExtractedRow` ile aynı mutable-model deseni), `_ProductsListScreenState._filters`.
- **Sıralama:** sütun başlığına dokun → server-side sıralama (Flutter `DataTable`'ın yerleşik `sortColumnIndex`/`sortAscending`/`DataColumn.onSort` desteği kullanılır, özel ok ikonu gerekmez). Ürün Adı A-Z/Z-A + sayısal sütunlar (Barkod dahil, metin olarak) büyükten küçüğe/küçükten büyüğe. Beyaz liste: `ProductRepository.sortableColumns`; UI tarafı sütun→db-kolonu eşlemesi `_ProductsTableState._dbColumnFor`.
- Filtreler/sıralama **server-side** — `fetchPaged`/`fetchAll`'a `filters`/`sortColumn`/`sortAscending` parametreleriyle geçer, sayfalamayla doğru çalışır (yalnız o an yüklü sayfayı süzmek YANLIŞ olurdu). Excel Aktar ve Ürün Özet de aktif filtre+sıralamayı hesaba katar.
- **`search_products` RPC (`0017`-`0020` migration'ları) — YALNIZ Durum filtresi aktifken kullanılır:** "Durum" `products` tablosunda gerçek bir sütun değil, `product_status` view'ından hesaplanır (view'ın FK'si yok → PostgREST embed filtresi desteklemez). İLK yaklaşım (eşleşen id'leri çekip `id=in.(...)` ile ana sorguya eklemek) "Pasif" gibi çok sayıda ürünü kapsayan durumlarda URL'yi aşırı uzatıp **400 Bad Request** veriyordu; RPC'ye taşındıktan sonra da `product_status`'u TÜM `products`'a JOIN etmek planlayıcının haftalık-satış agregasyonunu **satır başına yeniden hesaplamasına** yol açıp **statement timeout (57014)** verdi — çözüm: `weekly_sales`/`cok_satan` CTE'lerini `MATERIALIZED` işaretlemek (tek seferlik hesaplama zorlanır, bkz. `0018`). Durum filtresi YOKSA repository eski basit PostgREST sorgu zincirini kullanmaya devam eder.
  - ⚠️ **Migration dersi (tekrar düşmemek için):** `p_limit`/`p_offset`'ten ÖNCEYE yeni parametre eklemek (`0019`) fonksiyonun parametre TİP LİSTESİni değiştirdi — Postgres `CREATE OR REPLACE FUNCTION`'ı yalnız isim+tip listesi BİREBİR aynıysa "değiştirir", farklıysa aynı isimde YENİ bir overload yaratır. Sonuç: iki `search_products` birikti, imza belirtmeyen `GRANT`/çağrılar **"function name is not unique"** hatası verdi. Düzeltme (`0020`): `pg_proc` üzerinden o isimdeki TÜM overload'ları `DROP` edip fonksiyonu tek tanım olarak yeniden oluşturmak. **Bir RPC fonksiyonunun parametre listesini değiştiren her migration'da bu deseni (DO bloğuyla eski overload'ları temizle → yeniden oluştur) baştan kullan.**
  - `language sql` fonksiyonda sütun adı parametre olarak `ORDER BY`'a dinamik konulamaz (injection riski) — her sıralanabilir sütun için bir ASC+DESC `CASE` çifti yazılır, yalnız aktif olan çift her satırda non-null kalır.

**Ürün formu (`product_form_screen.dart`):** Kâr alanı düzenlenebilir; kâr ↔ satış fiyatı çift yönlü hesaplanır. Sayısal girişlerde virgül **ve** nokta ondalık ayıracı kabul edilir.
- **Mobilde ürün resmi ekleme alanı YOK** ("Ürün resmi ekle" bölümü yalnız masaüstü `Row`
  dalında kalır; `_buildProductInfoTab`'te `isMobile ? formFields : Row(...imageSection...)`).
  Görsel yükleme/gösterme mantığı (`_pickImage`, `_imageUrl`, `_save()` içindeki upload) DOKUNULMADI
  — sadece mobil UI'dan çıkarıldı, masaüstünden yüklenen görsel mobilde hâlâ korunur/gösterilir.
- **Mobilde Ürün Sil butonu:** yalnız mevcut (yeni değil, `_currentId` dolu) ürün düzenlenirken,
  alt çubukta sol tarafta kırmızı `ElevatedButton.icon` (sağda kaydet butonuyla birlikte `Row`).
  Onay dialogu: başlık "Ürünü Sil", metin `"$ad" ürününü silmek istediğinize emin misiniz?`,
  butonlar **Hayır** / **Sil** (kırmızı). `ProductRepository.delete()` çağırır, foreign-key
  hatasında ("bu ürüne ait satış kaydı var") anlaşılır mesaj gösterir.

### Liste Gir — Tedarikçi Listesi İçe Aktarma

Ürünler sayfasının 4. sekmesi (`ProductsTabsScreen`, yalnız `context.isDesktop` — dikdörtgen çizimi
mouse ile yapılır, pdf.js/Tesseract.js interop'u yalnız web'de çalışır). Tedarikçi PDF/JPEG
listesini yükleyip renkli dikdörtgenlerle sütun işaretleyerek toplu ürün içe aktarma.

- **Akış (`liste_gir_screen.dart`, adım-makinesi):** yükle → sütun seç → önizle/düzenle → kaydet.
- **PDF render + metin çıkarma:** `web/vendor/pdfjs/` altında vendor edilmiş pdf.js (Apache-2.0,
  pinned `5.4.624` — `pdf.min.mjs`/`pdf.worker.min.mjs`) + birinci parti `pdfjs_bridge.js` köprü
  script'i (`window.nicePdfLoad`/`nicePdfRenderAndExtract`/`niceOcrRecognize`, JSON string dönüşleri
  — JS nesne grafiği interop'undan kaçınmak için). `document_page_source_web.dart`/`_stub.dart`
  (conditional export, `sale_print.dart` ile aynı `dart.library.js_interop` deseni) script'leri
  **tembel** (yalnız ekran açılınca) enjekte eder.
- **OCR yedek yolu:** metin katmanı yok/az tespit edilirse (`RenderedPage.hasUsableTextLayer`,
  toplam karakter < eşik) veya doğrudan JPEG/PNG yüklenirse Tesseract.js (ücretsiz, tarayıcıda WASM,
  jsdelivr CDN'den tembel yüklenir — Google Cloud Vision KULLANILMAZ, hesap/kart gerektirmez).
- **Sütun seçimi (`liste_gir_column_select_step.dart`):** 4 sabit renkli çip — kırmızı=Barkod,
  sarı=Ürün Adı, mavi=Adet, yeşil=Alış Fiyatı. Sütun başına TEK bant (yalnız X-aralığı, yükseklik
  tam sayfa); kenar tutamaçlarıyla ince ayar. Çok sayfalı PDF'lerde AYNI X-aralığı tüm sayfalara
  uygulanır (sayfa başına yeniden çizim istenmez).
- **Çıkarma algoritması (`column_row_extractor.dart`, saf Dart, pdf.js VE Tesseract çıktısına karşı
  aynı `PositionedText` şekliyle çalışır):** bant→tip sınıflandırma → y-konumuna göre satır kümeleme
  (medyan yükseklik × 0.6 tolerans) → `_joinNameItems` yalnız GERÇEK görsel boşluk varsa araya boşluk
  ekler (bazı PDF üreticileri Türkçe "İ"yi ayrı font alt-kümesiyle, bitişik ama ayrı bir metin öğesi
  olarak yazar — kör `.join(' ')` yanlış boşluk sokuyordu). `_looksLikeNonProduct` fatura üst/alt
  bilgisindeki alıcı/firma adını (`_knownNonProductPhrases` sabit liste) ve `@` içeren satırları
  (e-posta) ürün olarak saymaz. `consolidateDuplicateBarcodes` aynı barkodlu satırları toplar (adet
  additive, fiyat "son sıfır-olmayan değer kazanır").
- **Türkçe sayı ayrıştırma (`tr_number_parser.dart`):** `parseTrNumber` binlik/ondalık ayraç
  belirsizliğini çözer (`"1.234,56"` → `1234.56`) — `products_list_screen.dart`'taki basit
  `_parseNum`'dan FARKLI, o bu belirsizliği çözmez.
- **Önizleme ızgarası (`liste_gir_review_grid.dart`):** tüm satırlar her zaman düzenlenebilir (liste
  küçük, `products_list_screen.dart`'taki "yalnız dokunulan satır" optimizasyonuna gerek yok). Font
  boyutu küçültülmüş (`_cellFontSize`), Ürün Adı hanesi 1.5× geniş (390px).
  - **Alış Fiyatı Çarpanı:** liste fiyatı iskonto/+KDV nedeniyle gerçek alış fiyatından farklıysa
    (ör. 0,66 / 1,2) tüm satırlara uygulanır — `ExtractedRow.rawPurchasePrice` ham değeri saklar,
    çarpan istenildiği kadar değiştirilebilir; satır elle düzenlenirse mevcut çarpana göre ham
    değere geri çevrilip saklanır (tutarlılık korunur).
  - **Satış Fiyatı Çarpanı (yalnız YENİ ürünler):** barkodu sistemde zaten kayıtlı ürünlerde satış
    fiyatı ürünün mevcut `price1`'i (dokunulmaz, otomatik/siyah renk); barkodu YENİ olan ürünlerde
    satış fiyatı kırmızı fontla vurgulanır (dikkat çeksin diye) ve bu çarpan `alış fiyatı × çarpan`
    olarak öneri hesaplar.
- **Kaydetme:** barkod sistemde eşleşirse **stok additive** (üzerine eklenir), **alış+satış fiyatı
  replace** (yeni değerlerle değiştirilir); eşleşmezse/boşsa yeni ürün oluşturulur. Kaydetmeden hemen
  önce güncel barkod listesiyle `fetchByBarcodes` tekrar sorgulanır (önizleme adımından beri elle
  değişmiş olabilir).
- **Testler:** `test/liste_gir_extractor_test.dart` — saf Dart, tarayıcı gerektirmez
  (`extractRows`/`consolidateDuplicateBarcodes`/`parseTrNumber` senaryoları).

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

### Etiket — Raf Etiketi A4 Yazdırma

`/etiket` rotası (`lib/features/labels/`). Ürün etiketlerini A4 kağıda basmak için **araç/çalışma
ekranı** (tasarım: design-tokens **KARAR v1.10** — **ekran hero'su YOK**, stok listesi token dili).
- **State:** `labelSheetProvider` (`@Riverpod(keepAlive:true)` `LabelSheet` notifier) — 24 hanelik
  `List<LabelSlot?>` + logo data URL; `setSlot/clearSlot/clearAll/setLogo`. Sabitler
  `kLabelColumns=3, kLabelRows=8, kLabelCount=24` (`labels_screen.dart`).
- **Ekran (`labels_screen.dart`):** masaüstü iki bölge — **sol** 24-hane barkod girişi, **sağ** canlı
  A4 önizleme; mobil tek kolon (giriş üstte, önizleme altta `LayoutBuilder+SizedBox` ile ölçekli).
- **Barkod akışı:** hane input'una barkod okut → **Enter** (`onSubmitted`) → satış ekranı
  `_onBarcodeSubmitted` deseninin uyarlaması: önce paylaşılan `barcodeCacheProvider` (sales feature),
  sonra `productRepository.fetchByBarcode`, sonra `fetchAll` (tam eşleşme tercihli) → `price1` çözülür,
  hane dolar, imleç **otomatik bir alt haneye** geçer. Aktif hane = 3px altın sol şerit + ink kenarlık;
  çözülemeyen = `danger` uyarı; ✕ haneyi temizler.
- **A4 önizleme:** sabit 794×1123px (96dpi) tuval → `FittedBox` ile panele ölçeklenir; 3×8 ızgara,
  ~5mm kenar, nötr hairline kesim kılavuzu (altın YOK).
- **Etiket-içi (referans `raf_etiketi.jpg`):** üst bant sol **logo yuvası** (14mm×10mm; yoksa
  `Icons.storefront` / SVG `#1B2A4A` mağaza ikonu fallback) + baskın **FİYAT** (iri bold, `price1`+" TL",
  **altın ray YOK** — etiketin kendi hero'su, app hero'su değil) → ürün adı → **Code128** çizgileri
  (`barcode`/`barcode_widget`) → en alt: barkod no (sol) + oluşturma tarihi (sağ-alt). Baskı siyah/beyaz.
- **Logo yükleme:** `FilePicker.pickFiles(withData:true)` → base64 data URL, önizleme + baskıda kullanılır
  (`keepAlive` ile oturum içi kalıcı).
- **Yazdır / PDF Üret (yalnız `kIsWeb`):** `etiket_print.dart` conditional export
  (`etiket_print_web.dart` / `_stub.dart`) — `sale_print.dart` deseninin birebir kopyası: HTML blob →
  yeni pencere → `window.print()`, Code128 SVG gömülü, `@page{size:A4 portrait;margin:5mm}`. PDF Üret
  aynı pencereyi açar (tarayıcı "PDF olarak kaydet"). Native'de no-op.
- **Paketler:** `barcode`, `barcode_widget`, `file_picker`.

### Veritabanı (Supabase)

Şema migration'ları: `supabase/migrations/` (DDL anon key ile çalıştırılamaz → Supabase SQL Editor'da uygulanır).
- `sales` tablosu iskontoyu **birebir** saklar: `discount_percent` (geriye dönük uyumluluk) + `discount_amount` (kesin TL) + `discount_type` (`'percent'` | `'tl'`). Bkz. `0008_discount_amount.sql`. `SaleEditScreen` kaydedilen tür/değerle açılır → yuvarlama farkı olmaz.
- `customer_balances` görünümü borcu `customer_payments` hareketlerinden hesaplar; bu yüzden bir hareketi/satışı silmek borcu doğrudan günceller.
- RPC'ler: `generate_sale_code`, `increment_product_stock` (stok iadesi), stok düşürme.
- `sales_revenue_between(start_ts, end_ts)` RPC (`0015_sales_revenue_rpc.sql`): `sale_date` index'i ile tek `SUM(total_amount)` sorgusu — dashboard YTD/365-gün/geçen-ay ciro kartları bunu kullanır (bkz. Dashboard notu). `security invoker` (varsayılan), RLS `sales` tablosuyla aynı.
- `product_status` view (`0016_product_status.sql`): Ürünler tablosundaki **Durum** sütununun kaynağı. Öncelik Çok Satan > Tükendi > Pasif > boş. Çok Satan = son 4 haftanın (bugüne göre kayan 7'şer günlük 4 pencere, takvim haftası DEĞİL) HER birinde ≥1 adet satış — `sale_items`/`sales` üzerinden hesaplanır. Tükendi = `stock_quantity <= 0`. Pasif = `products.updated_at` 1 yıldan eski — stok satışla (`decrement_product_stock`/`increment_product_stock` RPC'leri) VEYA elle düzenlemeyle (`Product.toInsertMap()`) değiştiğinde HER ikisi de `updated_at`'i günceller, yani bu tek alan "stok + satış + fiyat" aktivitesinin hepsini kapsar. `ProductRepository.fetchStatuses(ids)` ile `product_id` filtreli okunur (ana ürün sorgusundan ayrı, ikinci istek).
- `search_products(...)` RPC (`0017`→`0018`→`0019`→`0020`, tek fonksiyon — her migration `create or replace` ile üzerine yazar): Ürünler tablosu Durum filtresi aktifken arama+grup+sütun filtreleri+durum+sıralama+sayfalamayı TEK sorguda sunucuda birleştirir (bkz. Ürünler Sayfası notu — id-listesi URL taşması ve statement-timeout derslerinin detayı orada). `products` + `product_groups` (grup/üst grup adı) + inline `weekly_sales`/`cok_satan` (`MATERIALIZED` CTE) döndürür; `Product.fromMap()`'in düz-sütun fallback'i (`group_name`/`parent_group_name`) bu RPC'nin `product_groups` embed'i OLMAYAN düz satır şekli için gerekli. **Parametre listesini değiştiren migration yazarken önce `DO $$ ... DROP FUNCTION ... $$` ile eski overload'ları temizle** (bkz. `0020`) — aksi halde `CREATE OR REPLACE` yeni bir overload yaratır, isim çakışması hatası verir.

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
- **⚠️ Ortam izolasyonu — agent yazma engeli (GÜNCEL, deploy bunu izler):** Bu oturumlarda paylaşılan
  checkout'a **doğrudan yazma engellidir** (parent oturum ve arka plan alt-agent'lar dahil; hata:
  "hasn't isolated its changes yet"). Bu yüzden her değişiklik + deploy **iki aşamalı** yürütülür:
  1. **Kod/doküman değişikliği:** `isolation: "worktree"` ile bir alt-agent yapar ve değişikliği kendi
     worktree dalına **commit** eder (build/push YAPMAZ). Dal: `worktree-agent-<id>`, yol:
     `.claude/worktrees/agent-<id>`.
  2. **Deploy (ayrı alt-agent, ana checkout'ta master):** `git checkout master` →
     `git merge worktree-agent-<id>` (fast-forward beklenir, çakışmada DUR) →
     `git worktree remove .claude/worktrees/agent-<id>` → `flutter analyze` →
     `flutter build web --release --base-href /nicepos/ --dart-define=SUPABASE_URL=... "--dart-define=SUPABASE_ANON_KEY=..."`
     → `Remove-Item -Recurse -Force docs; Copy-Item -Recurse build\web docs` →
     `git add -A; git commit -m '...'` (tek satır, çift tırnaksız) → `git fetch; git log origin/master..master`
     (fast-forward teyidi) → `git push origin master`.
  - Yalnızca **markdown/doküman** değişikliğinde (kod yok) web rebuild gerekmez: merge + `git push origin master`
    yeterlidir (docs değişmez).
  - Alternatif: `.claude/settings.json` → `"worktree": {"bgIsolation": "none"}` engeli kapatır; ancak
    build+push gerçek repo/remote'u değiştirdiğinden **worktree akışı tercih edilir**.

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
