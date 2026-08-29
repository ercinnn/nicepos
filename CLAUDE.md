# CLAUDE.md

Bu dosya, Claude Code'a bu depoda çalışırken rehberlik eder.

## Agent'lar

`.claude/agents/` altında özel agent'lar tanımlı:
- **`tasarim-lideri`** — tasarım yönü/token kararları verir, `design/design-tokens.md`'nin tek sahibi. Kod yazmadan önce görsel bir karar gerekiyorsa buradan geçer. Kod YAZMAZ: yön verir, token'ı yönetir, alt agent'ların çıktısını token'a karşı **denetler**.
- **Ekran tasarımcıları (alt-agent, `tasarim-lideri` devreder):** `satis-ekrani-tasarimci` · `satis-grafikleri-tasarimci` (dashboard/grafikler) · `stok-listesi-tasarimci` (ürünler) · `musteri-kayitlari-tasarimci`. Her biri yalnız kendi ekranının widget'larını düzenler; `design-tokens.md`'yi **okur, değiştirmez**.
- **`gorsel-elestirmen`** — responsive/token uygunluğunu Playwright ile piksel üstünde QA eder, kod yazmaz (alt-agent).
- **`icerik-duzenleme-uzmani`** — UI içeriği/metin + arkasındaki matematiksel mantık (toplam, iskonto, yüzde, fiyat formatı) değişiklikleri.
- **`yazilim-lideri`** — yazılım mimarisi/performans lideri. `tasarim-lideri`'nin mühendislik karşılığı: Flutter/Riverpod/Supabase mimarisine hakim, performans darboğazlarını ölçerek tespit eder, düşük riskli düzeltmeleri **bizzat uygulayıp commit'ler** (`tasarim-lideri`'nin aksine kod YAZAR), riskli/büyük işleri kendi oluşturduğu (worktree izolasyonlu) ad-hoc alt agent'lara devredip sonucu denetler — sabit bir alt-agent rosteri YOK. DB migration/push öncesi kullanıcıya sorar.

`design/design-tokens.md` tasarım sisteminin tek doğru kaynağıdır (palet, tipografi, spacing, §4 imza öğesi: Hero Tutar + Altın Ray, §5 bileşen notları + KARAR geçmişi, §6 v2.0 Enstrüman Konsolu dili). Ekran tasarımcıları bu dosyayı okur, değiştirmez.

**⚠️ Bu roster dosya olarak eksik olabilir:** `.claude/` gitignore'lu olduğundan agent tanımları git ile taşınmaz — yeni bir checkout'ta (ör. bu depo başka bir makineye/klasöre klonlandığında) yukarıdaki agent'lar CLAUDE.md'de belgeli olsa da `.claude/agents/` altında **fiziksel olarak bulunmayabilir**. Çalışmadan önce `ls .claude/agents/` ile doğrula; eksikse kullanıcıya sor (yeniden mi oluşturulsun, yoksa başka bir checkout'ta mı kalmış).

### Storefront (Cloudflare Pages) agent'ları — AYRI roster

`storefront/` (bkz. "Online Satış (storefront)" bölümü) ana uygulamadan bağımsız bir tasarım sistemine sahiptir (`storefront/design/design-tokens.md`) ve KENDİ agent üçlüsünü kullanır — yukarıdaki `tasarim-lideri`/`yazilim-lideri` rosteriyle KARIŞTIRILMAZ:
- **`magaza-tasarim-lideri`** — storefront'un tasarım lideri, `storefront/design/design-tokens.md`'nin tek sahibi. Kod yazmaz.
- **`magaza-tasarimci`** — storefront ekranlarını (anasayfa/ürün detay/sepet/checkout) düzenleyen tek ekran tasarımcısı (storefront küçük olduğundan ekran başına ayrı agent YOK). `design-tokens.md`'yi okur, değiştirmez.
- **`magaza-gorsel-elestirmen`** — canlı siteyi (`nicepos-online-satis.pages.dev`) tarayıcı araçlarıyla (claude-in-chrome, deferred — ToolSearch ile yüklenir) çoklu genişlikte QA eder, kod yazmaz.

Ana uygulamanın koyu "Enstrüman Konsolu" dili storefront'a **taşınmaz** — storefront müşteri karşısında sıcak/aydınlık bir perakende mağazasıdır, palet kökeni ortak (lacivert+altın) ama uygulama dili kasıtlı farklı (bkz. `storefront/design/design-tokens.md` başlığındaki not).

**⚠️ Sıralama kuralı (yaşanmış hata):** Bir KARAR token'a yazıldıysa, alt agent'a devretmeden **ÖNCE commit edilmelidir**. Worktree'ler temiz `HEAD`'den açılır → ana checkout'ta *uncommitted* duran token değişikliğini alt agent **göremez** ve kararı belgeden doğrulayamaz (v2.2 turunda yaşandı: agent §6.7'yi bulamadı, yalnız görev metnine dayanarak uyguladı).

## Supabase Kimlik Bilgileri

```
SUPABASE_URL=https://maogkrllltlxkfdwfsdj.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1hb2drcmxsbHRseGtmZHdmc2RqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODE1MDk3NjQsImV4cCI6MjA5NzA4NTc2NH0.BsPCU9Hx1OuMf-JI7TU4I6SRuSKsLcmL2MIpQc2gKp0
```

## Commands

```powershell
# Yerel geliştirme — web (bu makinede `-d chrome` başarısız oluyor, web-server kullan)
flutter run -d web-server --web-port=8765 `
  --dart-define=SUPABASE_URL=https://maogkrllltlxkfdwfsdj.supabase.co `
  "--dart-define=SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1hb2drcmxsbHRseGtmZHdmc2RqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODE1MDk3NjQsImV4cCI6MjA5NzA4NTc2NH0.BsPCU9Hx1OuMf-JI7TU4I6SRuSKsLcmL2MIpQc2gKp0"

# Yerel geliştirme — Android (USB/emülatör)
flutter run -d android `
  --dart-define=SUPABASE_URL=https://maogkrllltlxkfdwfsdj.supabase.co `
  "--dart-define=SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1hb2drcmxsbHRseGtmZHdmc2RqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODE1MDk3NjQsImV4cCI6MjA5NzA4NTc2NH0.BsPCU9Hx1OuMf-JI7TU4I6SRuSKsLcmL2MIpQc2gKp0"

flutter analyze              # Lint / statik analiz
flutter test                 # Tüm testleri çalıştır
dart run build_runner build --delete-conflicting-outputs  # Riverpod kod üretimi

# App icon + splash screen + web favicon yeniden üret (kaynak: kök dizindeki pos.png,
# bkz. Marka bölümü) — pos.png değişirse veya yeni platform eklenirse çalıştır
dart run flutter_launcher_icons
dart run flutter_native_splash:create

# GitHub Pages deploy — yeni bir paket eklendiyse (pubspec.yaml değiştiyse) ÖNCE
# `flutter clean` + `flutter pub get` çalıştır (bkz. Deploy bölümündeki MissingPluginException notu)
flutter build web --release --base-href /nicepos/ `
  --dart-define=SUPABASE_URL=https://maogkrllltlxkfdwfsdj.supabase.co `
  "--dart-define=SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1hb2drcmxsbHRseGtmZHdmc2RqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODE1MDk3NjQsImV4cCI6MjA5NzA4NTc2NH0.BsPCU9Hx1OuMf-JI7TU4I6SRuSKsLcmL2MIpQc2gKp0"
# Sonra: Remove-Item -Recurse -Force docs; Copy-Item -Recurse build\web docs; git add docs build; git commit
# Push kullanıcının kendisi tarafından yapılır (bkz. Deploy bölümü)

# Android release APK
flutter build apk --release `
  --dart-define=SUPABASE_URL=https://maogkrllltlxkfdwfsdj.supabase.co `
  "--dart-define=SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1hb2drcmxsbHRseGtmZHdmc2RqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODE1MDk3NjQsImV4cCI6MjA5NzA4NTc2NH0.BsPCU9Hx1OuMf-JI7TU4I6SRuSKsLcmL2MIpQc2gKp0"
# Çıktı: build\app\outputs\flutter-apk\app-release.apk
```

## Ortam Değişkenleri

`.env` kullanılmaz. Supabase değerleri dart-define ile build'e gömülür (yerel `flutter run` ve `flutter build` aynı iki değişkeni ister). `lib/core/supabase/supabase_config.dart` — `String.fromEnvironment()` ile okur, eksikse `ConfigMissingScreen` gösterir.

## Platformlar

| Platform | Durum | Notlar |
|---|---|---|
| Web (GitHub Pages) | ✅ | `docs/` klasörü, base-href `/nicepos/` |
| Android APK | ✅ | `android/` klasörü mevcut, INTERNET + CAMERA izinleri |

**Gradle heap:** `android/gradle.properties` → `-Xmx3G` (8GB RAM makine için düşürüldü, OOM crash önlenir).

## Marka (App Icon / Splash / Favicon)

Uygulama adı **NicePOS** (Android `android:label`, web `<title>` + `manifest.json` `name`/`short_name`). Kaynak görsel kökteki **`pos.png`** (NiCE tente logosu, 1080×1080). App icon (Android mipmap + web `icons/`), Android splash screen (light/dark + Android 12 `values-v31`) ve web favicon `flutter_launcher_icons` + `flutter_native_splash` paketleriyle **üretilir**, elle düzenlenmez — pubspec.yaml'daki `flutter_launcher_icons:`/`flutter_native_splash:` bloklarını değiştirip yukarıdaki Commands'taki iki komutu çalıştır. Arka plan rengi beyaz (`#ffffff`), web `theme_color` lacivert (`#1B2A4A`). ⚠️ Bu iki paket ilk çalıştırmada eksik Android SDK Platform'u (o an min_sdk_android ile uyumlu olan) indirebilir, birkaç dakika sürebilir.

## Mimari

### Katmanlar

```
lib/
  core/
    constants/     # AppColors, AppSizes
    theme/         # app_theme.dart + app_theme.g.dart (Riverpod provider)
    utils/         # formatters.dart, responsive.dart (isMobile <650px / isDesktop)
    supabase/      # SupabaseConfig, supabaseClientProvider, tenant_context.dart (Storage path kiracı çözümü)
    local_db/      # app_database.dart — sqflite (mobil çevrimdışı ürün senkronu, bkz. ilgili bölüm)
    widgets/       # InstrumentHero — paylaşılan "enstrüman konsolu" hero'su (design-tokens §6.3, v2.0)
  app/             # Router, AppScaffold (web: sidebar + canlı saat; mobil: Drawer + BottomNav)
  features/
    auth/          # Login, Signup (yeni işletme/davet kodu), ConfigMissingScreen — bkz. "Çok Kiracılı Mimari"
    home/          # Anasayfa — kısayol kart grid + Dashboard (stat kartları + grafikler)
    gorevler/      # Görevler — dünkü satışların raf-kontrol listesi, günde bir kez otomatik açılır
    products/      # Ürünler, Ürün Grupları, Liste Gir
    customers/     # Müşteri listesi, detay (geçmiş işlem yönetimi + toplu yazdırma), ödeme
    sales/         # Satış ekranı — 5 sekme, sepet, ödeme paneli, hızlı ürünler
    reports/       # Günlük / Tarihsel / Ürün raporları (3 sekme)
    labels/        # Etiket — raf etiketi A4 yazdırma
    kasa/          # Kasa — gelir-gider defteri + mutabakat + firma giderleri
    online_satis/  # Online Satış kontrol paneli — bkz. "Online Satış (Storefront)" bölümü
    audit/         # Denetim Kaydı — kalıcı işlemler için kim-ne-zaman-ne (bkz. "Çok Kiracılı Mimari")
```

### Tasarım Sistemi

Tek kaynak: `lib/core/theme/app_theme.dart` (`appThemeProvider`, `@Riverpod(keepAlive: true)`). Palet: beyaz zemin, lacivert (#1B2A4A) butonlar, altın (#D4B86A) kenarlıklar — sabitler `lib/core/constants/app_colors.dart`. Detaylı token/karar geçmişi: `design/design-tokens.md`.

**v2.0 — "Enstrüman Konsolu" tasarım dili (design-tokens §6):** Kimlik "uzay üssü / görev-kontrol" yönüne evrildi — **palet KORUNDU** (sıcak lacivert + altın + beyaz; yeni hex yok, mevcut lacivert rampası "panel" yüzeyi olarak terfi etti). Yaklaşım **hibrit**: çalışma ekranları (satış/stok/müşteri liste-tablo/form/rapor tabloları) **aydınlık** kalır; **metrik + hero + dashboard yüzeyleri koyu "enstrüman paneli"ne** döner (`primaryDark → primaryDeep` gradyan + soluk graticule + altın reticle köşeler + tick'li ray + mikro-etiket). İmza = Hero tutar + **altın ray (korundu)** + enstrüman detaylandırması. **Faz 1:** Dashboard (`dashboard_section.dart` — bespoke, ışıltı/asimetri korundu). **Faz 2:** Raporlar/Kasa (altın ray) + Müşteri liste/detay (**semantik ray** — borç=danger, alacak/sıfır=success; reticle yine altın) → hepsi tek paylaşılan **`InstrumentHero`** bileşeninden (`lib/core/widgets/instrument_hero.dart`, statik/animasyonsuz — ışıltı YALNIZ Dashboard'a ait). **Faz 3:** Satış ekranı ödeme paneli (`payment_panel.dart`, KARAR **v2.2** / design-tokens **§6.7**) — hero `InstrumentHero`'ya taşındı (iade modunda semantik `danger` ray), ödeme butonları **iki aksiyon sınıfına** ayrıldı, altın bu ekranda yalnız ray+reticle'a indirildi, sabit 320px panel yüksekliği kaldırıldı. Ayrıca §6.2'ye **`panel.control`** token'ı eklendi (koyu panel üstündeki etkileşimli öğe kenarlığı = beyaz @0.24–0.30, dolgu @0.04–0.08 — `panel.hairline` bir butonu taşıyamaz). Kurallar korunur: ekran başına tek hero, altın ekonomisi, altın ray yalnız hero'da. ⚠️ Koyu panele Row eklerken **yatay-taşma tuzağı** (CLAUDE.md Dashboard notu) tekrar ısırır — `InstrumentHero` bunu `FittedBox(scaleDown)+IntrinsicWidth+CustomPaint` ile çözer (bounded/unbounded güvenli; `LayoutBuilder`, `IntrinsicWidth` altında çökertir → tick'ler `CustomPaint`).

### State Yönetimi — Riverpod Generator

TÜM provider'lar `@riverpod` / `@Riverpod(keepAlive: true)` ile üretilir; her dosyada `part '...g.dart'` zorunlu. Dashboard provider'ları (`todaySummary`, `dailySales(days)`, `currentYearMonthly`, `historicalYearly` vb.) **autoDispose** — Android'de soğuk açılışta ilk sorgu boş dönerse `keepAlive` bunu kalıcı dondururdu (yaşanmış bug), bu yüzden hepsi autoDispose. `salesCartProvider`/`paymentInputProvider`/`productColumnsProvider`/`labelSheetProvider` gibi UI-durumu tutan provider'lar `keepAlive`.

## Satış Akışı

`SalesCart` (Riverpod notifier, `sales_cart_notifier.dart`) 5 müşteri sekmesini yönetir (`SalesState.activeTab` + `List<CustomerTabState>`).

- **Canlı ürün arama:** barkod okutup Enter → doğrudan sepete ekler. Yazı yazınca (250ms debounce) `OverlayPortal` ile canlı öneri listesi açılır (Türkçe-duyarlı substring arama).
- **Sepet (`cart_table.dart`):** satır bazlı %/₺ iskonto (`_CompactDiscountCell`) + sepet geneli iskonto. **Çoklu seçim + toplu %iskonto:** her satırın solunda yuvarlak seçim ikonu (`_RowSelectToggle`); seçim varken üstte "Seçilenlere % İndirim Uygula" barı belirir, yalnız YÜZDE tipinde iskonto uygular ve yalnız seçili satırları etkiler (mevcut tekil %/₺ iskontodan ayrı bir akış). Seçim `Set<int>` index bazlı, sekme değişince veya satır sayısı değişince otomatik temizlenir.
- **Birim fiyat:** elle düzenlenebilir + yanında "Fiyat1 yap" radyosu (`products.price1`'i kalıcı günceller).
- **Mobil:** kamera barkod okuma, sepet kart listesi (sola kaydır → sil), ödeme `DraggableScrollableSheet`.
- **Ödeme paneli (`payment_panel.dart`) — v2.2 enstrüman dili (design-tokens §6.7):** Hero TOPLAM ekranın tek imza öğesidir ve artık paylaşılan **`InstrumentHero`**'yu kullanır (koyu panel + reticle + tick'li ray; bespoke `_HeroTotal` KALDIRILDI). Ray semantiktir: normal **altın**, iade modunda **`danger`**; reticle her durumda altın.
  - **Ödeme butonları iki aksiyon sınıfına ayrılır** (bu kararın kalbi): `TEK DOKUNUŞTA TAMAMLAR` grubu (**Nakit · POS**) türün renginde **dolu** buton — tek dokunuşta satışı bitirir; `ÖNCE SEÇ, SONRA TAMAMLA` grubu (**Açık Hesap · Parçalı**) nötr `divider` kenarlıklı **outline** + sol renk şeridi — yalnız mod seçer. Önceden dördü de aynı görünüyordu ve yanlış dokunuş satışı yanlış türle kapatıyordu. **Onay dialog'u EKLENMEZ** — ekranın önceliği hızdır, güvenlik görsel ağırlıkla sağlanır.
  - **Altın ekonomisi:** bu ekranda altın YALNIZ hero rayı + reticle'dadır. Ödeme butonu kenarlığı, mobil ödeme barı kenarlığı ve "Hızlı Ürünler" ⚡ ikonu **altın DEĞİL** (v1.9.1'in `goldBorder` izni bu ekranda bilinçli geri alındı).
  - **Mobilde tek hero:** `_MobilePaymentBar` hero DEĞİL (altın ray yok, tutar ~24) — mobilin tek hero'su ödeme sheet'indeki `InstrumentHero`'dur.
  - **İade modu 2 sinyal:** hero (`İADE TUTARI` + danger rakam/ray) + `_ReturnModeButton`. Masaüstündeki panel içi banner ve kartın 2px kırmızı kenarlığı kaldırıldı; **mobil banner KALIR** (orada hero sheet içinde, ana ekranda görünmez).
  - **⚠️ Sabit yükseklik YOK:** `SizedBox(height: 320, child: PaymentPanel())` kaldırıldı (Parçalı açılınca taşıyordu). Panel içeriği kadar yer alır; sağ sütun genişliği akışkandır (~%42, 420–580 arası).
  - **⚠️ ÜÇ BÖLGE — ana aksiyon asla kaydırma alanında olmaz (KARAR v2.3 / §6.8(a), ölçülmüş hata):** 1366×768'de Parçalı seçiliyken "Satışı Tamamla" 145px aşağıda görünmüyordu. `PaymentPanel` artık kendi içinde üç bölge kurar: **üstte sabit** `InstrumentHero` · **ortada kayan** (ödeme butonları, Parçalı input'ları, özet, uyarılar; `Scrollbar` ile görünür ipucu) · **altta sabit ana aksiyon**. Kaydırma YALNIZ panel bounded'ken (masaüstü `ConstrainedBox`, mobil sheet `Expanded`) açılır — `LayoutBuilder.constraints.hasBoundedHeight` denetler; sınırsız bağlamda ne `Flexible` (unbounded flex çökmesi) ne de ikinci bir kaydırma açılır. **Panelin dışına `SingleChildScrollView` KOYMA** — tüm paneli kaydırır ve hatayı geri getirir. Mobil sheet kendi `SingleChildScrollView`'ını bıraktı, `DraggableScrollableSheet`'in controller'ını `PaymentPanel(scrollController:)` ile panele geçirir → sürükleme çalışır, ekranda tek kaydırılabilir kalır (`initialChildSize` 0.6 değişmedi). Regresyon: `test/payment_panel_render_test.dart`.
  - **İade hero rakamı (§6.8(c)):** `InstrumentHero.amountColor` (toplamsal, varsayılan beyaz → diğer hero'lar değişmez); satış ekranı iade modunda `instrumentPanelReadable(AppColors.danger)` geçer — ham `danger` koyu panelde ≈2.7:1 ile AA'yı karşılamıyordu.
  - Yanında (yalnız web, `kIsWeb`) 🇬🇧 ikonlu buton — hero panelinin **içinde** durur (`InstrumentHero.trailing`), çemberi `panel.control` beyaz-alfa (altın değil) — toplamı İngilizce sesli okur (`flutter_tts`, `tts_service.dart` + `english_number_words.dart`). Erkek ses platform bazlı best-effort (kesin garanti yok); `speak()` çağrısı öncesindeki her hazırlık adımı (`setPitch/setVoice/getVoices`) ayrı try/catch korumalı — biri hata verse bile `speak()`'e her zaman ulaşılır.
- **Ödeme tamamlama:** `SalesRepository.completeSale()` → RPC → sales + sale_items insert → stok düşür → borç hareketi.

### Satış Düzenleme & Silme (`SaleEditScreen`)

Rapor ekranlarından ve müşteri detayından açılır; kalem/iskonto/ödeme türünü düzenler. İskonto TL/%-birebir saklanır (yuvarlama farkı olmaz). Ödeme türü değişince (`updateSale`) önce otomatik borç hareketi silinir, sonra kalan borca göre yeniden eklenir — hayalet borç kalmaz. Web'de **Yazdır** (`sale_print.dart` conditional export) A4 sepet detayını yeni pencerede açıp otomatik yazdırır. **Satışı Sil** stok iadesi + bağlı borç hareketi + kayıtları siler.

### Mobil Çevrimdışı Satış (Nakit/POS)

Ürün offline senkronuyla aynı mimari (bkz. Ürünler Sayfası bölümü), yalnız native. Kapsam **v1'de yalnız Nakit/POS** — Açık Hesap/Parçalı müşteri arama (`customer_picker_dialog.dart`, tamamen ağ-bağlı, offline cache'i YOK) + borç defteri (`customer_payments`) gerektirir, offline'da pasif kalır (bilgilendirme mesajı gösterir); **İade de v1'de kapsam dışı**.

