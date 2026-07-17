# Design Tokens — nice-pos

> **Tek doğru kaynak (single source of truth).** Tüm tasarım kararları burada yaşar.
> Yalnızca **tasarım-lideri** agent'ı bu dosyayı düzenler. Ekran tasarımcıları bu
> dosyayı **okur ama değiştirmez**. Bir token burada yoksa, ekranda da kullanılmaz —
> önce buraya eklenir, sonra uygulanır.
>
> **Kod karşılığı:** Değerler `lib/core/constants/app_colors.dart`,
> `app_sizes.dart` ve `lib/core/theme/app_theme.dart` ile birebir hizalıdır.
> Token = belge, kod = uygulama; ikisi senkron tutulur.
>
> Durum: **🟢 ONAYLANDI (v1)** — palet: lacivert+altın · imza: Hero tutar + altın ray.

---

## 1. Renk Paleti

Kimlik: **beyaz zemin · lacivert · altın** — "güvenilir esnaf / premium kasa" hissi.
Her renk bir işe yarar; dekoratif ton yok.

| Token adı | Hex | `AppColors` | Rol | Kullanım yeri |
|---|---|---|---|---|
| `color.surface` | `#FFFFFF` | `pageBg` / `cardBg` | Ana zemin | Sayfa + kart arka planı |
| `color.ink` | `#1B2A4A` | `primary` / `textPrimary` | Birincil metin + aksiyon | Başlıklar, ana butonlar, sidebar |
| `color.accent` | `#C9A84C` | `gold` | **İmza vurgu** | Hero tutar altın rayı, aktif durum, kenarlık |
| `color.muted` | `#8898AA` | `textMuted` | İkincil / pasif | Yardımcı metin, etiket |
| `color.positive` | `#1B7A45` | `success` / `cash` | Olumlu / kazanç / nakit | Net kazanç, başarı, nakit ödeme |
| `color.danger` | `#C0392B` | `danger` | Uyarı / silme / borç | Borç bakiyesi, silme, hata |

**Destek tonları (paletin içinden, yeni renk değil):**
`primaryDark #0F1D35` · `goldBorder #D4B86A` (kenarlık) · `goldBg #FDF6E3` (tablo başlığı) ·
`textSecondary #4A5568`.
**Ödeme semantiği:** nakit `#1B7A45` · POS `#1B6A9A` · açık hesap `#C9A84C` · parçalı `#6B4FA0`.

