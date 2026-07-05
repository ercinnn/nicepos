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
  - Müşteri kayıtları (DETAY) → müşteri **BAKİYE** (= Kalan Borç). Borç ise `danger`,
    alacak/sıfır ise `positive`; **ray rengi tutara göre** (altın değil — imza istisnası),
    hero büyüklük korunur. Diğer 3 özet (Toplam Satış · Toplam Borç · Ödeme) sakin destek.
  - Müşteri kayıtları (LİSTE) → **Toplam Kalan Borç** hero (KARAR v1.1 — **ONAYLANDI**). Agregat
    borç esnafın manşet metriği; ray `danger` (net alacak fazlası varsa `positive`). Liste
    tablosu/kartlar sakin destek. Detay ekranındaki bakiye hero'su ile aynı dil (borç/alacak).
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
  ince hairline kenarlık. Tür kimliği **sol renk şeridi + ikon/etiket** ile taşınır
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