- **Kuyruk:** `pending_sales` (sqflite, `id` PK — istemcide üretilen uuid), APPEND-ONLY (`pending_changes`'in aksine bir satış offline'da tekrar düzenlenmez). `PendingSale`/`PendingSaleDao` (`lib/features/sales/data/`), `pending_changes` ailesiyle birebir aynı desen.
- **Tamamlama (`payment_panel.dart` `_completeSaleDirectly`):** offline'da (veya ağ timeout'unda) `_queueOfflineSale` çağrılır — id üretilir, sepet donmuş payload olarak kuyruğa yazılır, sepetteki her kalem için `ProductLocalCacheDao.decrementStockLocally` + `BarcodeCache.put` ANINDA uygulanır (aynı offline oturumda ardışık taramalar doğru stok görsün diye). Görüntüleme için yerel `ÇEVRİMDIŞI-XXXXXX` kodu üretilir — gerçek `sale_code` server-only bir sequence kullandığından (`generate_sale_code` RPC) offline üretilemez, SENKRON anında atanır.
- **⚠️ Senkron TEK atomik RPC ile:** `SaleSyncService` (`sale_sync_service.dart`) her bekleyen satışı `SalesRepository.completeSaleOffline()` → `complete_sale_offline` RPC'siyle (bkz. `0027_complete_sale_offline.sql`, **Supabase SQL Editor'da elle uygulanmış olmalı**) gönderir — `sales`+`sale_items` insert + stok düşürme AYRI istemci adımlarına BÖLÜNMEZ, tek PL/pgSQL fonksiyon gövdesi (tek transaction) olarak sunucuda çalışır. Bağlantı senkron ORTASINDA tekrar koparsa kısmi yazım riski yoktur; RPC `id` bazlı idempotent (satır zaten varsa no-op döner) → retry her zaman güvenli. `sale_date` senkron ANI DEĞİL, `PendingSale.createdAt` (offline tamamlama anı) — aksi halde raporlar satışı yanlış güne yazar.
- **Sepete ürün ekleme offline fallback'i:** `BarcodeCache._load()` (sales_screen açılışında bir kez prefetch), `sales_screen.dart` barkod Enter + canlı öneri overlay'i, `product_search_dialog.dart`, Hızlı Ürünler paneli (`productsByGroup` provider) — hepsi ağ başarısız olursa `ProductLocalCacheDao.searchCached()`'e düşer (native only).
- **Bekleyen sheet'i birleşik:** `PendingChangesSheet` artık hem bekleyen ürün değişikliklerini hem bekleyen satışları TEK listede gösterir (bkz. yukarıdaki Ürünler bölümü).
- **⚠️ Kapsam dışı (v1, bilinçli):** Açık Hesap/Parçalı/İade offline çalışmaz; `SaleEditScreen` bekleyen bir satışı offline düzenleyemez (zaten sync'ten önce sunucuda görünmez); Dashboard/Raporlar bekleyen offline satışları senkron olana kadar yansıtmaz; müşteri etiketleme (customerId) Nakit/POS'ta bile bağlantı gerektirir (müşteri arama offline yok). "Bekleyenler" sheet'inde bir satışı **At** dersen düşürülen yerel stok geri eklenir.

## Dashboard (Anasayfa)

`dashboard_section.dart`:
- **Hero bandı (v2.0 enstrüman göstergesi):** bugünkü ciro — koyu lacivert gradyan + altın ray + ışıltı animasyonu (TEK `AnimationController`, faz türetmeli — yeni bir nabız efekti eklenirse AYRI controller AÇMA), üzerine **4 köşe altın reticle nişangâh + tick'li ray + mikro-etiket** (design-tokens §6.3). Işıltı yalnız Anasayfa'da; diğer ekranların hero'ları (`InstrumentHero`) statik/düz kalır.
- **Stat kartları (`_StatCardsRow`) — v2.0 koyu konsol:** Satış Adedi / Aylık Ciro / Aylık Adet / Yıllık Ciro / Son 365 Günlük Ciro. Her kart artık **koyu enstrüman paneli** (`_panelDecoration()` — `primaryDark→primaryDeep` gradyan + soluk graticule; ESKİ `cardDecoration()` altın-kenarlık dili KALDIRILDI, design-tokens §6.4 v1.17'yi bilinçli alt üst etti): sol ince kategorik renk şeridi (koyu zeminde görünmeyen `primary`/`danger` durakları `_panelUzerinde` ile parlatılır) + ikon + mini sparkline (`fl_chart`, eksensiz/dolgusuz). **Reticle/tick/altın ray YOK** — onlar yalnız gerçek hero'da. Grafik kartları da (`fl_chart`) koyu panele taşındı; grid/eksen/etiket koyu zeminde okunur ayarlı.
- **Günlük satış grafiği + Yıllık Ciro Karşılaştırma + Yıllık Ortalama Ciro:** `fl_chart` çizgi grafikler, hiçbiri hero değil.
- **⚠️ Bilinen Flutter tuzakları (regresyon testiyle yakalandı, `flutter analyze` GÖRMEZ):**
  - `Positioned` DAİMA `Stack`'in DOĞRUDAN çocuğu olmalı — `IgnorePointer`/`AnimatedBuilder` gibi bir ara widget'ın içine gömülürse "Incorrect use of ParentDataWidget" ile TÜM dashboard çöker.
  - Kaydırılabilir sayfada `IntrinsicHeight` olmadan stretch'li/Expanded'lı bir `Row` "infinite height" hatasıyla dashboard'u çökertir.
  - `test/dashboard_render_test.dart` bu ikisini regresyon olarak test eder.
- **Yıllık Ciro / Son 365 Gün kartları** sunucu tarafı tek `SUM()` RPC'si (`sales_revenue_between`) kullanır — istemci tarafı sayfalı toplama değil.

## Görevler

`/gorevler` — dün satılan ürünlerin raf-kontrol listesi ("dünkü satışları kontrol edip rafları tamamla"). Kalıcı bir menü öğesi, AYRICA **uygulama o gün ilk açıldığında otomatik gösterilir**: `AppScaffold` her build'de bir `SharedPreferences` anahtarını (`gorevler_son_acilis_tarihi`) bugünün tarihiyle (`gorevlerTarihAnahtari()`) karşılaştırır, farklıysa `/gorevler`'e yönlendirip anahtarı günceller — bir oturumda yalnız bir kez tetiklenir, aynı gün tekrar route değişse de yeniden yönlendirmez. Tüm platformlarda (web dahil) geçerli.

- **Liste kaynağı:** `GorevlerRepository.fetchYesterdaySoldProducts()` — dünün (takvim günü) `sale_items`'ını sayfalı çekip (`ReportRepository.fetchBestSellers` ile birebir aynı desen) ürün bazında Dart tarafında toplar, adede göre azalan sıralar. Silinmiş ürün (join'de `products` null gelirse) atlanır.
- **Tamamlanma sunucuda paylaşılır:** `gorev_tamamlamalar` tablosu (`0035_gorev_tamamlamalar.sql`, **Supabase SQL Editor'da elle uygulanmış olmalı**) — `(product_id, gorev_tarihi)` unique, `upsert`/`delete` ile işaretlenir/geri alınır. Aynı (paylaşılan) kullanıcı başka bir cihazdan girdiğinde aynı tamamlanma durumunu görür — önceki yerel/SharedPreferences tabanlı sürümün yerini alır.
- **Provider (`gorevlerControllerProvider`) autoDispose** — Dashboard provider'larıyla aynı KARAR: sayfaya her dönüşte taze sorgu, kalıcı-yanlış-veri riski yok.
- **UI:** Yapılacaklar/Tamamlananlar iki sekmesi AYNI provider'ı paylaşır, yalnız `GorevItem.tamamlandi` süzgeci ters çevrilir. Bir satırı tikleyince kısa bir sönme animasyonundan (`AnimatedOpacity`, 260ms) sonra gerçek sunucu güncellemesi (`tamamla`/`geriAl`) tetiklenir. Hero, Dashboard/Raporlar ile BİREBİR aynı `todaySummaryProvider` rakamını gösterir (nakit-esaslı günlük ciro).
- **⚠️ Mobil alt nav yatay-kaydırmalı:** `Görevler` eklenince alt navigasyon 9 öğeye çıktı ve sabit-genişlikli Material 3 `NavigationBar`'a sığmadı (etiketler sıkışıp okunaksızlaşıyordu) — `_MobileBottomNav` bu yüzden yatay kaydırılabilir sabit-genişlikli (`76px`) bir şeride çevrildi (`ListView.builder` + seçili öğeyi görünür alana otomatik kaydıran `ScrollController`). Yeni bir menü öğesi eklenirse bu davranış korunur, `NavigationBar`'a dönülmez.

## Müşteri Detayı

`customer_detail_screen.dart` — Alışverişler ve Ödeme/Borç Hareketleri listelerinde tekil + toplu silme. **Toplu yazdırma:** her satışın solunda seçim kutucuğu; seçiliyken (yalnız web) "Seçilenleri Yazdır" butonu, seçilen tüm satışları TEK bir A4 dokümanında (her satış kendi bölümü + genel toplam) yazdırır (`sale_print_web.dart` → `printMultipleSalesA4`).

## Ürünler Sayfası

**Desktop:** `DataTable`, kolon seçici, satır içi tıkla-düzenle (yalnız dokunulan satır `TextField`'a döner — `DataTable` sanallaştırma yapmaz, performans için önemli), `TapRegion` ile otomatik kaydet-kapat. Durum sütunu (Çok Satan/Tükendi/Pasif) sunucuda `product_status` view'ından hesaplanır. Sütun filtreleri + server-side sıralama.
**Mobil:** kart listesi, kamera ile barkod okuma.

**Liste Gir** (4. sekme, yalnız desktop): tedarikçi PDF/JPEG listesi → sütun işaretleme (pdf.js + Tesseract.js OCR yedek) → önizleme/düzenleme ızgarası → kaydet. Alış/satış fiyatı çarpanları (iskonto/KDV farkını telafi eder). **Tekil gönder:** her satırın sağında, toplu "Kaydet"ten bağımsız, o satırı tek başına sisteme yükleyen bir gönder ikonu (barkod tazeliği aynen korunur — göndermeden hemen önce tekrar sorgulanır). Barkod eşleşirse stok additive + fiyat replace, eşleşmezse yeni ürün. Test: `test/liste_gir_extractor_test.dart`.

**Eşlenik Barkod:** aynı fiziksel ürünün farklı barkodlu satırlarını gruplar (`products.equivalent_group_id`); ham veriler değişmez, stok/fiyat toplamı yalnız okuma anında `product_equivalent_aggregate` view'ıyla hesaplanır. Esas fiyat = grubun en son güncellenen satırından. **⚠️ KRİTİK:** `Product.equivalentGroupId` `toInsertMap()`'e KESİNLİKLE dahil edilmez — aksi halde her `update()` grup bağlantısını sessizce kırar; grup yalnız `linkEquivalentBarcode`/`unlinkEquivalentBarcode` ile değişir.

### Mobil Çevrimdışı Ürün Ekleme/Düzenleme

Dükkânın bazı bölgelerinde internet çekmiyor (Wi-Fi/cell "bağlı" görünüp gerçek erişim olmayabilir — sahte-bağlı dead-zone) — mobilde ürün ekleme/düzenleme bu yüzden offline-first çalışır. Yalnız native/Android (`!kIsWeb` guard — **`context.isMobile` DEĞİL**, bir Android tablet yatayda "masaüstü" `_TopBar`'ı render edebilir).

- **Yerel depo:** `sqflite` (`lib/core/local_db/app_database.dart`) — `products_cache` (ürün kataloğu aynası + `sync_state`), `pending_changes` (bekleyen ekleme/güncelleme kuyruğu, `product_id` PK), `product_groups_cache`/`companies_cache` (dropdown/autocomplete offline boş kalmasın diye).
- **Kayıt akışı (`product_form_screen.dart` `_save()`):** önce her zamanki gibi Supabase'e yazmayı dener (6sn timeout, `core/utils/network_timeout.dart`). Sunucu gerçek bir hata döndürürse (`PostgrestException`, ör. barkod çakışması) sert hata — formda kal, kuyruğa ALINMAZ. Hiç yanıt gelmezse (timeout/soket) yerel kuyruğa düşer: yeni ürünse id `Uuid().v4()` ile istemcide üretilir (`products.id uuid default gen_random_uuid()` olduğundan açık id insert migration gerektirmez) — sync bunu `ProductRepository.createWithId()` ile gönderir.
- **Bilinen-offline kısayolu:** `_knownOffline` (son senkron probu offline dediyse) 6sn'lik timeout'u tekrar tekrar BEKLEMEZ, doğrudan kuyruğa/cache'e düşer — bir dead-zone oturumunda bekleme yalnız İLK kayıtta/yüklemede ödenir. `_loadProduct`/`_fetchByBarcode` aynı desenle önce ağ, sonra (`!kIsWeb`) yerel cache'e düşer; ağdan başarıyla gelen her ürün fırsatçı olarak cache'e yazılır.
- **Bağlantı tespiti (paylaşılan):** `lib/core/connectivity/connectivity_status_service.dart` (`ConnectivityStatusService`, `@Riverpod(keepAlive:true)`) — reachability probe (2sn timeout, yalnız "bir bayt döndü mü" kanıtı) + 25sn periyodik timer + `connectivity_plus` dinleyicisi TEK yerde. `connectivity_plus` TEK BAŞINA yetersiz (sahte-bağlı dead-zone sorunu), bu yüzden her tetikleyici gerçek bir Supabase round-trip ile doğrulanır. `ProductSyncService`/`SaleSyncService` (satış tarafı, aşağıda) kendi probe'larını AÇMAZ — `registerDependent` ile kaydolur, bu servis online'ı doğrulayınca KAYITLI TÜM bağımlıları (ürün+satış) BİRLİKTE tetikler (`probeAndNotify()` — periyodik timer, connectivity-changed VE elle "Şimdi Senkronize Et" hepsi buradan geçer). Son bilinen faz `SharedPreferences`'a yazılır — soğuk açılışta bilinen bir dead-zone'da ilk ekran probu beklemeden offline varsayar.
- **Senkron motoru (ürün):** `product_sync_service.dart` (`ProductSyncService`) — bekleyen kayıtları 4'lü gruplar halinde paralel işler (sıralı değil). Push sırasında `PostgrestException` → o satır `failed` işaretlenir, kuyruğun geri kalanı devam eder; bağlantı gerçekten koparsa döngü hemen durur (kalan satırlara dokunulmaz).
- **Resim yükleme:** offline'da hiç ağ çağrısı yapılmaz — baytlar doğrudan cihaza dosya olarak yazılır (`getApplicationSupportDirectory()`), sync sırasında yüklenir. Çekirdek kayıt sunucuya gitmiş ama SADECE görsel adımı ağ hatasıyla başarısız olursa satır `operation:'update'`ye çevrilip yalnız görsel için tekrar denenir (idempotency — aksi halde tekrar deneme aynı id ile `createWithId` çağırıp PK ihlaline çarpar).
- **UI:** `AppScaffold`'da (hem masaüstü-genişlik `_TopBar` hem mobil `AppBar`) `SyncStatusBadge` — bekleyen sayaç + "Şimdi Senkronize Et" + `PendingChangesSheet` (yeniden dene/at; "at" bir `create` içinse ürün tamamen silinir, `update` içinse yalnız yerel değişiklik atılır).
- **Sessiz senkron bildirimi:** arka planda (kullanıcı hiç dokunmadan — periyodik prob veya connectivity geri gelince) tamamlanan bir senkron döngüsü `AppScaffold`'da "X ürün kaydı senkronize edildi" toast'ı ile bildirilir (`SyncStatus.lastSyncedCount`, her döngü sonunda AÇIKÇA yazılır). `PendingChangesSheet` de boşken "Son senkron: ..." gösterir — toast kaybolduktan sonra sayfayı tekrar açan kullanıcı da listenin BOŞ olmasının "kayıp" değil "zaten senkronize oldu" anlamına geldiğini görsün diye.
- **Ürünler LİSTE ekranı (`products_list_screen.dart`):** offline'da (`_knownOffline` veya ağ timeout'u) `ProductLocalCacheDao.searchCached()` ile yerel önbellekten isim/barkod/stok kodu arama + grup filtresiyle listelenir (çevrimdışı bant gösterilir). Sunucu gerektiren özellikler (Durum filtresi, sunucu-taraflı sıralama, Excel içe/dışa aktar, Ürün Özet, toplu seçim/silme, satır silme, tablo içi hücre düzenleme) offline'da pasif/gizli — yalnız satıra dokunup `ProductFormScreen`'e gitmek (zaten offline'a hazır) ve "+ Yeni Ürün" aktif kalır.
- **⚠️ Kapsam dışı (bilinçli):** ürün SİLME offline çalışmaz (ne formdan ne listeden); Eşlenik Barkod bağlama offline çalışmaz (canlı arama + anlık yazma gerektirir — `EquivalentBarcodeSection.pendingSync` bayrağıyla kapatılır); Ürünler listesinde tablo içi hücre düzenleme/sıralama/Excel/Ürün Özet offline çalışmaz (yalnız arama+görüntüleme+forma geçiş).
- **⚠️ Son-yazan-kazanır:** offline düzenleme `toInsertMap()`'in TÜM alanlarını gönderir, alan-bazlı birleştirme YOK — aynı ürün offline'dayken başka bir cihazdan değiştirilmişse o değişiklik sessizce ezilebilir (tek dükkan/tek aktif kullanıcı için kabul edilen basitleştirme).
- **⚠️ Barkod çakışması:** `products.barcode` UNIQUE — iki offline kayıt (veya offline+sunucu) aynı barkodu paylaşırsa sync `23505` ile başarısız olur, "Bekleyenler"den elle çözülür (silinmez, kullanıcı müdahalesi bekler).
- Yeni bağımlılıklar: `sqflite`, `connectivity_plus` (`AndroidManifest.xml`'e `ACCESS_NETWORK_STATE` eklendi), `shared_preferences` (son bağlantı durumu kalıcılığı) — üçü de web derlemesini bozmaz, yalnız runtime'da `!kIsWeb` ile atlanır.

## Raporlar

`/reports` — Günlük / Tarihsel / Ürün raporları. İskonto sütunu `% 82.25` formatında (2 ondalık).

**"TOPLAM CİRO" hero (Günlük + Tarihsel) = nakit-esaslı**, ana sayfa "günlük ciro" ile BİREBİR: `Nakit + POS + Alınan Ödemeler (borç tahsilatı)`; **açık hesap/borç HARİÇ** ("o gün kasaya giren para"). Kaynak: `DailyReportSummary.cashBasisTurnover` (`= cashTotal + posTotal + receivedPaymentsTotal`). `grandTotal` (borç DAHİL) modelde durur ama hero'yu beslemez — yalnız tablo/diğer kullanımlar için. Hero widget'ı `ReportHero` artık paylaşılan `InstrumentHero`'yu sarar (altın ray). Dashboard'ın nakit-esaslı ciro tanımı da aynıdır (`sales_revenue_between` RPC: `paid_amount` + `type='odeme'` tahsilatları).

## Etiket — A4 Etiket Yazdırma

`/etiket` — 9 sekme (`enum _LabelTab`): **Havuz** (mobil ürün formundaki "Etiket" butonundan beslenen, cihazlar/kullanıcılar arası paylaşılan DB'de kalıcı bekleyen kuyruk — Raf/Tel/Geniş/Ürün tipleri, `label_pool_items` tablosu), **Raf Etiketi** (eski "Yeni Etiket", 24 hane, 3×8 ızgara, logo+fiyat+Code128+barkod no+tarih), **Tel Etiketi** (Raf ile birebir aynı hücre, 32 hane, 4×8 ızgara, Raf'ın logosunu paylaşır), **Tel İndirim** (Tel Etiketi ile AYNI 32 hane/4×8 ızgara/boyut, yalnız her hücrede çizili eski fiyat + kırmızı büyük yeni fiyat — bkz. aşağıdaki ayrı not), **Geniş Logo** (10 hane, 2×5 ızgara, 88mm×55mm hücre — logo Faz D'den itibaren kiracı-bazlı, bkz. aşağıdaki not), **Poster** (barkod/ad ile serbest liste, A4 dikey profesyonel ürün listesi, çok sayfalı), **Ürün Etiketi** (adet-tabanlı, fiyatsız/logosuz, 72 hane, 6×12 ızgara), **İndirim** (4 hane, 2×2 ızgara, kullanıcının referans mockup'ına göre KARAR — çok sayfalı destek YOK: logo + logo-altı tagline artık kiracı-bazlı, bkz. aşağıdaki not — + ürün adı BÜYÜK HARF + tek satır kırmızı "%X İNDİRİM" bandı + "ESKİ FİYAT:" siyah/üzeri KIRMIZI çizili + kutulu kırmızı "YENİ FİYAT" hero + Code128 (bölge/konum sabit, asıl grafik bölgenin yalnız ORTA 1/3'ü — üst/alt eşit boşlukla merkezde) + tarih **YYAAGG** (örn. 260819, `formatShortDate` DEĞİL — bu sekmeye özel kompakt format) + barkod no. **Ana İndirim %**: haneler listesinin üstünde ayrı bir "genel" yüzde alanı (`LabelDiscountSheetState.defaultPercent`) — hane kendi yüzdesini GİRMEMİŞSE (`DiscountLabelSlot.discountPercent == null`) bu değer geçerli olur, genel değer sonradan değişse bile o haneyi güncel tutar; hane kendi yüzdesini girmişse genel değerden bağımsız SABİT kalır (`DiscountLabelSlot.effectivePercent`/`newPrice` bu ikisini çözer). Kamera ile barkod tarama diğer sekmelerle aynı (`onCameraScan`, yalnız native), **Kayıtlı Dosyalar** (Supabase Storage `etiket_pdfleri` bucket'ı, imzalı URL — sekmeden bağımsız TÜM kayıtlı PDF'leri listeler). Barkod → ürün çözme (`_resolveBarcode`) tüm sekmeler arasında paylaşılır, satış ekranıyla aynı desen. Yazdır yalnız web (`kIsWeb` guard); PDF Kaydet her platformda (gerçek `pdf`-widgets PDF, Supabase Storage'a yüklenir). Etiket çıktısı kendi hero'suna (FİYAT, altın ray YOK) sahiptir — app krom'undan ayrı bir görsel dil.

**Geniş Logo / İndirim — kiracı-bazlı marka (Faz D, bkz. "Çok Kiracılı Mimari").** Eskiden `genis_logo_figur.png`/`nice_logo_indirim.png` paket asset'lerine + hardcoded "EV GEREÇLERİ & HIRDAVAT" metnine gömülüydü, tüm kiracılar aynı NicePOS markasını görüyordu. Artık Raf/Poster/Ürün Etiketi'nin zaten kullandığı **paylaşılan** `LabelSheetState.logoDataUrl` mekanizmasını kullanırlar (`showLogoActions: true`) — bir kiracı herhangi bir sekmede logo yüklerse hepsinde görünür; yüklemezse alan BOŞ kalır (**yeni kiracılar için nötr varsayılan**, eski NicePOS markası hiçbir yeni kiracıya sızmaz). Tagline (İndirim'in logo-altı metni) `LabelsStorageRepository.uploadTagline/fetchTagline` ile ayrı bir Storage text-key'de (`__store_tagline.txt`, `logoKey` ile birebir desen) kiracı-bazlı; boşsa satır basılmaz. Geniş Logo hücresi bu yüzden **dikey `Expanded(flex:)` akışına** yeniden tasarlandı (logo → fiyat → ad → barkod → alt satır, düz zemin + `BoxFit.contain` — eski Positioned/tam-hücre-arka-plan yaklaşımı belirli bir illüstrasyona göre sabit oranlıydı, rastgele bir logoyla çalışmazdı); İndirim zaten Column-tabanlıydı, yalnız parametre değişti.

**Tel İndirim** (`TelDiscountLabelSlot`/`TelDiscountKind`, `lib/features/labels/data/models/tel_discount_label_slot.dart` + `labels_provider.dart` `LabelTelDiscountSheetState`) — Tel Etiketi'nin 32 hane/4×8 ızgarasını AYNEN kullanır (yeni ızgara sabiti YOK), mevcut "İndirim" sekmesinden AYRI (isim çakışmasın diye). İndirim % veya ₺ olabilir, hem sayfa geneli ("Genel İndirim" alanı, üstte %/₺ seçici + değer) hem hane-özel: her barkodun yanında bir "Genel" tiki — **tik HER ZAMAN görünür** (⚠️ yaşanmış hata: önceden yalnız tik kaldırılınca hane-özel %/₺ kontrolü görünüyordu, kullanıcı fark edemiyordu — artık her zaman görünür, tikliyken `Opacity`+`IgnorePointer` ile soluk/pasif). Tikli → genel değerden etkilenir; tiksiz → o hanenin kendi %/₺'si (`TelDiscountLabelSlot.effectiveKind/effectiveValue/newPrice`) geçerli olur, genel değer değişse bile SABİT kalır. Hücre tasarımı: logo + çizili eski fiyat (üst) → kırmızı büyük yeni fiyat → ürün adı (TEK satır, Tel'in 2 satırından fark) → Code128 → barkod no + tarih (Tel'le AYNI `formatShortDate`, İndirim'in YYAAGG'si DEĞİL). Rozet ("%X İNDİRİM" bandı) bilinçli olarak YOK — hücre zaten çok küçük (32/sayfa). **⚠️ Hücre-içi flex ORAN dersi (yaşanmış hata):** Tel hücresi (~136×189px) her ikisi (eski+yeni fiyat) + ad + barkod + tarihi aynı anda büyütmeye yetecek kadar geniş DEĞİL — kullanıcının art arda gelen "logo/eski fiyatı 2× yap", "barkodu yarıya indir, açılanı yeni fiyata ekle" gibi taleplerinde SABİT piksel yerine `Expanded(flex:)` oranı kullanılır (şu an 40:73:19:40 — üst:yeniFiyat:ad:barkod), üçü de (Flutter hücresi/`label_pdf.dart` PDF hücresi/`etiket_print_web.dart` CSS) BİREBİR aynı oranı paylaşır — hücreye göre ölçeklenir, ASLA taşmaz. **⚠️ PDF barkod `height > 0` assertion'ı (yaşanmış hata):** `pdf` paketinde (`pw.*`) bir `SizedBox(height:)` + `Row` + `Expanded` zinciri barkod widget'ına GERÇEK (sıfır olmayan) yükseklik vermeyebiliyor — `pw.Row`/`pw.Expanded` çapraz-eksen yayılımı yalnız `crossAxisAlignment: stretch` ile garanti; Raf/Tel'in kanıtlanmış deseni barkodu doğrudan `pw.Expanded`'ın Column ANA eksenindeki (dikey) flex payına koymaktı — `_telDiscountCell` bu yüzden barkod satırını SABİT `SizedBox(height:)` yerine bu desene döndü. PDF çıktısı `flutter run`/tarayıcı önizlemesinden bağımsız AYRI kod yolu olduğundan bu tür hatalar yalnız gerçek "PDF Kaydet" denemesiyle ortaya çıkar — flutter analyze/test YAKALAMAZ.

## Kasa

Gelir-gider defteri: Gelir (Nakit/POS banka kırılımı + mutabakat) · Gider (kategori + firma) · Firma Giderleri (yıl bazlı rapor) sekmeleri. Hero = birikimli yıl kasası (v2.0 `InstrumentHero`, altın ray; sağda ray'sız gider okuması — `instrumentPanelReadable` ile koyu panelde okunur).

## Veritabanı (Supabase)

Migration'lar `supabase/migrations/` — DDL anon key ile çalıştırılamaz, Supabase SQL Editor'da elle uygulanır.
- `sales`: iskonto birebir saklanır (`discount_percent` + `discount_amount` + `discount_type`).
- `customer_balances` view'ı borcu `customer_payments`'tan hesaplar.
- `sales_revenue_between(start_ts,end_ts)` RPC — dashboard ciro kartları için tek `SUM()`.
- `product_status` view — Çok Satan/Tükendi/Pasif; Eşlenik Barkod gruplarında grup-bazlı davranır.
- `search_products(...)` RPC — Ürünler sayfası Durum filtresi aktifken arama+filtre+sıralama+sayfalamayı tek sorguda birleştirir.
- **⚠️ RPC migration dersi:** Bir RPC'nin parametre listesini değiştiren migration'da ÖNCE `DO $$ ... DROP FUNCTION ... $$` ile eski overload'ları temizle — aksi halde `CREATE OR REPLACE` parametre tipi farklıysa yeni bir overload yaratır, "function name is not unique" hatası çıkar.
- **⚠️ Sorgu planlayıcı dersi:** Bir view'ı büyük bir tabloya JOIN edip window/agregasyon fonksiyonu kullanıyorsan CTE'yi `MATERIALIZED` işaretle — aksi halde planlayıcı satır başına yeniden hesaplayıp statement timeout (57014) verebilir.
- Eşlenik Barkod: `products.equivalent_group_id` + `product_equivalent_aggregate` view (detay: Ürünler Sayfası notu).
- `gorev_tamamlamalar` (`0035_gorev_tamamlamalar.sql`) — Görevler raf-kontrol tamamlanma kayıtları, `(product_id, gorev_tarihi)` unique (detay: Görevler bölümü).
- `audit_log` (`0044_audit_log.sql`) — kalıcı işlemler için kim-ne-zaman-ne kaydı, immutable (update/delete politikası yok), SELECT yalnız owner/admin (detay: "Çok Kiracılı Mimari" Faz B notu).
- **Online Satış** (`0028_online_satis.sql`, `0029_online_categories_public_read.sql`): `online_products` view (public-safe sütunlar, `is_online_active=true` filtresi, `anon` okur) + `online_orders`/`online_order_items` tabloları + `create_online_order()` RPC (SECURITY DEFINER, atomik — `complete_sale_offline` ile aynı desen, fiyat/stok/aktiflik sunucuda doğrulanır). `product_groups`'a `anon` için ek public-read policy (kategori navigasyonu). Detay: aşağıdaki "Online Satış (Storefront)" bölümü.

## Çok Kiracılı Mimari (Multi-Tenant SaaS)

NicePOS artık tek şirket için değil, birden çok şirkete SaaS olarak satılabilecek şekilde dönüştürülüyor (kullanıcının kendi mağazası "1. kiracı" olarak sorunsuz devam ediyor — ayrı bir veri taşıma/export-import olmadı). Yol haritası: `~/.claude/plans/bu-uygulamay-kendi-firmamda-synthetic-koala.md` (Faz A–G). Migration'lar `0036`–`0043` (`supabase/migrations/`).

**Faz A — Şema + RLS temeli (tamamlandı, canlıda doğrulandı):**
- `tenants` (id/name/slug/plan/is_active) + `memberships` (user_id/tenant_id/role: owner|admin|staff) tabloları.
- `current_tenant_id()` — SECURITY DEFINER SQL fonksiyonu, `memberships`'ten çağıranın kiracısını çözer; TEK çözümleme noktası, her yerde kullanılır.
- **Her iş tablosuna `tenant_id uuid not null default current_tenant_id()` eklendi** — bu DEFAULT sayesinde Dart tarafında `toInsertMap()`'lerin HİÇBİRİNE dokunulmadı; istemci INSERT'lerinde `tenant_id` hiç belirtilmez, DB otomatik doldurur. İzolasyon uygulama kodunda değil DB'de garanti altında.
- Tüm "authenticated = tam erişim" RLS politikaları `tenant_id = current_tenant_id()` ile değiştirildi (0039). `product_groups`'taki storefront'a açık "public read" politikası yalnız `anon` rolüne daraltıldı — aksi halde `authenticated` kullanıcılar da (Postgres permissive politikaları OR'ladığından) tüm kiracıların kategori adlarını görmeye devam ederdi.
- `security definer` RPC'ler (`complete_sale`, `complete_sale_offline`, `delete_sale`, `create_online_order`, `decrement/increment_product_stock`) tek tek kiracı kontrolüyle güncellendi (0040) — RLS'i by-pass ettiklerinden otomatik korunmazlar. `create_online_order` (anon çağırır, `current_tenant_id()` NULL döner) kiracıyı sepetteki ürünün kendi `tenant_id`'sinden çözer.
- Global unique kısıtlar (`products.barcode`, `sales.sale_code`, `customers.name`, `online_orders.order_code`, `kasa_expense_categories.name`, `kasa_opening_balances` PK, `kasa_reconciliations`) `(tenant_id, ...)` bileşik hale getirildi (0038).

**Faz B — Kendi-kendine kayıt + personel davet (tamamlandı, canlıda doğrulandı):**
- `/signup` ekranı — "Yeni İşletme" (yeni `tenants` satırı, kullanıcı owner) veya "Davet Kodum Var" (mevcut kiracıya belirtilen rolle katılma).
- `ensure_tenant_bootstrap(p_tenant_name, p_invite_code)` RPC (0041) — tek atomik giriş noktası, idempotent (zaten üyeliği olan kullanıcı için no-op). Gecikmeli e-posta onayı senaryosunu (Confirm email açıksa `signUp()` hemen oturum dönmez) kapatmak için şirket adı/davet kodu `auth.signUp()`'ın `data:` (`user_metadata`) parametresinde saklanır; RPC parametresiz çağrıldığında oradan okur.
- `tenant_invites` tablosu + `create_tenant_invite(p_role)` RPC — yalnız owner/admin, 8 haneli rastgele kod üretir, 7 gün geçerli.
- Owner/admin için üst bar/mobil menüde "Personel Davet Et" (`staff_invite_dialog.dart`).
- **⚠️ Provizyon kontrolü router'da DEĞİL, `AppScaffold`'da yapılır (yaşanmış hata):** `ensureTenantProvisionedProvider`'ı router'ın `redirect`'inde `await` etmek go_router'ın `refreshListenable`'ı (auth state değişimleri) ile çakışıp uygulamanın canlıda KALICI BEYAZ EKRANDA kilitlenmesine yol açtı — CanvasKit/`main.dart.js` yüklenip çalışıyordu ama hiçbir widget asla ilk frame'i tamamlamıyordu (network/console'da hata YOKTU, sessizce donuyordu — `flutter analyze`/test bunu YAKALAMAZ). Çözüm: router senkron kalır (yalnız `loggedIn`/`goingToPublic` kontrolü), provizyon kontrolü `AppScaffold.build()`'da `ref.watch(ensureTenantProvisionedProvider).isLoading` ile bir widget-seviyeli yükleniyor ekranı olarak yapılır — **asenkron bir kontrolü asla go_router `redirect`'ine koyma.**
- **Rol-bazlı UI kısıtlaması (tamamlandı):** `currentMembershipProvider.role` üç yüzeyde kısıtlar (kullanıcı kararı — Kasa, maliyet fiyatları, Satışı Sil/düzenleme; Personel Davet Et zaten owner/admin'e özeldi). **Kasa:** `app_scaffold.dart` `_NavItem.ownerOrAdminOnly` + `_visibleNavItems()` menüden gizler (sidebar/bottom-nav/drawer ÜÇÜ de aynı filtreli listeyi kullanır); `KasaScreen.build()` ayrıca ikinci savunma katmanı olarak `membership != null && !isOwnerOrAdmin` ise `_KasaAccessDenied` gösterir (doğrudan URL'e karşı — menüden gizlemek TEK BAŞINA yeterli değil, web'de route korumasız). **Maliyet fiyatları:** `products_list_screen.dart` `_visibleColumns` getter'ı `ProductColumn.alis`'i staff için `productColumnsProvider`'ın kişisel tercihinden BAĞIMSIZ filtreler (owner'ın kolon tercihini bozmadan, yalnız render anında); kolon seçici dialog'da "Alış Fiyatı" seçeneği de gizlenir; mobil kart + Ürün Özet dialog'undaki "Toplam ürün maliyeti" toplamı da aynı gerekçeyle (agregat sızıntı) gizli. **Satışı Sil/düzenleme:** `sale_edit_screen.dart` `_canEdit` getter'ı (membership `null` iken ENGELLEMEZ — owner/admin çoğunluk senaryosu gecikmesin) Kaydet/Satışı Sil butonlarını + kalem düzenleme (miktar/fiyat/ekle/sil) etkileşimlerini devre dışı bırakır, "Salt okunur" bandı gösterir. **Üçünde de ortak desen:** menüden/UI'dan gizleme birincil savunma, ekranın kendisi ikinci katman — `Kasa`'da bu açıkça ayrı bir widget (`_KasaAccessDenied`), diğerlerinde tek tek kontrol noktası. **Doğal uzantı — Denetim Kaydı (`lib/features/audit/`, 0044 migration):** kimin ne zaman sildiğini görmek isteyenler için `/denetim` (owner/admin'e özel, `_AuditLogAccessDenied` AYNI ikinci-katman deseni) — `AuditLogRepository.log()` ikincil bir yan etki (asıl işlemi geri almaz, migration uygulanmadıysa sessizce yutulur). Kapsam: satış silme, ürün silme (tekil+toplu), müşteri silme, ödeme/borç hareketi silme (tekil+toplu). **⚠️ Bilinçli tutarsızlık:** rol-bazlı kısıtlama yalnız `SaleEditScreen`'i kapsar — `CustomerDetailScreen`'deki satış/ödeme/müşteri silme (AYNI `SalesRepository.deleteSale`'i çağırır) staff'a hâlâ açık, yalnız audit-loglanır, ENGELLENMEZ (kullanıcı bunu istedi: "audit log kapsamını genişlet", erişim kısıtlaması DEĞİL — genişletme kararı ayrı bir konuşma gerektirir).

**Faz C (kısmi) — Marka (tamamlandı, canlıda doğrulandı):**
- `currentTenantProvider` (`tenants.name`) — sidebar/topbar/mobil çekmecedeki hardcoded "NicePOS" yerine kiracının kendi adı gösterilir. Giriş/kayıt ekranları BİLİNÇLİ OLARAK "NicePOS" platform adını korur (henüz hangi kiracıya ait olduğu bilinmiyor).
- `update_tenant_name(p_name)` RPC (0042, yalnız owner/admin) — "İşletme Adı" butonu. **⚠️ RPC sonrası `ref.invalidate(currentTenantProvider)` ŞART** — keepAlive provider kendiliğinden yenilenmez (yaşanmış hata: isim değişse de ekran eski değeri göstermeye devam ediyordu).
- Logo/renk white-label BİLİNÇLİ OLARAK ERTELENDİ — Faz E ile birlikte ele alınması gerekiyordu, storage bucket'ları o ana kadar kiracı-izole değildi (üstüne "genel marka logosu" eklemek çapraz-kiracı üzerine yazma riski taşırdı).

**Faz E — Storage kiracı-izolasyonu (tamamlandı, canlıda doğrulandı):**
- `product-images` (public okuma korunur, storefront için) ve `etiket_pdfleri` (private) bucket'larının yazma/okuma RLS'i artık `(storage.foldername(name))[1] = current_tenant_id()::text` (0043) — öncesinde `auth.role()='authenticated'` idi, herhangi bir kiracı başka bir kiracının dosya adını bilirse/tahmin ederse okuyup üzerine yazabilirdi (etiket_pdfleri'nde `list()` zaten TÜM kiracıların dosyalarını karışık listeliyordu).
- `ProductRepository.uploadImage()` ve `LabelsStorageRepository`'nin tüm metodları path'i `<tenant_id>/...` öneki ile kurar (`lib/core/supabase/tenant_context.dart` → `currentTenantIdOrThrow()`, repository içine gömülü — hiçbir çağrı noktası, `product_form_screen.dart`/`labels_screen.dart`, DEĞİŞMEDİ).
- **⚠️ Mevcut dosyaların taşınması SQL İLE YAPILAMAZ** — `storage.objects.name` kolonunu doğrudan UPDATE etmek metadata'yı gerçek nesne baytlarından ayrıştırır. Storage REST API'nin `move` endpoint'i UPDATE RLS gerektirdiğinden (bucket politikaları yalnız select/insert/delete grantlıyken) 400 döner — **copy+delete** (select+insert+delete yeterli) ile taşınmalı. Mevcut dosyalar bu şekilde (tarayıcının kendi oturumundaki `access_token` localStorage'dan okunup Storage REST API'sine doğrudan `fetch()` ile) taşındı.
- **⚠️ Deploy sıralaması şart:** yeni kod (tenant-önekli path yazan) ÖNCE canlıya çıkmalı, storage RLS migration'ı (0043) SONRA uygulanmalı — tersi olursa eski (önek'siz) kod yeni RLS tarafından reddedilir (kısa bir kırılma penceresi).

**Faz D — Etiket şablonları (tamamlandı):** Geniş Logo (`genis_logo_figur.png`) ve İndirim Etiketi (`nice_logo_indirim.png` + sabit "EV GEREÇLERİ & HIRDAVAT" metni) artık kiracı-bazlı — sabit paket asset'leri KALDIRILDI. **KARAR (kullanıcı onaylı):** yeni tenant'lar için nötr/boş varsayılan; hardcoded NicePOS markası hiçbir tenant'a varsayılan olarak sızmaz. Bu iki sekme artık Raf/Poster/Ürün Etiketi'nin zaten kullandığı **paylaşılan** `LabelSheetState.logoDataUrl` mekanizmasını kullanır (`showLogoActions: true`, `LabelsStorageRepository.uploadLogo/fetchLogo/removeLogo` — yeni bir Storage anahtarı YOK) — bir kiracı Raf'ta logo yüklerse Geniş Logo/İndirim'de de otomatik görünür. **Tagline** (İndirim'in logo-altı metni) yeni bir Storage text-key ile (`LabelsStorageRepository.uploadTagline/fetchTagline`, anahtar `__store_tagline.txt`, `logoKey` ile birebir desen) kiracı-bazlı — boşsa satır hiç basılmaz, DB migration GEREKMEDİ. **⚠️ Genelleştirme gerçek bir layout işiydi, veri-kaynağı değişimi değil:** eski Geniş Logo hücresi `genis_logo_figur.png`'yi tam-hücre arka plan yapıp fiyat/ad/barkod'u SABİT ORANLI (`_kWFigPriceLeft` vb.) bu spesifik illüstrasyonun boş alanına bindiriyordu — rastgele bir kiracı logosuyla bu konumlandırma anlamsız kalırdı. Hücre bu yüzden **dikey `Expanded(flex:)` akışına** (logo → fiyat → ad → barkod → alt satır, düz zemin üstünde ortalı `BoxFit.contain` logo) yeniden tasarlandı — Flutter önizleme (`_WideLabelCell`), PDF (`label_pdf.dart` `_wideCell`) ve web print (`etiket_print_web.dart` `.wcell` CSS) ÜÇÜ de aynı oranları paylaşır. İndirim hücresi zaten Column-tabanlıydı, yalnız parametre değişti (logo/tagline artık argüman, sabit asset/metin değil).

**Faz G altyapısı (kısmi — gerçek faturalama olmadan yapılabilecek kısım tamamlandı):** `tenants.plan`/`is_active` artık uygulama tarafında OKUNUYOR ve `is_active=false` gerçekten kilitliyor — `currentTenantProvider`/`TenantInfo` bu iki alanı da select eder (migration GEREKMEDİ, RLS zaten satır-bazlı izin veriyordu), `AppScaffold.build()` provizyon kontrolüyle AYNI desende (widget-seviyeli, router `redirect`'inde DEĞİL) `is_active=false` ise kilitleme ekranı + Çıkış Yap gösterir. **Bilinçli KARAR: self-servis plan değiştirme YOK** — `plan`/`is_active` platform-yönetim alanları, tenant'ın kendi owner/admin'i tarafından değiştirilemez (gerçek ödeme olmadan self-servis plan seçimi anlamsız kalırdı); kontrol yalnız Supabase Table Editor'dan elle yapılır — plan doc'unun öngördüğü "ileride kilitleme için kanca noktası" tam olarak budur. Gerçek faturalandırma/kartla-tahsilat (iyzico) hâlâ kapsam dışı.

**Kalan fazlar (henüz yapılmadı):** Faz F (storefront çoklu-kiracı, slug/subdomain yönlendirmesi — routing yaklaşımı henüz netleşmedi, bkz. "Yapılacaklar"daki domain maddesi), gerçek faturalandırma/ödeme (iyzico entegrasyonu bekliyor).

**Diğer yaşanmış migration dersleri:**
- `CREATE OR REPLACE VIEW` mevcut sütunların pozisyonunu/adını DEĞİŞTİREMEZ (42P16 hatası) — yeni bir sütun (`tenant_id`) yalnız listenin EN SONUNA eklenebilir, araya sıkıştırmak sonraki sütunları "yeniden adlandırma" gibi yorumlanır.
- `DO $$ ... $$` bloklarında dinamik `DROP POLICY`/`CREATE POLICY` için politika adı `format()`'ta `%I` (identifier) ile geçirilmeli, `%L` (string literal) DEĞİL — `%L` `DROP POLICY IF EXISTS 'ad' ON tablo` gibi geçersiz bir sözdizimi üretir.

## Online Satış (Storefront)

Ana POS'un dışında, **ayrı bir Flutter web projesi** olarak kurulu ikinci bir müşteri-karşısı site: `storefront/` (paket adı `nicepos_storefront`, kendi `pubspec.yaml`'ı var, ana projeyle kod paylaşmaz). Aynı Supabase projesine (aynı `SUPABASE_URL`/`SUPABASE_ANON_KEY` dart-define'ları) `anon` rolüyle bağlanır.

- **Kontrol paneli** ana uygulamada: `/online-satis` (`lib/features/online_satis/`) — canlı ürün arama (sales_screen'deki desenin sadeleştirilmiş hali) ile seçilen ürün `products.is_online_active=true` yapılır; ürün formundaki mevcut "Online Aç" anahtarıyla AYNI alanı paylaşır (ikisi birbirini tamamlar, ayrı bir online-ürün tablosu YOK).
- **Storefront ekranları** (`storefront/lib/`): anasayfa (`features/home/`, kategori `Wrap` filtresi + arama + ürün grid'i), ürün detay (`features/product/`), sepet (`features/cart/`, yalnız bellekte — `cartProvider`, sayfa yenilenince sıfırlanır, bilinçli v1 basitleştirmesi), checkout (`features/checkout/`, misafir bilgi formu → `create_online_order` RPC → sipariş kodu onay ekranı). State: plain `flutter_riverpod` (codegen YOK, ana projenin `@riverpod` deseninden farklı — küçük proje için daha az boilerplate). Routing: `go_router`, tüm rotalar `_fadeThroughPage` (ana uygulamanın `router.dart`'ıyla birebir aynı 240ms/180ms `easeOutCubic` fade+slide eğrisi, `storefront/lib/app.dart`).
- **v1'de online müşteri GİRİŞİ (Supabase Auth hesabı) YOK, yalnız misafir sipariş.** Bu karar `0028_online_satis.sql` yazıldığında (RLS hâlâ `auth.role()='authenticated'` blanket-tam-erişimken) o eski modele göre gerekçelendirilmişti — RLS artık kiracı-bazlı (bkz. "Çok Kiracılı Mimari" bölümü), ama gerçek müşteri hesabı hâlâ ayrı bir tasarım işi: bir online müşteri `memberships`'e (staff/owner/admin) dahil edilmemeli, kendi ayrı bir "customer" kimlik modeli gerektirir — bu Faz F'nin (storefront çoklu-kiracı) kapsamına girer, henüz yapılmadı.
- **Tasarım sistemi AYRI:** `storefront/design/design-tokens.md` — ana uygulamanın koyu "Enstrüman Konsolu" diliyle KARIŞTIRILMAZ, sıcak/aydınlık perakende kimliği (Space Grotesk başlık + Inter gövde tipografik çifti, `google_fonts`; ana uygulamanın "altın ray" imzasının statik/ışıltısız yorumu — hero banner + AppBar alt çizgisi). Agent rosteri de ayrı (`magaza-tasarim-lideri`/`magaza-tasarimci`/`magaza-gorsel-elestirmen` — bkz. yukarıdaki "Agent'lar" bölümü).
- **⚠️ Bilinen tuzak:** yatay `ListView` cross-axis'te çocuklarına DAR (tight) yükseklik zorlar — 200+ kategori bu yüzden `Wrap` (sabit `maxHeight` + dikey kaydırma) ile gösterilir, yatay `ListView` DEĞİL (kategori chip'i içeriden taşıyordu, yaşanmış hata).

### Ödeme Entegrasyonu (planlandı, HENÜZ YAPILMADI)

**Karar: iyzico.** Türkiye'de TL hesaba ödeme aktarımı yapan, hosted checkout/iframe sunan (kart bilgisi bize hiç dokunmaz, PCI yükü minimal) bir sağlayıcı gerekiyordu — Stripe TL/Türkiye tarafında sınırlı olduğundan elenmiş, PayTR ikinci sırada değerlendirilmişti. **Kullanıcının henüz bir iyzico üye işyeri hesabı YOK** — bu, entegrasyon çalışmasının önündeki ilk ve zorunlu adım (KYC/işletme doğrulaması gerektirir, Claude bunu kullanıcı adına yapamaz).

**Şu anki durum (ödeme entegrasyonu yokken):** `create_online_order` RPC'si siparişi doğrudan `'yeni'` durumunda oluşturuyor — online mağazadan gelen HİÇBİR sipariş şu an gerçek bir ödeme adımından geçmiyor (fiilen "kapıda ödeme/elle mutabakat" modeli). Bu bilinçli bir v1 sınırlaması, ödeme eklenene kadar böyle kalacak.

**Planlanan mimari (üye işyeri hesabı açılınca uygulanacak):**
1. Checkout akışına bir ödeme adımı eklenir — iyzico'nun hosted Checkout Form'una yönlendirme ya da embed (kart verisi storefront'a/Supabase'e hiç değmez).
2. **Sunucu tarafı bir webhook/callback ucu şart** — istemcinin "ödeme başarılı" demesine GÜVENİLMEZ, yalnız iyzico'nun imzalı async callback'i siparişi kesinleştirir. Bu, şu an sistemde OLMAYAN yeni bir bileşen gerektirir: Supabase Edge Function ya da (storefront zaten Cloudflare'de barındığından daha doğal) bir Cloudflare Worker.
3. `online_orders` şemasına ödeme alanları eklenmesi gerekecek (ör. `payment_status`, `payment_provider_ref`) — mevcut `status` enum'u (`yeni/onaylandi/hazirlaniyor/kargoda/tamamlandi/iptal`) sipariş lojistik durumu için, ödeme durumu için AYRI bir alan daha doğru olur.
4. Stok düşümü şu an sipariş anında (`create_online_order` içinde) yapılıyor — ödeme eklenince bunun ödeme ONAYINDAN SONRAYA mı taşınacağı (stok kilitleme riski vs. ödenmemiş sipariş için stok bloke etme riski) ayrıca karara bağlanmalı.

**Sıradaki somut adım:** kullanıcı iyzico üye işyeri başvurusunu tamamlayıp API anahtarlarını aldığında bu bölüm güncellenip gerçek migration/Worker/checkout-akışı işine başlanacak.

### Deploy — Cloudflare Pages

Site: `https://nicepos-online-satis.pages.dev` (custom domain YOK, deneme aşaması). GitHub Pages'ten TAMAMEN AYRI bir deploy akışı — GitHub Actions/webhook'a bağlı DEĞİL, `wrangler` CLI ile elle deploy edilir:

```powershell
cd storefront
flutter build web --release `
  --dart-define=SUPABASE_URL=https://maogkrllltlxkfdwfsdj.supabase.co `
  "--dart-define=SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1hb2drcmxsbHRseGtmZHdmc2RqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODE1MDk3NjQsImV4cCI6MjA5NzA4NTc2NH0.BsPCU9Hx1OuMf-JI7TU4I6SRuSKsLcmL2MIpQc2gKp0"
cd ..
npx wrangler pages deploy storefront/build/web --project-name nicepos-online-satis --branch master
```

`storefront/build/` git'e commit EDİLMEZ (kendi `.gitignore`'u `/build/` — ana projenin `docs/`+`build/web` deseninin AKSİNE, burada build çıktısı yalnız Cloudflare'e gider, repoda tutulmaz). Kaynak kod (`storefront/lib/`) normal şekilde ana repoya commit edilir. `.wrangler/` (yerel wrangler cache/oturum) kök `.gitignore`'da hariç tutulur.

## Deploy — GitHub Pages

Site: `https://ercinnn.github.io/nicepos` · Repo: `https://github.com/ercinnn/nicepos` · Branch: `master`, klasör: `/docs`. Yerel checkout (`C:\Projects\Flutter\nicepos`) doğrudan bu repo — `origin` zaten doğru remote'a bağlı, ayrı bir deploy klasörü YOK.

**Akış:** `flutter build web --release --base-href /nicepos/ --dart-define=...` → `Remove-Item -Recurse -Force docs; Copy-Item -Recurse build\web docs` → `git add docs build; git commit`. Push öncesi `git fetch` + `git log origin/master..master` ile fast-forward teyit et.

**Kullanıcı tercihi:** deploy'da build+commit'i Claude hazırlar, `git push origin master`'ı kullanıcı kendisi çalıştırır (komut kendisine verilir, sonra `git fetch && git log origin/master -1` ile doğrulanır).

**⚠️ `MissingPluginException` (release'de, localde değil) — yaşanmış kök neden:** Yeni bir paket (`pubspec.yaml`) eklendikten sonra `.dart_tool` derleme önbelleği bayat kalıp web plugin registrant'ını (ör. `flutter_tts`'in web implementasyonu) atlayabiliyor — `flutter run -d web-server` her seferinde taze başladığı için sorun çıkmaz ama `flutter build web --release` önbelleği yeniden kullanabilir. Belirti: konsolda `MissingPluginException(No implementation found for method X on channel Y)`, paket kodu doğru olsa bile. **Çözüm:** yeni bağımlılık eklendikten sonraki İLK release build'den önce `flutter clean && flutter pub get` çalıştır.

**⚠️ Ortam izolasyonu — agent yazma engeli:** Arka planda spawn edilen agent'lar paylaşılan checkout'a doğrudan yazamaz ("hasn't isolated its changes yet" hatası) — bu yüzden kod değişikliği gerektiren her görev `isolation: "worktree"` ile verilir (agent build/push YAPMAZ), ardından ana oturum (bu kısıtlamaya tabi değil) `git merge worktree-agent-<id>` ile ana checkout'a alır, `git worktree remove` ile temizler, `flutter analyze` ile doğrular. Yalnızca markdown/doküman değişikliğinde web rebuild gerekmez.

**⚠️⚠️ Agent commit ETMEYEBİLİR — iş kaybı tuzağı (yaşanmış):** Kabuk erişimi olmayan alt agent'lar (ekran tasarımcılarının araç seti `Read/Edit/Glob/Grep`'tir, `Bash` YOK) worktree'de **commit edemez**; değişiklikler orada *uncommitted* kalır. Belirti: `git merge worktree-agent-<id>` → **"Already up to date."** ve `git worktree remove` → *"contains modified or untracked files"*. 🔴 **Bu durumda `--force` ile SİLME — tüm iş kaybolur.** Doğru kurtarma:
```powershell
cd .claude\worktrees\agent-<id>
git status                     # önce ne var bak (untracked dosyalar dahil)
git add -A; git commit -m "..."
cd C:\Projects\nice-pos
git merge worktree-agent-<id>
git worktree remove .claude\worktrees\agent-<id>
```
Yani "Already up to date" **başarı değil, alarmdır** — merge'den sonra `git log --stat -1` veya `git diff HEAD~1 --stat` ile beklenen dosyaların gerçekten geldiğini doğrula. (⚠️ Merge **commit'lerinde** `git log --stat -1` boş gelir; içeriği görmek için `git diff HEAD^1 HEAD --stat` kullan.)

**🔴 Worktree'ler ESKİ commit'ten açılır — VARSAYILAN DAVRANIŞ, her turda kontrol et.** Yeni worktree'nin tabanı güncel `master` DEĞİL, **oturumun başladığı commit**tir. Aynı oturumda arka arkaya verilen görevlerde bu her seferinde tekrarlar: v2.2/v2.3 turlarında üç ayrı worktree de `dbdd4ae`'den açıldı, master ise sırayla `9d7a42d` → `9615918`'e ilerlemişti. Yani **agent bir önceki turun işini göremez** ve üzerine yazarsa onu geri alır.

**Görev metnine ZORUNLU "Adım 0" koy:**
- **Kabuk erişimi OLAN agent** (`general-purpose` vb.) → `git status --short` (temiz olmalı) + `git merge --ff-only master`. Worktree'de yerel değişiklik yokken bu **saf ileri sarmadır, çakışma imkânsızdır**. Sonra sentinel ile doğrula.
- **Kabuk erişimi OLMAYAN agent** (ekran tasarımcıları: `Read/Edit/Glob/Grep`) → tabanını **tazeleyemez**, yalnız fark edip durabilir. Bu yüzden taban tazeliği kritikse görevi kabuklu bir agent'a ver.
- **Sentinel yöntemi:** son turda eklenen bir sembolü ve token başlığını arat (ör. `trailingTight` + `### 6.8`). İkisi de yoksa taban eski → DUR.

**Merge stratejisi:** Worktree **temiz + fast-forward** ise `git merge --ff-only master` risksizdir. Ama worktree'de **yerel değişiklik varken** taban eskiyse `git merge` üç yönlü birleştirmeye döner ve aynı dosyalarda çakışır — o durumda yalnız ilgili dosyaları çek:
```powershell
git checkout worktree-agent-<id> -- <dosya1> <dosya2> ...
git diff --stat HEAD    # beklenen dosyalar geldi mi
```

**Diğer notlar:**
- `docs/main.dart.js` her kod değişikliğinden sonra rebuild edilmeden ESKİ kalır — "değişikliği göremiyorum" şikâyetinde önce bunu kontrol et, sonra service worker/tarayıcı önbelleğini (hard refresh/gizli pencere) düşün.
- `.gitignore` `/build/*`'ı yoksayar ama `!/build/web` izler → repo hem `build/web` hem `docs` tutar, deploy'da ikisi de commit edilir.
- `supabase_flutter` **2.14.2**'de sabit tutulmalı — 2.15.x web'de açılış hatası veriyordu (`passkeys_web`/`ua_client_hints` → `dart:html`).
- PowerShell'de çok satırlı/çift tırnaklı commit mesajları için here-string yerine tek satırlık `git commit -m '...'` tercih et.
- `.gitignore`'a `*.sql` (migration'lar hariç: `!supabase/migrations/*.sql`) ve `/supabase/.temp/` eklendi — `pg_dump` yedekleri ve Supabase CLI önbelleği yanlışlıkla public repo'ya commit edilmesin diye (yaşanmış hata: bir yedek dosyası proje köküne düşüp `git status`'ta göründü).

## Önemli Konvansiyonlar

- **Model sınıfları:** `fromMap()` + `toInsertMap()`, ORM yoktur.
- **Repository'ler:** `Supabase.instance.client` doğrudan.
- **Dil:** UI metinleri ve yorumlar Türkçedir.
- **Tarih:** `initializeDateFormatting('tr_TR')`, formatlama `lib/core/utils/formatters.dart`.
- **Dialog context:** `showDialog(builder: (dialogContext) => ...)` — `Navigator.pop` için her zaman `dialogContext`, parent `context` değil. State güncellemesi pop'tan SONRA.
- **Kamera:** `mobile_scanner` — `kIsWeb` guard ile yalnız native'de.
- **Web-only özellikler** (Yazdır, Excel export, TTS, Etiket PDF): hepsi `kIsWeb` guard'ı veya conditional export (`*_web.dart`/`*_stub.dart`) deseniyle native'de no-op/gizli.
- **Native-only özellikler** (kamera barkod okuma, çevrimdışı ürün senkronu/sqflite): tersine `!kIsWeb` guard'ı ile web'de no-op/gizli — bkz. "Mobil Çevrimdışı Ürün Ekleme/Düzenleme" bölümü.
- **Layout (kaydırılabilir sayfa = sınırsız yükseklik):** stretch'li/Expanded'lı `Row` → `IntrinsicHeight` ile sar; dikey `Column`'da `FractionallySizedBox` (heightFactor null) aynı sonsuz-yükseklik hatasını verir → genişlik için `LayoutBuilder + SizedBox(width:...)` kullan. Bu tür render hataları `flutter analyze`'da GÖRÜNMEZ — widget testiyle veya gözle yakalanır.

## Yapılacaklar

Henüz uygulanmamış, kullanıcıyla konuşma sırasında ortaya çıkan özellik fikirleri. Kullanıcı "yapılacaklar listesi" isterse bu liste madde madde okunur/güncellenir.

- **Düşük stok / stok tükenmesi uyarısı** — `product_status` view'ı zaten "Tükendi" durumunu sunucuda hesaplıyor; Dashboard'a rozet/bildirim katmanı eklenecek. Gerçek zamanlı bildirim (push/e-posta) istenirse ayrı bir tetikleyici (Supabase Edge Function veya periyodik client kontrolü) gerekir — yalnız "Dashboard'da görünür uyarı" ise mevcut mimariyle ek maliyeti düşük.
- **Müşteri SMS/WhatsApp bildirimi** (borç hatırlatma, sipariş hazır) — dış servis entegrasyonu gerektirir, sağlayıcı henüz seçilmedi.
- **Audit log kapsamının daha da genişletilmesi** — `lib/features/audit/` (0044 migration) şu an satış silme (SaleEditScreen + CustomerDetailScreen), ürün silme (tekil+toplu), müşteri silme, ödeme/borç hareketi silme (tekil+toplu) loglar. `products_list_screen.dart`'taki toplu Excel içe/dışa aktarım gibi diğer hacimli işlemler henüz kapsam dışı — istenirse eklenebilir.
- **iyzico ödeme entegrasyonu** — ayrıntılı plan yukarıda "Online Satış (Storefront) → Ödeme Entegrasyonu" bölümünde; kullanıcının iyzico üye işyeri başvurusu tamamlanmadan başlanamaz.
- **Müşteri borç yaşlandırma görünümü** — kimin borcu ne kadar süredir duruyor, en riskli müşteriler kim. Veri (`customer_balances`, `customer_payments`) zaten var, eksik olan yalnızca bir "yaşlandırma" raporu/görünümü.
- **Offline kapsamının genişletilmesi** — Açık Hesap/Parçalı/İade şu an dead-zone'da çalışmıyor (bkz. Mobil Çevrimdışı Satış bölümü, "Kapsam dışı" notu); dükkânda sinyal çekmeyen bölgede bu satış türleri de sık oluyorsa değerli olur, aksi halde gereksiz karmaşıklık katar.
- **Online sipariş bildirimi** — storefront'tan bir sipariş geldiğinde POS tarafında (ürün/satış senkron toast'larıyla aynı desende) sesli/görsel bir bildirim yok; şu an "Online Satış" sayfasına gidip elle kontrol ediliyor. Düşük efor, storefront canlı kullanılıyorsa hemen fayda sağlar.
- **e-Fatura/e-Arşiv entegrasyonu** — şu an yalnız kendi A4 sepet çıktısı var, resmi mali fatura/fiş yok. KDV mükellefiyseniz potansiyel bir yasal zorunluluk açığı olabilir; önem kullanıcının bu konudaki durumuna bağlı.
- **Gün sonu özet bildirimi** — akşam kapanışta günlük ciro/nakit-POS kırılımını otomatik WhatsApp/e-posta ile göndermek. Borç hatırlatmadan ayrı bir kullanım ama aynı SMS/WhatsApp altyapısını paylaşabilir.
- **Test kapsamının genişletilmesi** — şu an yalnız birkaç render/golden test var (dashboard, ödeme paneli, sepet, etiket); offline senkron mantığı, Analiz/Görevler gibi hesaplama ağırlıklı yerlerde birim test yok. Kullanıcıya doğrudan görünmez ama regresyon riskini azaltır.
- **Her kullanıcı için domain adresi alma sekmesi** — kullanıcının talebi, ayrıntı netleşmedi (muhtemelen storefront'un paylaşılan `nicepos-online-satis.pages.dev` yerine her mağaza sahibinin kendi özel alan adını bağlayabildiği/satın alabildiği bir panel). Kapsam (yalnız mevcut bir domain'i Cloudflare Pages'e bağlama mı, yoksa bir domain kayıt/satın alma akışı mı) konuşulup netleştirilmeli.