**Bölücü / hairline (KARAR v1.2 — altın ekonomisi geçişi):** `AppColors.divider` artık **nötr**tir,
altın DEĞİL → `#EAECF0` (= `textMuted` ~%18 beyaz üstü, paletten türetilmiş hairline; yeni renk değil).
Gerekçe: divider hem tema varsayılanı hem ~10 yerde satır ayracı; altın-tint (#EADEBB) iken her satırda
altın tekrarlıyor ve §5 imzasını sulandırıyordu. Satır ayraçları, liste/tablo bölücüleri ve grafik
grid/ekseni bu nötr hairline'ı kullanır (grid `~0.15`, eksen `~0.25` alfa). **Altın çizgi yoktur** —
kasıtlı altın yalnızca kart kenarlığı (`goldBorder #D4B86A`), tablo başlığı (`goldBg`) ve aktif/seçili
durumdadır; hiçbir bölücü/ayraç altın olamaz.

**Kontrast notu:** ink/surface ve danger/surface çiftleri WCAG AA (≥ 4.5:1) sağlar.
Altın metin **asla** beyaz üzerine gövde metni olarak kullanılmaz (kontrast düşük) —
altın yalnızca vurgu, kenarlık ve ray olarak.

**Seri renk paleti (kategorik — çok-serili grafikler için, KARAR v1.4):** Çok yıllı/çok
serili grafiklerde her seriyi ayırmak için 6 ayrık renk; hepsi **mevcut paletten** alınır
(yeni hex YOK). Sıra, yıl indeksine göre atanır → `renk = liste[(yıl − 2021) % 6]`:
1. `primary #1B2A4A` (lacivert) · 2. `success #1B7A45` (yeşil) · 3. `pos #1B6A9A` (çelik mavi) ·
4. `splitPayment #6B4FA0` (mor) · 5. `gold #C9A84C` (altın) · 6. `danger #C0392B` (kiremit).
**Kural:** Bu bağlamda renkler **kategorik ayraçtır**, semantik/imza rolü **taşımaz** —
buradaki altın imza rayı DEĞİL, kırmızı "borç/hata" DEĞİL; yalnızca "hangi yıl" bilgisidir.
Sadece grafik çizgisi + lejant/renk noktası olarak; **dolgu (area fill) yok** (çizgiler üst
üste binince çamurlaşmasın). İmza (§4) etkilenmez: grafik çizgisi asla altın ray değildir.

---

## 2. Tipografi Rolleri

Başlık **Manrope** (geometrik, premium) · Gövde + **tüm rakamlar Inter** (tabular figür →
para tutarları hizalı). Boyut değil **rol** düşünülür.

| Rol | Font | Boyut / ağırlık | Nerede |
|---|---|---|---|
| `type.display` | Manrope | 28–40 / w700–w800, `height 1.1`, `spacing -0.5` | Ekran başlığı, **hero tutar** |
| `type.body` | Inter | 13–15 / w400, `height 1.45` | Liste satırı, form etiketi, genel metin |
| `type.utility` | Inter | 11–13 / w500–w600 | Etiket, rozet, tablo başlığı, buton |

**Sayı kuralı:** Tüm para/stok/adet rakamları **tabular figür** (Inter) ile hizalanır.
Hero tutar `type.display` ile büyütülür; küçük tutarlar `type.body` tabular.

---

## 3. Spacing & Radius

Tek ölçek (`AppSizes`). Ara değer icat etme.

- **Spacing (4'lük grid):** `4 · 6 · 8 · 12 · 16 · 20 · 24 · 32` → `space4 … space32`.
  Sayfa kenarı `pagePadding 20`, kart içi `cardPadding 16`, bölüm aralığı `sectionGap 16`.
  İstisna: `space2` (2px) yalnızca **pill/rozet iç dikey dolgusu** için ayrılmıştır; layout
  aralığı olarak kullanılmaz.
- **Radius:** `radiusSm 8` · `radiusMd 12` · `radiusLg 16` · `radiusXl 20` · `radiusPill 999`.
  Kart 16, buton/input 12, chip pill.
- **Dokunma hedefi (mobil):** minimum **48×48 px**.
- **Gölge:** lacivert-tint yumuşak (`AppSizes.cardShadow` / `elevatedShadow`) — düz görünümden çıkış, ağır drop-shadow yok.
- **Yoğunluk:** masaüstü tablolar sıkı; mobil kartlar ferah.

---

## 4. İmza Tasarım Öğesi (Signature) — **Hero Tutar + Altın Ray**

> Uygulamayı "şablon Flutter dashboard"dan ayıran TEK cesur öğe. Cesaret buraya
> yatırılır; geri kalan her şey sakin durur ki bu öğe parlasın.

- **Öğe nedir:** Bir ekranın **en önemli para tutarı**, kahraman olarak gösterilir:
  iri `type.display` (Manrope/Inter tabular) rakam + **hemen altında ince altın aksan
  rayı** (`color.accent`, ~3px, rakam genişliğinin ~%40'ı kadar, `radiusPill`).
- **Nerede görünür (ekran başına TEK hero):**
  - Satış ekranı → sepet **GENEL TOPLAM**
  - Satış grafikleri → **bugünkü toplam ciro (₺)** hero (en baskın para metriği). Adet
    sayısı ("X adet") hero OLAMAZ — kural 3 gereği hero daima para formatıdır.
  - Raporlar (GÜNLÜK / TARİHSEL) → **Toplam Ciro (₺)** hero (KARAR v1.3 — ONAYLANDI). Günün/
    aralığın manşet metriği; altın ray (para metriği, ray altın). Diğer stat kartları (Nakit/POS/
    Açık Hesap/Kâr/Adet/Maliyet/Alınan Ödeme) **sakin destek** olur — `highlight` tekilleşir, Kâr
    artık ikinci kahraman DEĞİL (yalnız `success/danger` metin semantiği taşır, hero büyüklüğünde değil).
  - Raporlar (ÜRÜN) → **hero YOK** (KARAR v1.3). Tarama/analiz ekranı (stok listesi gibi); imzası
    zaten min/maks/ort birim fiyat + toplam istatistik chip'leridir. Tek para metriği hero'ya yükseltilmez.
  - Stok listesi → **hero YOK** (KARAR v1.1). Bu bir tarama/çalışma ekranı; tek cesur öğe
    **kritik stok sinyali**dir (bkz. §5). Toplam stok değeri özeti "Ürün Özet" dialog'unda kalır.
  - Etiket (raf etiketi A4 yazdırma) → **ekran hero'su YOK** (KARAR v1.10). Uygulama ekranı bir
    araç/çalışma ekranıdır (stok listesi emsali). ANCAK basılan **her etiketin kendi hero'su = FİYAT**
    (kullanıcı kararı): fiyat, etiketin en baskın/en iri öğesidir (referans `raf_etiketi.jpg` — iri
    bold "250 TL"). Bu bir **baskı-çıktısı hero'sudur, app hero'su DEĞİL** → **altın ray YOK** (24
    etikette ray = "altın duvar" + baskı çıktısı mağaza markasını taşır, app krom'unu değil). Fiyat =
    iri bold; barkod okunaklılığı için etiket dili siyah/beyaz baskıdır. Bkz. §5 "Etiket ekranı".
  - Müşteri kayıtları (DETAY) → müşteri **BAKİYE** (= Kalan Borç). Borç ise `danger`,
    alacak/sıfır ise `positive`; **ray rengi tutara göre** (altın değil — imza istisnası),
    hero büyüklük korunur. Diğer 3 özet (Toplam Satış · Toplam Borç · Ödeme) sakin destek.
  - Müşteri kayıtları (LİSTE) → **Toplam Kalan Borç** hero (KARAR v1.1 — **ONAYLANDI**). Agregat
    borç esnafın manşet metriği; ray `danger` (net alacak fazlası varsa `positive`). Liste
    tablosu/kartlar sakin destek. Detay ekranındaki bakiye hero'su ile aynı dil (borç/alacak).
  - Kasa (gelir-gider defteri) → **birikimli yıl kasası (₺)** hero (KARAR v1.9 — **ONAYLANDI**).
    = açılış geliri + o güne kadar Nakit+POS gelir (yıl bazlı, `fiscal_year`). Para metriği →
    **ray altın** (imza korunur). Seçili günün Nakit+POS kırılımı + açılış = **sakin destek**
    (`type.body` tabular, ray YOK). Gider hero'ya karışmaz — tek hero kuralı (§4.1).
- **Nasıl uygulanır (kural):**
  1. Ekran başına **yalnızca bir** hero tutar. İkinci bir tutarı bu boyutta gösterme.
  2. Altın ray **sadece** hero tutarın altında belirir — başka yerde süs çizgisi yok.
  3. Hero tutar daima **tabular figür** ve `formatters.dart` para formatı.
- **Nerede GÖRÜNMEZ (sınır):** Liste satırlarındaki tutarlar, tablo hücreleri, ikincil
  toplamlar hero DEĞİLDİR (normal `type.body` tabular). Altın ray; kenarlık, bölücü
  veya dekor olarak ekrana serpiştirilmez.

---

## 5. Bileşen Notları

- **Buton:** ana aksiyon `color.ink` zemin + beyaz metin, `buttonRadius 12`. İkincil =
  altın kenarlıklı outline.
- **Ödeme türü butonu:** varsayılan (seçili değil) zemin **nötr beyaz** (`color.surface`),
  ince kenarlık = **`goldBorder`** (v1.9.1 netleştirme — "ince kart kenarlığı" izniyle tutarlı;
  onaylı satış ekranı `_PaymentTypeButton` uygulaması referanstır. Yasak olan **zemin** altınıdır,
  kenarlık değil; disabled durumda kenarlık nötr `divider`). Tür kimliği **sol renk şeridi + ikon/etiket** ile taşınır
  (nakit `#1B7A45` · POS `#1B6A9A` · açık hesap `#C9A84C` · parçalı `#6B4FA0`).
  **Seçili durum:** o türün renginde dolgu/kenarlık. Açık hesap seçili değilken
  etiket/ikon rengi **`color.ink`** (altın metin açık zemine yazılmaz, §1). `goldBg`
  zemin ödeme butonlarında kullanılmaz — dört butonu "altın duvar"a çevirir.
- **Altın ekonomisi (imza koruması, §4):** Altın aynı ekranda dekor olarak yığılmaz.
  İzin verilen: hero ray, aktif/seçili durum, tablo başlığı `goldBg`, ince kart
  kenarlığı. Yasak: her input + her buton + her bölücüde altın → imza sulandırılır,
  geri kalan sakin durmalı ki hero rayı parlasın.
- **Kart:** `AppSizes.cardDecoration()` — beyaz zemin, altın kenarlık, yumuşak gölge, radius 16.
- **Hero yüzeyi (istisna):** Hero tutar kutusu bilinçli **KENARLIKSIZ** — yalnız beyaz zemin
  + yumuşak `cardShadow` + `radiusLg`. Ekranın tek altın/semantik vurgusu **ray** olmalı;
  altın kenarlık eklemek hero'yu generic kartla aynılaştırır ve §4 imzasını sulandırır.
  (Dashboard hero bandı ve müşteri hero'ları bu istisnayı kullanır.)
- **Tablo başlığı:** `goldBg #FDF6E3` zemin, `type.utility`, hover `tableRowHover`.
- **Rozet/pill:** ödeme türü renkleri (§1), `chipRadius` pill.
- **Aktif durum:** sidebar/sekme seçili = altın metin (`sidebarTextActive`) — bu, imza
  rayının "aktiflik" diliyle tutarlıdır ama ray DEĞİLDİR (ray yalnızca hero tutara ait).
- **Çoklu-yıl karşılaştırma grafiği (dashboard, KARAR v1.4):** Günlük satış grafiğinin
  **altında**, aynı eksen üzerinde Oca–Ara aylık ciro; 2021 → içinde bulunulan yıl her biri
  ayrı seri (seri renk paleti §1, `renk = liste[(yıl − 2021) % 6]`). Yıllar **aç/kapa toggle
  chip** ile seçilir (renk noktası + yıl etiketi); birden fazlası açık kalabildiği için bu
  **radyo değil çoklu-seçimdir**. Bu grafik **HERO değildir** — dashboard'un tek hero'su
  bugünkü cirodur (§4); altın ray yok. Çizgiler 2px, dolgusuz; ızgara/eksen nötr hairline
  (§1, grid ~0.15 / eksen ~0.25 alfa). Y ekseni tabular para; X ekseni Türkçe ay kısaltmaları.
- **Nav öğesi — çift-bölge "yeni sekmede aç" (masaüstü sidebar, KARAR v1.5):** Masaüstü
  sidebar nav öğeleri (`_SidebarTile`) iki **bitişik tıklama bölgesine** ayrılır ama **tek
  buton gibi** görünür (0px gap; ortak zemin, ortak hover/seçili görünümü, ortak radius).
  - **Sol ~4/5:** öğeyi **aynı sekmede** açar (mevcut SPA navigasyon).
  - **Sağ ~1/5:** öğeyi **yeni sekmede** açar (web'de `_blank`).
  - **Altın ekonomisi (kritik):** Sağ 1/5 bölgesinin altını **kalıcı DEĞİLdir** — yoksa
    5 buton = "altın duvar" ve §4 imza rayı + seçili-durum altını sulanır (bkz. "Altın
    ekonomisi" maddesi). Kural:
    - **Dinlenme:** sağ bölge sakin → soluk **↗ ikonu** (`Icons.open_in_new`), `sidebarText`
      renginde, düşük opaklık. Altın YOK. **Dikey ayraç YOK** (v1.5.1 — `divider` hairline açık
      zemin için; lacivert sidebar üstünde beyaz çizgi gibi duruyordu ve "tek buton" hissini
      bozuyordu; iki bölgeyi ↗ ikonu + hover altını zaten ayırt ettirir).
    - **Hover (yalnız o öğe):** sağ 1/5 zemini altına döner (`gold`/`goldLight` düşük-orta
      alfa fill) + ↗ ikonu `sidebarTextActive` (altın). Sol 4/5 mevcut hover davranışını korur.
      Tooltip: "Yeni sekmede aç".
    - Böylece altın yalnız **etkileşimde** (hover = geçici aktif durum) parlar; bu altının
      izinli rolüyle tutarlıdır, dinlenmedeki sidebar sakin kalır.
  - **Seçili öğe:** mevcut sol altın şerit + altın metin **korunur**; sağ bölge yine yalnız
    hover'da altınlanır (seçiliyken de kalıcı altın sağ şerit yok).
  - **Daraltılmış sidebar (56px, ikon-only):** çift-bölge **kapalı** → tüm öğe = aynı sekme.
    Yeni-sekme bölgesi yalnız **genişletilmiş** modda görünür (1/5 ≈ 9px tıklanamaz olurdu).
  - **Mobil:** etkilenmez (drawer + bottom nav; yeni-sekme bölgesi yoktur).
- **En Çok Satanlar sekmesi (Raporlar 4. sekme, KARAR v1.6):** Raporlar tasarım dilinin
  uzantısı; **tarama/analiz** ekranı → **HERO YOK** (Ürün raporu ile aynı, §4 v1.3 gerekçesi).
  - **Kolonlar:** Sıra `#` · Ürün (+ barkod) · **Birim Fiyat** (ürünün güncel `price1`'i) ·
    **Adet** (seçili aralıkta satılan toplam miktar) · **Son Satış Tarihi**. *(Toplam Gelir
    kolonu YOK — adet × fiyat türevi, gereksiz.)*
  - **Sıralama:** Adet **azalan** (en çok satandan en aza).
  - **Filtreler:** (1) **Tarih aralığı** — default **2026-01-01 → bugün** (Tarihsel Rapor tarih
    seçici deseni). (2) **Min. fiyat** — default **50 TL**, **elle düzenlenebilir** alan; yalnız
    `price1 ≥ girilen değer` ürünler listelenir (fiyat sınıfına göre karşılaştırma).
  - **Görünüm:** web `cardDecoration()` + `goldBg` başlık tablosu, tüm rakamlar Inter tabular,
    sayısal kolonlar sağa dayalı; mobil kart listesi (diğer rapor sekmelerinin deseni). Yeni
    renk/altın yok — mevcut rapor token'ları.
- **Sepet kalıcı-fiyat kontrolü + satır-içi başarı bildirimi (Satış ekranı, KARAR v1.6):**
  Sepet satırında birim fiyat **elle düzenlenebilir** (tabular, `formatters` para). Fiyatın
  yanında **çıplak radyo butonu** (KARAR v1.6.1 — kullanıcı görünür "Fiyat1 yap" etiketini
  kaldırdı; radyo doğrudan **fiyat hanesinin yanında** durur). Basılınca ürünün **kalıcı satış
  fiyatı** (`products.price1`) DB'de güncellenir.
  - **Kaza koruması:** etiket kaldırıldığı için keşfedilebilirlik + kaza azaltımı **hover
    tooltip "Fiyat1 yap"** ile taşınır (görünür etiket değil, ipucu); yalnız `productId != null`
    satırlarda görünür (serbest kalem hariç). Kalıcı fiyat değişimi geri alınamaz — radyo
    işaretlenince hemen yeşil onay bildirimi verilir (aşağıda).
  - **Onay bildirimi:** aksiyondan hemen sonra o satırda **yeşil** (`color.positive #1B7A45`)
    kısa süreli pill "Fiyat güncellendi" (`radiusPill`, `type.utility`). Bu, success semantiğinin
    (§1) satır-içi geri bildirim kullanımıdır; **altın DEĞİL**, imza rayıyla karışmaz. Hem web
    (satır içi) hem mobil (adet/fiyat dialog'u içinde) aynı dil.
- **Sepet satır-içi muhtelif ekleme (Satış ekranı, masaüstü, KARAR v1.6.2):** Masaüstü sepette
  ayrı **"+Muhtelif" footer butonu KALDIRILDI**; yerine ekleme, tablonun **sıradaki boş satırında**
  (son ürünün altındaki satır; sepet boşsa 1. satır) yapılır:
  - **Toplanmış (varsayılan):** o satırda **Ürün sütununun en solunda** sade bir **"+" ikonu**
    (`Icons.add`, `color.ink`/`textSecondary`, tooltip "Muhtelif ürün ekle"). Diğer sütunlar boş.
  - **Açık (+'ya basınca):** aynı satır **kolon hizasını koruyarak** düzenlenir → **Ürün adı** alanı
    Ürün sütunu altında (autofocus), **Fiyat** alanı **Fiyat sütunu altında** (İskonto/Miktar
    sütunları boş); Tutar sütununda onay (✓), Sil sütununda vazgeç (✕). Enter/✓ → `addMiscItem`
    (ad = not, fiyat, adet 1) → kalem normal satır olur, "+" satırı **bir alt satıra iner** ve
    toplanmış hâle döner.
  - **"+" yalnız TEK satırda** (sıradaki boş satır) bulunur; ürün eklendikçe aşağı kayar.
  - Yeni renk/altın yok; alanlar tabular + `formatters`. Kolon genişlikleri mevcut tablo ölçüleri
    (Ürün esnek · İskonto 96 · Miktar 116 · Fiyat 160 · Tutar 88 · Sil 40) ile birebir hizalı.
  - **Mobil** bu karardan etkilenmez (mobil footer "Muhtelif" butonu korunur — kullanıcı "webde" dedi).
- **Kritik stok durumu (stok listesi imzası, §4):** Stok miktarı, durumuna göre üç dilde gösterilir:
  **tükendi** (stok ≤ 0) en belirgin → `danger` dolu rozet/pill (kırmızı zemin + beyaz metin);
  **kritik** (0 < stok ≤ kritik eşik) → `danger` metin/ince rozet; **normal** (stok > eşik) →
  nötr `textPrimary` tabular, vurgu yok. Satır bazında çok hafif `danger` tint opsiyonel; tablo
  "kırmızı duvar"a dönmemeli — yalnızca riskli satırlar konuşur, kalan sakin durur. Altın bu
  durumda KULLANILMAZ (kritik sinyal semantik kırmızıdır, imza altın rayı yalnız hero'ya ait).

- **Hafta sonu gün işaretçileri (günlük satış grafiği, KARAR v1.7):** Günlük satış çizgi grafiğinde (`_SatisLineChart`) o güne denk gelen **dikey düşük-alfa bant** çizilir (fl_chart `rangeAnnotations.verticalRangeAnnotations`): **Cumartesi = altın** (`gold`, ~0.09 alfa), **Pazar = kızıl** (`danger`, ~0.09 alfa). Bantlar **kategorik/bilgi amaçlıdır** (KARAR v1.4 emsali) — §4 imza rayı DEĞİL, "kötü gün" semantiği DEĞİL; yalnız "bu gün hafta sonu" bilgisidir. Kural: solid dolgu YOK (faint wash, alfa ≤ 0.10), çizgi lacivert kalır, bu kartta başka altın kullanılmaz (grafik zaten HERO değildir). Bant yalnız bu grafikte; yıllık karşılaştırma grafiğine uygulanmaz.
- **Artımlı grafik yükleme (dashboard, KARAR v1.8):** Yıllık karşılaştırma grafiği gibi ağır sorgulu grafiklerde, veri beklenirken tam-alan loader ile alanı kapatmak yerine **grafik iskeleti** (ızgara + eksen + ay etiketleri, çizgisiz) ANINDA çizilir; sağ üst köşede küçük, göze batmayan yükleme ipucu (`textMuted` spinner + "Yükleniyor…") durur. Veri gelince çizgiler fl_chart varsayılan animasyonuyla içeri dolar. Yeni renk yok (nötr ızgara/eksen §1, ipucu textMuted). Algılanan gecikmeyi düşürür; imza/palet etkilenmez.
- **Kasa ekranı (gelir-gider defteri, KARAR v1.9):** Yerleşim = **hero-önderli tek kolon** (raporlar/müşteri diliyle tutarlı; iki-sütunlu "defter/spreadsheet" görünümü YASAK — AI-tipik gazete sütunu). Üstten aşağıya:
  - **Hero:** birikimli yıl kasası + altın ray (§4). Altında seçili günün Nakit+POS'u + açılış = sakin destek.
  - **Tarih seçici** (bugün default) + **yıl** göstergesi (yıl bazlı defter; 2027 sıfırdan).
  - **Gelir/Gider sekmeleri** (`SegmentedButton` veya sekme; ödeme türü butonu dili değil — bunlar kanal değil sekme).
  - **Gelir sekmesi:** gün-sonu değerleri **4 tabular alan** — Nakit · İş Bankası POS · Akbank POS · Garanti POS (POS tabanı = 3 bankanın toplamı). Kanal kimliği **ince sol renk şeridi/etiket** ile taşınır (nakit `success #1B7A45`, POS `pos #1B6A9A`, §1/§5 ödeme dili) — **dolu renk zemin YOK** (dört alanı renk duvarına çevirmez). Her kanalda **mutabakat rozeti/satırı:** sistem tabanı vs girilen → fark (`adjustment_amount`). Rozet **semantik** renk: +düzeltme (ek gelir) `success`/nötr, −düzeltme (iade) `danger`; `radiusPill`, `type.utility`. **Altın DEĞİL** — imza rayı yalnız hero'ya ait; rozet "Fiyat güncellendi" pill'iyle (KARAR v1.6) aynı satır-içi geri bildirim dili.
  - **Gider sekmesi:** kategori seçimi (`kasa_expense_categories`; Kira/Muhasebe/Muhtelif + "yeni kalem" ekleme) + tutar + not; gün içi **çok kalem** liste. Firma alanı **`/` autocomplete** → satış ekranı `_LiveProductSearchField` **OverlayPortal + CompositedTransformFollower** örüntüsünün birebir yeniden kullanımı (`companies.name`). Gider tutarları `danger` semantiği taşımaz (nötr tabular); yalnız net/negatif özet `danger`.
  - **Düzeltme satışını silme (KARAR v1.9.3):** Mutabakat düzeltme satışları (`is_adjustment=true`, `[KASA DÜZELTME]`) **normal satış listesinden** (raporlar → satış → "Satışı Sil") silinebilir. `SalesRepository.deleteSale`, satışı silmeden **önce** o satışa bağlı `kasa_reconciliations` kaydını (`sale_id` eşleşmesi) siler: (1) FK engeli kalkar → düzeltme satışı silinebilir, (2) o gün+kanal **"hiç mutabakat yapılmamış"** hâle döner (tekrar Kaydet & Mutabakat yapılınca sistem tabanından yeniden hesaplanır). Bu adım tüm silmelerde çalışır ama yalnız düzeltme satışlarında karşılığı olur (normal satışta eşleşen kayıt yoktur → zararsız). UI/token değişikliği yok; yalnız veri-bütünlüğü davranışı.
  - **Gider — kademeli açılım (progressive disclosure, KARAR v1.9.2):** Firma hanesi **başlangıçta gizlidir**; yalnızca bir **gider kalemi (kategori) seçildikten sonra** görünür olur (Kategori → Tutar → *[kalem seçilince belirir]* Firma → Not sırası). Amaç: boş/ilgisiz alanla formu kalabalıklaştırmamak; girişi doğal sırayla yönlendirmek. **Autocomplete ("akıllı klavye") birebir korunur** — alan belirdiğinde OverlayPortal canlı arama + `TextFieldTapRegion` odak davranışı aynen çalışır (yazdıkça öneri açılır, dokununca odak düşmeden seçer). Alanın belirmesi/gizlenmesi **ani** olabilir (dekoratif animasyon şart değil); yeni renk/token yok, yalnız görünürlük koşulu. Kalem seçimi geri alınırsa (null'a düşerse) Firma alanı yeniden gizlenir ve seçili firma temizlenir. **(KARAR v1.9.4 ile daraltıldı — Firma artık yalnız kategori = "Ürün Alımı" iken görünür; aşağıya bakınız.)**
  - **Firma yalnız "Ürün Alımı"nda + Firma Giderleri sekmesi (KARAR v1.9.4):**
    - **(a) Firma görünürlüğü:** Firma hanesi yalnızca seçili gider kalemi **`'Ürün Alımı'`** iken açılır (v1.9.2'nin "herhangi bir kalem" koşulunu daraltır). Başka kalemde (Kira/Muhasebe/Muhtelif…) Firma alanı **hiç render edilmez**; kategori `'Ürün Alımı'`dan başka bir değere/null'a düşerse `_firmaId` temizlenir. `'Ürün Alımı'` kategorisi `0013` migration ile seed'lenir (isim eşleşmesi tetikleyicidir). Autocomplete davranışı (§v1.9.2) aynen korunur.
    - **(b) Firma Giderleri sekmesi:** Kasa üst kontrolü **üç sekmeye** çıkar: **Gelir · Gider · Firma Giderleri**. Üçüncü sekme **yıl bazlıdır** (seçili `fiscal_year`; gün seçicisinden bağımsız) ve bir **rapor/analiz ekranıdır → HERO YOK** (raporlar diliyle tutarlı, §4 v1.3 gerekçesi; kasa hero'su ekranın üstünde kalır ama bu sekmenin kendi hero'su yoktur). İçerik: (1) üstte **sakin özet** "‹yıl› Yılı Toplam Ürün Alımı ₺X" — tabular, **altın ray YOK** (ikinci hero olmaz); (2) altında **firma listesi**: her firma bir kart, firma adı + o firmaya yıl içi ödenen **toplam** (tabular, sağa dayalı), açılınca o firmaya yapılan **her ödeme** satır satır **tarih · tutar**. Yalnız `direction='gider'` + `category='Ürün Alımı'` + `company_id` dolu kalemler; firmalar toplam tutara göre azalan sıralanır. Boş durum: "Bu yıl için ürün alımı kaydı yok." Renk/altın: yalnız `cardDecoration` + `goldBg` başlık; yeni renk yok, tüm rakamlar Inter tabular + `formatters`.
  - **Üç-sekme etiket kompaktlığı (KARAR v1.9.5 — QA #1/#2 düzeltmesi):** Kasa üst kontrolü (`SegmentedButton`) üç segmentle **taşmamalı**. Kural: (1) **Mobil (<650px):** üçüncü sekme etiketi **"Firmalar"** (kısa), segment **ikonları gizli** (`showSelectedIcon:false` + `Icon` yok/gizli), böylece Gelir·Gider·Firmalar 360px'e kesilmeden sığar. (2) **Masaüstü (≥650px):** üçüncü etiket **"Firma Giderleri"** ama **tek satır** (`maxLines:1`, `softWrap:false`/`overflow` ile sarma yok) — segment iki satıra kırılmaz. Sekme **fonksiyonu/sırası değişmez** (Gelir·Gider·Firma Giderleri); yalnız etiket dili genişliğe uyarlanır. Yeni renk/token yok.
  - **Açılış bakiyesi:** mütevazı alan/bölüm (hero değil); yıl bazlı `opening_income`/`opening_expense`.
  - **Renkler:** Nakit `success` · POS `pos` · negatif düzeltme/iade `danger` — **yeni renk/altın YOK**. Altın yalnız hero ray + kart kenarlığı + tablo başlığı (`goldBg`) + aktif sekme (§1 altın ekonomisi). Tüm rakamlar Inter tabular + `formatters`.
  - **Nav:** `/kasa` rotası + sidebar/drawer/bottom-nav öğesi (mevcut nav diline uyar; masaüstü sidebar çift-bölge KARAR v1.5 kuralı geçerli).
- **Etiket ekranı — raf etiketi A4 yazdırma (KARAR v1.10):** Ürün etiketlerini A4 kağıda basmak için
  bir **araç/çalışma ekranı** (stok listesi dili; **ekran hero'su YOK**, §4). İki kavram ayrıdır:
  **(A) uygulama krom'u** design-tokens paletine uyar; **(B) basılan etiket çıktısı** referans
  `raf_etiketi.jpg` estetiğine (siyah/beyaz + mağaza logosu) uyar — ikisi karışmaz.
  - **Ekran yerleşimi (A):** iki işlevsel bölge (satış ekranı sepet+ödeme deseni gibi; gazete sütunu
    DEĞİL): **sol** = 24 haneli barkod giriş sütunu, **sağ** = canlı A4 önizleme. Mobil: tek kolon
    (giriş üstte, önizleme "Önizle"/altta).
  - **24-hane barkod akışı:** Haneler `1..24` numaralı, tek satır. Barkod okutulup **Enter** →
    o hane dolar (`products` lookup ile ürün adı + `price1` çözülür), imleç **otomatik bir alt haneye**
    geçer (satış ekranı `_onBarcodeSubmitted` deseninin birebir tekrarı). **Aktif hane** = aktif durum
    altını (izinli: ince sol altın şerit / ink kenarlık, §5 altın ekonomisi). Çözülemeyen/boş barkod →
    `danger` ince uyarı; satır ✕ ile hane temizlenir. Tüm barkod/fiyat Inter tabular.
  - **A4 baskı geometrisi (B):** **3 sütun × 8 satır = 24 etiket** ızgarası. Kenar boşlukları
    **olabildiğince küçük** (`@page { size:A4 portrait; margin:~5mm }`); etiketler arası ince nötr
    hairline kesim kılavuzu (altın YOK — sayfa "altın duvar" olmaz). Yaklaşık hücre: ~66mm × ~36mm.
  - **Etiket-içi yerleşim (B, referans jpg sırası):**
    1. **Üst bant:** SOL'da **logo yuvası** (ayrılmış alan) · sağında/baskın **FİYAT hero** (iri bold,
       etiketin en büyük öğesi — `price1` + " TL", tabular). Logo yoksa **standart ikon fallback**
       (`Icons.store`/`Icons.storefront`, `color.ink`, aynı yuva boyutu).
    2. **Ürün adı** (fiyatın altında, tek/iki satır, taşarsa kısalt — okunur ama fiyatı ezmez).
    3. **Barkod çizgileri** (barkod no'dan üretilir — Code128/EAN; net siyah, beyaz sessiz alan).
    4. **En alt:** SOL/orta **barkod no** (tabular rakam) · SAĞ-ALT köşe **oluşturma tarihi**
       (`formatters` kısa tarih, minik `type.utility`, köşeye sığar).
  - **Logo pixel kararı (benim):** logo yuvası ~ **14mm × 10mm** (@96dpi ≈ 53×38px); dar 3-sütun
    hücreye sığar, fiyatı/adı ezmez. Standart ikon fallback aynı yuvada, `color.ink`.
  - **Aksiyonlar:** **Yazdır** (ana aksiyon, `color.ink` zemin — `sale_print_web.dart` deseni: HTML
    blob → yeni pencere → `window.print()`, yalnız web `kIsWeb` guard) + **PDF Üret** (ikincil, altın
    kenarlıklı outline). Mobil/native'de yazdırma no-op (satış yazdırma emsali).
  - **Renk/tipografi:** app krom'u stok listesi token dili (Manrope başlık, Inter tabular, `cardDecoration`,
    `goldBg` başlık); **yeni renk/altın YOK**. Baskı çıktısı siyah/beyaz + mağaza logosu (app altını
    baskıya taşınmaz). Etiket hero'su = fiyat (iri bold), **altın ray YOK** (§4).
  - **Nav:** `/etiket` rotası + sidebar/drawer/bottom-nav "Etiket" öğesi (mevcut nav dili; masaüstü
    çift-bölge KARAR v1.5 geçerli).
  - **İki sekme + kayıtlı PDF'ler (KARAR v1.11):** Etiket ekranı üst kontrolü **iki sekme** olur
    (`SegmentedButton`, kasa sekme dili; ödeme-türü butonu değil): **"Yeni Etiket"** · **"Kayıtlı
    Dosyalar"**. Sekme fonksiyonu ayraç, kanal değil; aktif sekme token dili (§1 altın ekonomisi),
    yeni renk yok.
    - **Sekme 1 (Yeni Etiket):** mevcut 24-hane + A4 önizleme + **Yazdır** (web `window.print`,
      korunur). Eski "PDF Üret" → **PDF Kaydet**: **dosya adı** soran dialog → gerçek PDF (`pdf` paketi,
      A4 3×8 = 24 etiket, KARAR v1.10 etiket-içi düzeni birebir: logo + FİYAT hero + Code128 + barkod
      no + tarih; baskı siyah/beyaz) → **Supabase Storage**'a yüklenir (`etiket_pdfleri` bucket'ı). Her
      platformda çalışır (native Android dahil — yerel cihaz kaydı YOK, yalnız Storage).
    - **Sekme 2 (Kayıtlı Dosyalar):** **ekran hero'su YOK** (tarama/liste; stok listesi/rapor emsali).
      Storage'daki PDF'ler listelenir (kart/tablo: ad · oluşturma tarihi · boyut, Inter tabular). Her
      satırda: **Aç/İndir** (imzalı URL → web yeni sekmede aç) · **Yazdır** (web: yeni sekmede aç →
      `window.print`) · **Sil** (`danger`, onay dialog'u). **Silme = Storage'dan da siler**
      (`storage.remove([path])`) — program'dan silinen dosya Storage'da kalmaz (kullanıcı kararı). Boş
      durum: "Kayıtlı etiket dosyası yok." `cardDecoration` + `goldBg` başlık; yeni renk/altın yok.
    - **Depolama:** private bucket `etiket_pdfleri` + **imzalı URL** (`createSignedUrl`, aç/yazdır için).
      Bucket + RLS politikaları Supabase panelinden kurulur (anon key ile DDL yapılamaz; migration
      dosyası `supabase/migrations/` altında dokümante edilir, uygulama panelde). Erişim: `authenticated`
      rolü bu bucket'ta select/insert/delete.
  - **Etiket-içi düzen rötuşu + logo kalıcılığı (KARAR v1.12):** KARAR v1.10 etiket-içi yerleşimi üç noktada güncellenir (önizleme = HTML yazdırma = PDF, üçü BİREBİR aynı):
    1. **Ürün adı = ORTALI** (önce sola dayalıydı) — hücre genişliğine ortalanır.
    2. **Fiyat = logodan sonra kalan alanda ORTALI** (önce sağa dayalıydı). Üst bant Row'unda logo yuvası solda sabit kalır; fiyat, logodan sonraki kalan genişliğe (Expanded alanı) ortalanır. Fiyat yine etiketin hero'su (iri bold, **altın ray YOK**).
    3. **Barkod çizgi yüksekliği = önceki değerin 2/3'ü** (3x→2x). Referans ölçüler: önizleme 30→20px, PDF 24→16pt, HTML 9mm→6mm.
  - **Logo RENKLİ:** Yüklenen mağaza logosu **kendi renkleriyle** basılır (siyah/beyaz baskı kuralının bilinçli istisnası; logo mağaza markasını taşır). Metin/barkod yine siyah/beyaz. Fallback mağaza ikonu `color.ink` lacivert kalır.
  - **Logo kalıcılığı (Supabase Storage):** Logo artık yalnız `keepAlive` oturumda değil, **Supabase Storage'da** saklanır (mevcut `etiket_pdfleri` bucket'ı, ayrılmış `__store_logo.txt` anahtarı; `savedLabelFiles` listesinden filtrelenir). Ekran açılışında geri yüklenir → login/logout sonrası korunur. Logo değiştir = Storage'a yaz; Logo kaldır = Storage'dan sil. Yeni bucket/RLS gerekmez (authenticated insert/delete yeterli). Token/palet/imza etkilenmez.
  - **Etiket-içi boyut rötuşu + alt-satır kırpılma düzeltmesi (KARAR v1.13):** KARAR v1.10/v1.12 etiket-içi
    geometrisi beş oranla güncellenir (önizleme = HTML yazdırma = PDF, üçü BİREBİR aynı; yeni renk/palet/imza
    YOK — yalnız baskı geometrisi):
    1. **Logo yuvası ×1.3** — önizleme 53×38→**69×49**px, HTML 14×10→**18×13**mm, PDF 40×27→**52×35**pt.
    2. **Fiyat (etiket hero'su, altın ray YOK) ×1.3** — önizleme 34→**44**, HTML 30→**39**pt, PDF 22→**28.6**pt.
       Fiyat taşarsa `FittedBox scaleDown` ile hücreye küçülür, **asla kırpılmaz**.
    3. **Ürün adı ×1.25** — önizleme 10→**12.5**, HTML 8→**10**pt, PDF 7→**8.75**pt (ortalı, 2 satır + ellipsis korunur).
    4. **Barkod numarası yazısı ×2** — önizleme 8→**16**, HTML 7→**14**pt, PDF 6→**12**pt (tabular).
    5. **Barkod çizgi genişliği = %80 ortalı** (%10 boşluk + %80 barkod + %10 boşluk) — önizleme/PDF
       `Center + FractionallySizedBox(widthFactor: 0.8)` (yatay widthFactor güvenli; dikey heightFactor
       sonsuz-yükseklik verdiği için kullanılmaz), HTML `.bc { width:80%; margin:0 auto }`.
    - **🔴 Kırpılma düzeltmesi (bug):** Sabit yükseklikli hücrede (HTML `~36mm` + `overflow:hidden`; önizleme/PDF
      sabit tuval) `spaceBetween` dizilimi, öğelerin min toplam yüksekliği hücreyi aşınca **en alt satırı
      (barkod no + tarih) kırpıyordu** — uzun ürün adlı ("bazı") etiketlerde. Yukarıdaki büyütmeler bunu
      kötüleştireceğinden düzeltme zorunlu: **barkod alanı esnek öğe olur** (`Expanded` / HTML `flex:1 1 auto;
      min-height:0`), sabit öğeler (ürün adı + alt satır `flex:0 0 auto`) yerini garantiler → **alt satır asla
      hücre dışına itilmez**; taşma olursa yalnız barkod çizgisi kısalır. Dikey padding hafif kısılır (önizleme
      6→4, HTML 2→1.5mm, PDF 3→2) yeni öğelere yer açmak için. Renk/palet/imza etkilenmez.
  - **"Geniş Logo" sekmesi — sabit tenteli 2×5 marka etiketi (KARAR v1.14):** Etiket ekranına
    **üçüncü bir sekme** eklenir; mevcut "dar logo" 3×8 raf etiketinden AYRI, iri tenteli marka
    etiketi (`genis_logo_etiketi.jpg` referansı). Mevcut etiketi değiştirmez — yan yana yaşar.
    - **Sekme yapısı:** Üst `SegmentedButton` **üç segment** olur: **Yeni Etiket · Geniş Logo ·
      Kayıtlı Dosyalar** (sıra: dar → geniş → dosyalar). Aktif sekme token dili (§1 altın ekonomisi),
      yeni renk yok. **Responsive (kasa KARAR v1.9.5 emsali):** mobilde (<650px) segment ikonları
      gizli + kısa etiketler ("Yeni" · "Geniş" · "Dosyalar") → üç segment 360px'e taşmadan sığar;
      masaüstünde tam etiket + ikon, tek satır (`maxLines:1, softWrap:false`).
    - **Grid:** **2 sütun × 5 satır = 10 etiket / A4 sayfa** (dar logonun 3×8=24'ünden az, daha iri
      hücre ≈ 100mm × 57mm). Ayrı sabitler (`kWideCols=2, kWideRows=5, kWideCount=10`) ve ayrı
      state (`labelWideSheetProvider`, 10 hane — mevcut 24-hane `labelSheetProvider`'a karışmaz;
      keepAlive, aynı desen). `@page{size:A4 portrait; margin:~5mm}`, hücreler arası ince nötr
      hairline kesim kılavuzu (altın YOK).
    - **Sabit marka görseli (logo yükleme YOK):** Turuncu tente/çadır + NiCE görseli **tek firma için
      HEP AYNI, sabit asset** → **`genis_logo_tente.png`** (kullanıcının verdiği dolu 2×5 A4 şablon
      `genis_logo_etiketi_sablon.png`'den kesilmiş **tek tente+NiCE karosu**; her etiket hücresinde bu
      karo üste yerleşir, fiyat/ad/barkod uygulamaca üzerine bindirilir). `pubspec.yaml` `assets:` listesinde.
      ⚠️ **Çözünürlük notu (izleme):** ilk karo ~220×90px → A4 ~100mm hücrede pikselleşebilir; görsel QA
      pikselleşme gösterirse yüksek-çöz. tek-tente PNG ile değiştirilir (baskı netliği). Bu sekmede **logo yükle/değiştir/kaldır
      aksiyonları YOKTUR** (dar logo sekmesindeki kullanıcı-logosu mantığı buraya taşınmaz). Görsel
      **renkli** basılır (turuncu tente kendi renginde) — bu, siyah/beyaz baskı kuralının **bilinçli
      istisnasıdır** (marka grafiği; KARAR v1.12 "logo renkli" emsali). Metin + barkod yine siyah.
      Marka grafiği **baskı çıktısına** aittir, app paletine karışmaz (`raf_etiketi` iki-kavram ayrımı).
    - **Etiket-içi düzen (üç çıktı BİREBİR: canlı önizleme = HTML yazdırma = PDF), üstten alta:**
      1. **Tente görseli** hücre genişliğini kaplar; üzerine **FİYAT** ortalı bindirilir (`Stack`/overlay —
         tentenin fiyat bandına). Fiyat = etiketin **hero'su**: iri bold tabular `${formatNumber} TL`,
         **altın ray YOK** (baskı hero'su, app hero'su değil — §4 korunur). Taşarsa `FittedBox scaleDown`,
         asla kırpılmaz. NiCE rozeti asset'in kendi parçasıdır (ayrı çizilmez).
      2. **Ürün adı** — tentenin altında beyaz gövdede, **ortalı**, en çok 2 satır (taşarsa ellipsis),
         `type.utility`/bold, siyah.
      3. **Code128 barkod** — ortalı, **%80 genişlik** (`Center + FractionallySizedBox(widthFactor:0.8)`
         / HTML `width:80%`, KARAR v1.13 deseni), altında **barkod no** (ortalı, tabular, siyah).
      4. **Sağ-alt köşe:** dosyanın **oluşturma/kayıt tarihi** (`formatShortDate`, minik `type.utility`,
         nötr gri) — kullanıcı isteği: her etiketin sağ-alt köşesine tarih.
    - **Barkod → ürün çözme akışı = mevcut mantık BİREBİR:** hane input'una barkod okut → **Enter**
      → `_resolveBarcode` (cache → fetchByBarcode → fetchAll) → `price1` çözülür, hane dolar, imleç
      **bir alt haneye** geçer; kamera ile sürekli tarama da desteklenir (satış/dar-logo deseni).
      Aktif hane = ince sol altın şerit + ink kenarlık (§5 altın ekonomisi); çözülemeyen = `danger`.
    - **Ekran krom'u:** **ekran hero'su YOK** (araç/çalışma ekranı, §4 v1.10 gerekçesi); stok listesi
      token dili (Manrope başlık, Inter tabular, `cardDecoration`, `goldBg` başlık). Masaüstü iki bölge
      (sol hane girişi · sağ A4 önizleme), mobil tek kolon — mevcut "Yeni Etiket" yerleşiminin 10-haneli
      uyarlaması. **Yazdır** (web `window.print`) + **PDF Kaydet** (Supabase Storage, mevcut
      `etiket_pdfleri` bucket'ı — geniş-logo PDF varyantı) aynı aksiyon dili. **Kayıtlı Dosyalar** sekmesi
      ortaktır (dar + geniş PDF'ler aynı listede). Yeni renk/altın YOK.
- **İşitsel geri bildirim — barkod okutma sesi (KARAR v1.14.1, uygulama geneli):** Her başarılı barkod
  okutmasında **kısa sentetik "bip"** sesi çalınır; barkod **çözülemezse** (ürün bulunamadı) farklı,
  **"danger" hissi veren** kısa uyarı sesi çalınır. **Kapsam = tüm uygulama:** satış ekranı
  (`_onBarcodeSubmitted` + kamera), etiket ekranı (dar + geniş logo, hane Enter + kamera sürekli tarama).
  - **Standart/sentetik:** ses dosyası (asset) YOK — ton **kod içinde üretilir** (öneri: kısa PCM/WAV
    byte'ları Dart'ta sentezle → tek codepath ile hem web hem Android'de çal; web-only `AudioContext`
    yerine cross-platform tercih edilir). Başarı = tek net yüksek bip; hata = daha alçak/sert kısa ton.
  - **Mevcut geri bildirimle katmanlı:** Ses, mevcut `HapticFeedback.lightImpact()` (titreşim) ve
    satır-içi yeşil "çözüldü" / `danger` "bulunamadı" görsel bildirimini **değiştirmez, tamamlar**.
    Ortak `playScanBeep(success)` yardımcısı her okutma sonucundan çağrılır. Görsel token/palet/imza
    etkilenmez (ses görsel bir öğe değildir; buraya yalnız tutarlılık kaydı olarak yazılır).
  - **Geniş Logo baskı geometrisi + etiket-içi hizalama (KARAR v1.14.2 — kullanıcı ölçüleri):** Geniş Logo
    etiketinin fiziksel/baskı ölçüleri kesinleşti. Önizleme = HTML = PDF üçü BİREBİR aynı; yeni renk/palet/imza
    YOK (fiyat hero, altın ray YOK korunur).
    - **Sayfa geometrisi (kesin mm):** A4 dikey 210×297mm. Etiket hücresi **94mm genişlik × 55mm yükseklik**.
      2 sütun = 188mm · 5 satır = 275mm. **Boşluklar eşit ve simetrik:** sol=sağ=**11mm**, üst=alt=**11mm**
      → `(210−188)/2 = 11`, `(297−275)/2 = 11`. 10 etiket A4'e tam ortalanır. HTML `@page{size:A4 portrait;
      margin:11mm}` + hücre `94mm×55mm`; PDF `PdfPageFormat.a4` + `margin:11mm` + hücre eşit dağılım; önizleme
      tuvali aynı oranı korur (1mm≈3.78px @96dpi).
    - **Asset = TAM tek-hücre figürü:** Marka görseli yalnız tente üstü DEĞİL, **tam dükkan figürü** olmalı:
      turuncu tente + NiCE rozeti + altındaki **beyaz gövde + sol/sağ turuncu yan çizgiler + alt çizgi**.
      Kaynak: kullanıcının `genis_logo_etiketi_sablon.png` dolu 2×5 şablonundan **tek tam hücre** yüksek
      çözünürlükte kırpılır (dashed kesim kılavuzları hariç). Figür hücreyi (94×55 oranı) dolduracak biçimde
      yerleşir; tüm etiket-içeriği bu figürün **sınırları içinde** kalır.
    - **Fiyat:** Tentenin **açık turuncu (iç) dikdörtgeninin tam merkezine** — yatay VE dikey ortalı. **Kalın**
      (w800) siyah tabular; taşarsa `FittedBox scaleDown`. Fiyat = etiket hero'su, **altın ray YOK**.
    - **Ürün adı + barkod genişliği:** NiCE yazısının/tentenin altındaki gövdede; **sol ve sağdaki turuncu yan
      çizgilerin dışına TAŞMAZ** (genişlik gövdenin iç payına kısıtlı) ve **tam ortalı**. Ürün adı ortalı, en
      çok 2 satır + ellipsis.
    - **Barkod çizgi yüksekliği:** mevcut değerin **1/2'sine** indirilir (yarı yükseklik); yatayda yine gövde
      iç genişliğinde, ortalı.
    - **Alt satır:** **barkod no SOLDA · tarih SAĞDA** (önceki "no ortalı + tarih sağ-alt" düzeni değişir).
      Alt satır figürün **alt çizgisinin altına TAŞMAZ** (gövde içinde kalır). `formatShortDate`, minik tabular.
  - **Ürün adı dikey konumu (KARAR v1.14.3 — kullanıcı isteği):** Geniş Logo etiketinde ürün adı,
    mevcut konumundan **1.5 harf yüksekliği kadar AŞAĞI** taşınır (tentenin altına fazla yapışıktı).
    - **Ölçü kuralı:** kaydırma = **1.5 × ürün adı font boyutu**, her çıktının kendi biriminde
      (önizleme px · HTML pt · PDF pt) → üç çıktı BİREBİR aynı görünür.
    - **Kapsam (kritik):** Yalnız **ürün adı** iner; **barkod çizgileri ve alt satır (barkod no + tarih)
      YERİNDE KALIR**. Gövdenin tamamı kaydırılmaz — v1.14.2'nin "alt satır figürün alt çizgisinin
      altına TAŞMAZ" kuralı bağlayıcıdır; hepsini kaydırmak alt satırı figür dışına iterdi.
      Uygulama: ürün adı, gövdenin üst esnek alanı içinde üstten boşlukla aşağı itilir; taşma
      riskinde ad yine 2 satır + ellipsis ile kısalır (barkodun alanını yemez).
    - Yeni renk/palet/imza YOK — yalnız dikey hizalama. Fiyat hero + altın ray YOK kuralı korunur.
  - **Geniş Logo etiket genişliği + ürün adı düzeltmesi (KARAR v1.14.4 — kullanıcı isteği):**
    - **Etiket genişliği 94mm → 88mm:** 2×5=10 etiket sayısı aynı kalır. A4 dikey 210×297mm; hücre
      **88mm × 55mm**. 2 sütun = 176mm · 5 satır = 275mm. Kenar boşlukları: **sol/sağ = 17mm**
      (`(210−2×88)/2 = 17`), **üst/alt = 11mm** (`(297−275)/2 = 11`). 10 etiket A4'e tam ortalı kalır.
      HTML `@page{margin:11mm 17mm}` + `.sheet width:176mm` + hücre `88mm×55mm`; PDF `margin:symmetric(v:11mm,
      h:17mm)`; önizleme `EdgeInsets.symmetric(vertical:11mm, horizontal:17mm)`. Üçü BİREBİR.
    - **Ürün adı ~5mm yukarı:** v1.14.3'teki 1.5-harf aşağı-itme, 2 satırlı adlarda alttaki barkod
      çizgilerine giriyordu → aşağı-itme **kaldırıldı** (shift 0), ad gövdenin üst esnek alanında **ÜSTE
      hizalı** (topCenter). Bu, adı önceki konumundan ~1.5 harf ≈ ~5mm yukarı çeker; 2 satır artık barkodu
      yemez. **Barkod + alt satır YERİNDE KALIR** (v1.14.2 alt-çizgi kuralı korunur). Ad hâlâ 2 satır +
      ellipsis/clip. Yeni renk/palet/imza YOK.
