# CLAUDE.md

Bu dosya, Claude Code'a bu depoda çalışırken rehberlik eder.

## Agent'lar

`.claude/agents/` altında 4 özel agent tanımlı:
- **`tasarim-lideri`** — tasarım yönü/token kararları verir, `design/design-tokens.md`'nin tek sahibi. Kod yazmadan önce görsel bir karar gerekiyorsa buradan geçer.
- **`ekran-tasarimcisi`** — `tasarim-lideri`nin onayladığı yönü Flutter koduna uygular (alt-agent).
- **`gorsel-elestirmen`** — responsive/token uygunluğunu QA eder, kod yazmaz (alt-agent).
- **`yazilim-uzmani`** — tasarım dışı somut görevler (bug fix, özellik, refactor) için genel amaçlı agent.

`design/design-tokens.md` tasarım sisteminin tek doğru kaynağıdır (palet, tipografi, spacing, §4 imza öğesi: Hero Tutar + Altın Ray, §5 bileşen notları + KARAR geçmişi). Ekran tasarımcıları bu dosyayı okur, değiştirmez.

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

## Mimari

### Katmanlar

```
lib/
  core/
    constants/     # AppColors, AppSizes
    theme/         # app_theme.dart + app_theme.g.dart (Riverpod provider)
    utils/         # formatters.dart, responsive.dart (isMobile <650px / isDesktop)
    supabase/      # SupabaseConfig, supabaseClientProvider
    widgets/       # InstrumentHero — paylaşılan "enstrüman konsolu" hero'su (design-tokens §6.3, v2.0)
  app/             # Router, AppScaffold (web: sidebar + canlı saat; mobil: Drawer + BottomNav)
  features/
    auth/          # Login, ConfigMissingScreen
    home/          # Anasayfa — kısayol kart grid + Dashboard (stat kartları + grafikler)
    products/      # Ürünler, Ürün Grupları, Liste Gir
    customers/     # Müşteri listesi, detay (geçmiş işlem yönetimi + toplu yazdırma), ödeme
    sales/         # Satış ekranı — 5 sekme, sepet, ödeme paneli, hızlı ürünler
    reports/       # Günlük / Tarihsel / Ürün raporları (3 sekme)
    labels/        # Etiket — raf etiketi A4 yazdırma
    kasa/          # Kasa — gelir-gider defteri + mutabakat + firma giderleri
```

### Tasarım Sistemi

Tek kaynak: `lib/core/theme/app_theme.dart` (`appThemeProvider`, `@Riverpod(keepAlive: true)`). Palet: beyaz zemin, lacivert (#1B2A4A) butonlar, altın (#D4B86A) kenarlıklar — sabitler `lib/core/constants/app_colors.dart`. Detaylı token/karar geçmişi: `design/design-tokens.md`.

**v2.0 — "Enstrüman Konsolu" tasarım dili (design-tokens §6):** Kimlik "uzay üssü / görev-kontrol" yönüne evrildi — **palet KORUNDU** (sıcak lacivert + altın + beyaz; yeni hex yok, mevcut lacivert rampası "panel" yüzeyi olarak terfi etti). Yaklaşım **hibrit**: çalışma ekranları (satış/stok/müşteri liste-tablo/form/rapor tabloları) **aydınlık** kalır; **metrik + hero + dashboard yüzeyleri koyu "enstrüman paneli"ne** döner (`primaryDark → primaryDeep` gradyan + soluk graticule + altın reticle köşeler + tick'li ray + mikro-etiket). İmza = Hero tutar + **altın ray (korundu)** + enstrüman detaylandırması. **Faz 1:** Dashboard (`dashboard_section.dart` — bespoke, ışıltı/asimetri korundu). **Faz 2:** Raporlar/Kasa (altın ray) + Müşteri liste/detay (**semantik ray** — borç=danger, alacak/sıfır=success; reticle yine altın) → hepsi tek paylaşılan **`InstrumentHero`** bileşeninden (`lib/core/widgets/instrument_hero.dart`, statik/animasyonsuz — ışıltı YALNIZ Dashboard'a ait). Kurallar korunur: ekran başına tek hero, altın ekonomisi, altın ray yalnız hero'da. ⚠️ Koyu panele Row eklerken **yatay-taşma tuzağı** (CLAUDE.md Dashboard notu) tekrar ısırır — `InstrumentHero` bunu `FittedBox(scaleDown)+IntrinsicWidth+CustomPaint` ile çözer (bounded/unbounded güvenli; `LayoutBuilder`, `IntrinsicWidth` altında çökertir → tick'ler `CustomPaint`).

### State Yönetimi — Riverpod Generator

TÜM provider'lar `@riverpod` / `@Riverpod(keepAlive: true)` ile üretilir; her dosyada `part '...g.dart'` zorunlu. Dashboard provider'ları (`todaySummary`, `dailySales(days)`, `currentYearMonthly`, `historicalYearly` vb.) **autoDispose** — Android'de soğuk açılışta ilk sorgu boş dönerse `keepAlive` bunu kalıcı dondururdu (yaşanmış bug), bu yüzden hepsi autoDispose. `salesCartProvider`/`paymentInputProvider`/`productColumnsProvider`/`labelSheetProvider` gibi UI-durumu tutan provider'lar `keepAlive`.

## Satış Akışı

`SalesCart` (Riverpod notifier, `sales_cart_notifier.dart`) 5 müşteri sekmesini yönetir (`SalesState.activeTab` + `List<CustomerTabState>`).

- **Canlı ürün arama:** barkod okutup Enter → doğrudan sepete ekler. Yazı yazınca (250ms debounce) `OverlayPortal` ile canlı öneri listesi açılır (Türkçe-duyarlı substring arama).
- **Sepet (`cart_table.dart`):** satır bazlı %/₺ iskonto (`_CompactDiscountCell`) + sepet geneli iskonto. **Çoklu seçim + toplu %iskonto:** her satırın solunda yuvarlak seçim ikonu (`_RowSelectToggle`); seçim varken üstte "Seçilenlere % İndirim Uygula" barı belirir, yalnız YÜZDE tipinde iskonto uygular ve yalnız seçili satırları etkiler (mevcut tekil %/₺ iskontodan ayrı bir akış). Seçim `Set<int>` index bazlı, sekme değişince veya satır sayısı değişince otomatik temizlenir.
- **Birim fiyat:** elle düzenlenebilir + yanında "Fiyat1 yap" radyosu (`products.price1`'i kalıcı günceller).
- **Mobil:** kamera barkod okuma, sepet kart listesi (sola kaydır → sil), ödeme `DraggableScrollableSheet`.
- **Ödeme paneli (`payment_panel.dart`) — hero TOPLAM:** ekranın tek imza öğesi (iri tutar + altın ray). Yanında (yalnız web, `kIsWeb`) 🇬🇧 ikonlu buton — toplamı İngilizce sesli okur (`flutter_tts`, `tts_service.dart` + `english_number_words.dart`). Erkek ses platform bazlı best-effort (kesin garanti yok); `speak()` çağrısı öncesindeki her hazırlık adımı (`setPitch/setVoice/getVoices`) ayrı try/catch korumalı — biri hata verse bile `speak()`'e her zaman ulaşılır.
- **Ödeme tamamlama:** `SalesRepository.completeSale()` → RPC → sales + sale_items insert → stok düşür → borç hareketi.

### Satış Düzenleme & Silme (`SaleEditScreen`)

Rapor ekranlarından ve müşteri detayından açılır; kalem/iskonto/ödeme türünü düzenler. İskonto TL/%-birebir saklanır (yuvarlama farkı olmaz). Ödeme türü değişince (`updateSale`) önce otomatik borç hareketi silinir, sonra kalan borca göre yeniden eklenir — hayalet borç kalmaz. Web'de **Yazdır** (`sale_print.dart` conditional export) A4 sepet detayını yeni pencerede açıp otomatik yazdırır. **Satışı Sil** stok iadesi + bağlı borç hareketi + kayıtları siler.

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

## Müşteri Detayı

`customer_detail_screen.dart` — Alışverişler ve Ödeme/Borç Hareketleri listelerinde tekil + toplu silme. **Toplu yazdırma:** her satışın solunda seçim kutucuğu; seçiliyken (yalnız web) "Seçilenleri Yazdır" butonu, seçilen tüm satışları TEK bir A4 dokümanında (her satış kendi bölümü + genel toplam) yazdırır (`sale_print_web.dart` → `printMultipleSalesA4`).

## Ürünler Sayfası

**Desktop:** `DataTable`, kolon seçici, satır içi tıkla-düzenle (yalnız dokunulan satır `TextField`'a döner — `DataTable` sanallaştırma yapmaz, performans için önemli), `TapRegion` ile otomatik kaydet-kapat. Durum sütunu (Çok Satan/Tükendi/Pasif) sunucuda `product_status` view'ından hesaplanır. Sütun filtreleri + server-side sıralama.
**Mobil:** kart listesi, kamera ile barkod okuma.

**Liste Gir** (4. sekme, yalnız desktop): tedarikçi PDF/JPEG listesi → sütun işaretleme (pdf.js + Tesseract.js OCR yedek) → önizleme/düzenleme ızgarası → kaydet. Alış/satış fiyatı çarpanları (iskonto/KDV farkını telafi eder). **Tekil gönder:** her satırın sağında, toplu "Kaydet"ten bağımsız, o satırı tek başına sisteme yükleyen bir gönder ikonu (barkod tazeliği aynen korunur — göndermeden hemen önce tekrar sorgulanır). Barkod eşleşirse stok additive + fiyat replace, eşleşmezse yeni ürün. Test: `test/liste_gir_extractor_test.dart`.

**Eşlenik Barkod:** aynı fiziksel ürünün farklı barkodlu satırlarını gruplar (`products.equivalent_group_id`); ham veriler değişmez, stok/fiyat toplamı yalnız okuma anında `product_equivalent_aggregate` view'ıyla hesaplanır. Esas fiyat = grubun en son güncellenen satırından. **⚠️ KRİTİK:** `Product.equivalentGroupId` `toInsertMap()`'e KESİNLİKLE dahil edilmez — aksi halde her `update()` grup bağlantısını sessizce kırar; grup yalnız `linkEquivalentBarcode`/`unlinkEquivalentBarcode` ile değişir.

## Raporlar

`/reports` — Günlük / Tarihsel / Ürün raporları. İskonto sütunu `% 82.25` formatında (2 ondalık).

**"TOPLAM CİRO" hero (Günlük + Tarihsel) = nakit-esaslı**, ana sayfa "günlük ciro" ile BİREBİR: `Nakit + POS + Alınan Ödemeler (borç tahsilatı)`; **açık hesap/borç HARİÇ** ("o gün kasaya giren para"). Kaynak: `DailyReportSummary.cashBasisTurnover` (`= cashTotal + posTotal + receivedPaymentsTotal`). `grandTotal` (borç DAHİL) modelde durur ama hero'yu beslemez — yalnız tablo/diğer kullanımlar için. Hero widget'ı `ReportHero` artık paylaşılan `InstrumentHero`'yu sarar (altın ray). Dashboard'ın nakit-esaslı ciro tanımı da aynıdır (`sales_revenue_between` RPC: `paid_amount` + `type='odeme'` tahsilatları).

## Etiket — Raf Etiketi A4 Yazdırma

`/etiket` — üç sekme: **Yeni Etiket** (24 hane, 3×8 ızgara, logo+fiyat+Code128+barkod no+tarih), **Geniş Logo** (10 hane, 2×5 ızgara, sabit marka figürü — turuncu tente + NiCE, 88mm×55mm hücre), **Kayıtlı Dosyalar** (Supabase Storage `etiket_pdfleri` bucket'ı, imzalı URL). Barkod → ürün çözme satış ekranıyla aynı desen. Yazdır/PDF Üret yalnız web. Etiket çıktısı kendi hero'suna (FİYAT, altın ray YOK) sahiptir — app krom'undan ayrı bir görsel dil.

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

## Deploy — GitHub Pages

Site: `https://ercinnn.github.io/nicepos` · Repo: `https://github.com/ercinnn/nicepos` · Branch: `master`, klasör: `/docs`. Yerel checkout (`C:\Projects\Flutter\nicepos`) doğrudan bu repo — `origin` zaten doğru remote'a bağlı, ayrı bir deploy klasörü YOK.

**Akış:** `flutter build web --release --base-href /nicepos/ --dart-define=...` → `Remove-Item -Recurse -Force docs; Copy-Item -Recurse build\web docs` → `git add docs build; git commit`. Push öncesi `git fetch` + `git log origin/master..master` ile fast-forward teyit et.

**Kullanıcı tercihi:** deploy'da build+commit'i Claude hazırlar, `git push origin master`'ı kullanıcı kendisi çalıştırır (komut kendisine verilir, sonra `git fetch && git log origin/master -1` ile doğrulanır).

**⚠️ `MissingPluginException` (release'de, localde değil) — yaşanmış kök neden:** Yeni bir paket (`pubspec.yaml`) eklendikten sonra `.dart_tool` derleme önbelleği bayat kalıp web plugin registrant'ını (ör. `flutter_tts`'in web implementasyonu) atlayabiliyor — `flutter run -d web-server` her seferinde taze başladığı için sorun çıkmaz ama `flutter build web --release` önbelleği yeniden kullanabilir. Belirti: konsolda `MissingPluginException(No implementation found for method X on channel Y)`, paket kodu doğru olsa bile. **Çözüm:** yeni bağımlılık eklendikten sonraki İLK release build'den önce `flutter clean && flutter pub get` çalıştır.

**⚠️ Ortam izolasyonu — agent yazma engeli:** Arka planda spawn edilen agent'lar paylaşılan checkout'a doğrudan yazamaz ("hasn't isolated its changes yet" hatası) — bu yüzden kod değişikliği gerektiren her görev `isolation: "worktree"` ile verilir (agent kendi dalına commit eder, build/push YAPMAZ), ardından ana oturum (bu kısıtlamaya tabi değil) `git merge worktree-agent-<id>` ile ana checkout'a alır, `git worktree remove` ile temizler, `flutter analyze` ile doğrular. Yalnızca markdown/doküman değişikliğinde web rebuild gerekmez.

**Diğer notlar:**
- `docs/main.dart.js` her kod değişikliğinden sonra rebuild edilmeden ESKİ kalır — "değişikliği göremiyorum" şikâyetinde önce bunu kontrol et, sonra service worker/tarayıcı önbelleğini (hard refresh/gizli pencere) düşün.
- `.gitignore` `/build/*`'ı yoksayar ama `!/build/web` izler → repo hem `build/web` hem `docs` tutar, deploy'da ikisi de commit edilir.
- `supabase_flutter` **2.14.2**'de sabit tutulmalı — 2.15.x web'de açılış hatası veriyordu (`passkeys_web`/`ua_client_hints` → `dart:html`).
- PowerShell'de çok satırlı/çift tırnaklı commit mesajları için here-string yerine tek satırlık `git commit -m '...'` tercih et.

## Önemli Konvansiyonlar

- **Model sınıfları:** `fromMap()` + `toInsertMap()`, ORM yoktur.
- **Repository'ler:** `Supabase.instance.client` doğrudan.
- **Dil:** UI metinleri ve yorumlar Türkçedir.
- **Tarih:** `initializeDateFormatting('tr_TR')`, formatlama `lib/core/utils/formatters.dart`.
- **Dialog context:** `showDialog(builder: (dialogContext) => ...)` — `Navigator.pop` için her zaman `dialogContext`, parent `context` değil. State güncellemesi pop'tan SONRA.
- **Kamera:** `mobile_scanner` — `kIsWeb` guard ile yalnız native'de.
- **Web-only özellikler** (Yazdır, Excel export, TTS, Etiket PDF): hepsi `kIsWeb` guard'ı veya conditional export (`*_web.dart`/`*_stub.dart`) deseniyle native'de no-op/gizli.
- **Layout (kaydırılabilir sayfa = sınırsız yükseklik):** stretch'li/Expanded'lı `Row` → `IntrinsicHeight` ile sar; dikey `Column`'da `FractionallySizedBox` (heightFactor null) aynı sonsuz-yükseklik hatasını verir → genişlik için `LayoutBuilder + SizedBox(width:...)` kullan. Bu tür render hataları `flutter analyze`'da GÖRÜNMEZ — widget testiyle veya gözle yakalanır.
