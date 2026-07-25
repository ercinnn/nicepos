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
> **v1.15 (KARAR — ONAYLANDI):** Anasayfa hero bandı "dijital platform" yönüne gradyan +
> asimetri kazandı (bkz. §4 sonu). Yeni renk YOK, yalnız `primaryDeep #081226` eklendi
> (mevcut lacivert rampasının bir durağı).

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
- **Anasayfa hero yüzeyi — gradyan + asimetri (KARAR v1.15 — ONAYLANDI, kullanıcı isteği:
  "daha profesyonel, daha dijital platform hissi, renk geçişleri, asimetrik yapılar"):**
  Yalnızca **Anasayfa Dashboard**'daki bugünkü-ciro hero'sunun KENDİ yüzeyi zenginleşir; §4
  kuralları (tek hero, ray yalnız hero altında, tabular figür) DEĞİŞMEDİ — geri kalan ekranlar
  ve hero'lar (Kasa, Müşteri, Raporlar) hâlâ düz beyaz kart + düz altın ray kullanır. "Boldness
  tek yerde" ilkesi bu kararla ÇİĞNENMEDİ, tam tersi uygulandı: imzanın kendisi güçlendirildi.
  - **Yüzey:** beyaz kart yerine 3 duraklı lacivert gradyan (`primary → primaryDark →
    primaryDeep`, ~155° sol-üstten sağ-alta). `primaryDeep #081226` — mevcut lacivert
    rampasının (primary/primaryDark/primaryMid/primaryLight) yeni bir durağı, yabancı hex değil.
  - **Asimetri:** sağ-üst köşede altın (`gold`, ~%32 alfa) radyal parıltı + hafif döndürülmüş
    (~-12°) beyaz-alfa ışık kaması; sol taraf sakin bırakılır — çapraz, merkezi-olmayan denge.
  - **Metin/ray:** hero tutar + "SATIŞ ADEDİ" mini-istatistiği artık beyaz metin (koyu zemin);
    altın ray düz dolgu yerine sağa doğru soluklaşan gradyan (`gold → goldLight → şeffaf`) +
    hafif parıltı gölgesi. Değişim rozeti yeni `_DegisimBadgeOnDark` (camsı/yarı saydam yeşil-
    kırmızı pill) — diğer ekranlardaki `_DegisimBadge` (beyaz zemin) DEĞİŞMEDİ, ayrı bileşen.
  - **Yerleşim:** tutar+ray sola/alta, "Satış Adedi" sağa/üste (yalnız masaüstü) — tek sütun
    yerine çapraz iki-nokta denge. Mobilde mini-istatistik gizlenir (dar genişlikte asimetri
    yerine okunabilirlik önceliklidir).
  - **Kapsam:** yalnız `_HeroBand` (Anasayfa). Diğer hero'lara (Kasa, Müşteri, Raporlar)
    şimdilik uygulanmadı — beğenilirse aynı dil oraya da taşınabilir (ayrı KARAR gerekir).
- **Anasayfa kart yüzey tutarlılığı (KARAR v1.17 — ONAYLANDI, kullanıcı isteği: "hero
  tasarımını tüm ana sayfaya parça parça uygulayalım", kapsam kullanıcı tarafından
  "sadece yüzey dili / kart stili" olarak daraltıldı):** Hero'nun kendine özgü öğeleri
  (koyu lacivert gradyan dolgu, altın radyal parıltı, ışıltı animasyonu, altın ray)
  KESİNLİKLE genişletilmedi — §4 "ekran başına tek hero" ve "altın ray yalnız hero
  altında" kuralları AYNEN geçerli. Genişleyen şey yalnız **kart çerçevesi dili**:
  - Anasayfadaki TÜM destek kartları (`_StatCard`, Günlük Satış Grafiği, Yıllık Ciro
    Karşılaştırma, Yıllık Ortalama Ciro) artık **aynı** `AppSizes.cardDecoration()`
    kullanır (beyaz zemin + ince `goldBorder` kenarlık + `cardShadow` + `radiusLg`).
    Önceden iki yıllık grafik kartı bilinçli olarak kenarlıksız bırakılmıştı ("HERO
    değil" gerekçesiyle) — bu istisna kaldırıldı; ince kart kenarlığı zaten §5 "altın
    ekonomisi"nin İZİN VERİLEN listesinde ("ince kart kenarlığı"), yani bu bir yeni
    altın kullanımı DEĞİL, var olan izinli kullanımın tutarlı uygulanmasıdır.
  - **Yasak kalan (değişmedi):** kartlara koyu lacivert dolgu, gold ray/şerit, radyal
    parıltı veya ışıltı animasyonu eklenmedi — bunların hepsi hero'nun münhasır §4
    imzasıdır. Bu KARAR yalnız "kenarlık/gölge/radius tutarlılığı" kapsar.
- **Stat kartları — ikon + kategorik renk şeridi + mini sparkline (KARAR v1.18 —
  ONAYLANDI, kullanıcı isteği: hero dilini anasayfaya yaymanın devamı, kullanıcı
  4 seçenekten en kapsamlısını seçti):** `_StatCardsRow`'daki 5 kart (Satış Adedi,
  Aylık Ciro, Aylık Adet, Yıllık Ciro, Son 365 Günlük Ciro) açık zemin + altın
  kenarlık (§4 v1.17) korunarak "dijital panel" hissi kazanır. **Altın KULLANILMAZ**
  (ray/şerit altın olamaz, §4/§5 altın ekonomisi AYNEN geçerli) — kimlik rengi
  kategorik palet + ikon ile taşınır. Bu, **yeni bir bileşen dili DEĞİL**, mevcut
  "Ödeme türü butonu" desenininin (§5: "tür kimliği sol renk şeridi + ikon/etiket
  ile taşınır") stat kartlarına uyarlanmasıdır.
  - **Sol renk şeridi (ince, ~3px, kart yüksekliği boyunca):** kategorik, seri renk
    paletinden (§1) ama **altın HARİÇ** — 5 karta sabit atama: Satış Adedi →
    `primary` (lacivert) · Aylık Ciro → `success` (yeşil — ciro/kazanç anlamıyla zaten
    örtüşüyor) · Aylık Adet → `pos` (çelik mavi) · Yıllık Ciro → `splitPayment` (mor)
    · Son 365 Günlük Ciro → `primaryLight` (açık lacivert). `danger` bilinçli
    DIŞARIDA bırakıldı — uygulamanın başka yerlerinde (borç/kritik stok) net bir
    "sorun" anlamı taşıyor; bir ciro kartında kafa karıştırır.
  - **İkon:** başlığın solunda küçük, metrikle ilgili bir ikon (nötr `textSecondary`
    veya kartın kendi kategorik rengi — uygulayan ekran tasarımcısı ikiden birini
    tutarlı seçer).
  - **Mini sparkline:** değerin altında, eksensiz/gridsiz/dolgusuz ince (1.5px) çizgi
    grafik, kartın kategorik rengiyle çizilir (KARAR v1.4 "seri renk paleti" ile aynı
    "çizgi var, dolgu yok" kuralı). Veri kartın periyoduyla TAM örtüşmek zorunda
    değildir (gerçek dashboard sparkline'ları gibi yönsel eğilim gösterir) — kaynak:
    Satış Adedi/Aylık Adet → günlük satış ADEDİ (yeni `dailySalesCountProvider`,
    `dailySalesProvider`'ın adet karşılığı), Aylık Ciro → `dailySalesProvider(8)`,
    Yıllık Ciro → `currentYearMonthlyProvider` (cari yıl aylık seri), Son 365 Günlük
    Ciro → `monthlySalesProvider(12)` (zaten tanımlı, dashboard'da kullanılmıyordu).
  - **Bu bir HERO DEĞİL:** §4 tek-hero kuralı ihlal edilmez — sparkline/şerit/ikon
    hero'nun gradyan+ışıltı+altın-ray yoğunluğunun çok altında, salt "kimlik + trend
    okunabilirliği" için. Veri yoksa/yükleniyorsa sparkline sessizce gizlenir (kartın
    geri kalanı zaten `Skeleton` ile yükleniyor durumunu gösteriyor).

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
  - **Ürün adı 5mm aşağı (KARAR v1.14.5 — kullanıcı isteği):** Geniş Logo etiketinde ürün adı,
    v1.14.4'teki üste-hizalı konumundan **tam 5mm AŞAĞI** taşınır (`_kWNameShift` 0 → 5mm karşılığı).
    - **Ölçü:** her çıktının kendi biriminde tam 5mm — önizleme `5*3.7795 ≈ 18.9px` · HTML `5mm` ·
      PDF `5*PdfPageFormat.mm`. Üç çıktı BİREBİR. Kayma **1 satırda da 2 satırda da AYNI** (üste-hizalı
      blok + sabit üst offset; ortalı-blok tuzağına düşülmez).
    - **Kritik kısıt (v1.14.4 dersi):** Ad ÜSTE hizalı kalır ve barkodun alanını YEMEZ; 5mm eklendikten
      sonra 2 satırlı ad barkoda girecek olursa **ad 2 satır + ellipsis ile kısalır**, barkod/alt satır
      ASLA itilmez (fixed-height çocuklar, boşluğu yalnız esnek ad alanı yutar). Alt satır figür alt
      çizgisinin altına taşamaz (v1.14.2). Yeni renk/palet/imza YOK — yalnız dikey hizalama.
  - **Ürün adı 2.5mm'ye düşürüldü (KARAR v1.14.6 — kullanıcı isteği):** v1.14.5'teki 5mm aşağı-kaydırma,
    2 satırlı adlarda ürün adını hâlâ **azıcık barkoda sokuyordu** → kaydırma **5mm → 2.5mm** yarıya
    indirilir (`_kWNameShift` = 2.5mm karşılığı). Net konum: v1.14.4 üste-hizalı taban + **2.5mm aşağı**.
    - **Ölçü:** her çıktının kendi biriminde tam 2.5mm — önizleme `2.5*3.7795 ≈ 9.45px` · HTML
      `margin-top: 2.5mm` · PDF `2.5*PdfPageFormat.mm`. Üç çıktı BİREBİR; kayma 1 ve 2 satırda AYNI
      (üste-hizalı blok + sabit offset). Barkod + alt satır YERİNDE (v1.14.4/v1.14.2 kısıtları korunur).
- **Dört-etiket (2×2 A5) sekmesi — "Büyük Etiket" (KARAR v1.19 — kullanıcı isteği):** Etiket ekranına
  **dördüncü sekme**; A4 dikey sayfa **tam ortadan bir dikey + bir yatay çizgiyle 4 eşit çeyreğe** bölünür
  (2 üst + 2 alt) → **2 sütun × 2 satır = 4 etiket / A4**. Her çeyrek ≈ **105mm × 148.5mm** (A5). İçerik
  **"Yeni Etiket" (dar logo) etiketiyle BİREBİR AYNI öğe seti** (kullanıcı seçimi: (a)) — yalnız hücre A5'e
  büyüdüğü için oranlar yeniden ölçeklenir. Mevcut etiketleri değiştirmez; yan yana yaşar.
  - **Sekme yapısı:** üst `SegmentedButton` **dört segment** olur: **Yeni Etiket · Geniş Logo · Büyük Etiket ·
    Kayıtlı Dosyalar** (sıra: dar → geniş → büyük → dosyalar). Aktif sekme token dili (§1 altın ekonomisi),
    yeni renk yok. **Responsive (kasa v1.9.5 / v1.14 emsali):** mobilde (<650px) segment ikonları gizli + kısa
    etiketler ("Yeni" · "Geniş" · "Büyük" · "Dosyalar"); masaüstünde tam etiket, tek satır (`maxLines:1,
    softWrap:false`). ⚠️ **İzleme (QA):** dört segment 360px'e sığmayabilir — görsel QA taşma gösterirse
    segment kontrolü **yatay-kaydırılabilir/sarmalı** bir sekme çubuğuna dönüştürülür (fonksiyon/sıra
    değişmez, yalnız barındırma).
  - **A4 geometrisi:** A4 dikey 210×297mm. **Merkez haç kesim çizgileri:** dikey çizgi x=**105mm**, yatay çizgi
    y=**148.5mm** — **nötr ince hairline**, **altın YOK** (§5 altın ekonomisi), hem **önizlemede hem baskıda**
    görünür (kesim kılavuzu; kullanıcı isteği). **Kesim çizgisi rengi (KARAR v1.19.1):** WYSIWYG — önizleme = baskı
    aynı nötr **baskı-grisi**: dolu hücre kenarı/haç `#B8B8B8`, boş hücre `#E0E0E0` (mevcut dar/geniş sekmelerle
    tutarlı). `#EAECF0` (app divider) KULLANILMAZ — beyaz üstünde basılınca görünmez, kesim kılavuzu işlevini
    göremezdi. Bu gri app paletine değil etiket **baskı kavramına** aittir (§4 v1.10 iki-kavram ayrımı); altın
    DEĞİL, imza etkilenmez. Çeyrekler tam yarım
    sayfadır (haç tam ortada). Etiket içeriği her çeyreğin içinde **~6mm güvenli iç boşlukla** yerleşir (yazıcı
    basılamaz kenar payı → hiçbir öğe kırpılmaz). Dış kenarda ek margin yok — kesim yalnız merkez haçtır. HTML
    `@page{size:A4 portrait; margin:0}` + 2×2 ızgara + merkez hairline; PDF `PdfPageFormat.a4`, hücre
    105×148.5mm eşit dağılım + merkez çizgiler; önizleme aynı oranı korur (1mm≈3.78px @96dpi).
  - **Etiket-içi düzen (dar-logo v1.10/v1.12/v1.13 sırası, A5'e yeniden oranlanmış; üç çıktı BİREBİR: önizleme =
    HTML = PDF), üstten alta:**
    1. **Üst bant:** SOL'da logo yuvası (renkli logo v1.12; yoksa `Icons.store` `color.ink` fallback) · kalan
       alanda **ORTALI FİYAT hero** (v1.12) — etiketin en iri/en baskın öğesi, `${formatNumber} TL` kalın
       tabular, **altın ray YOK** (§4 baskı hero'su). A5 hücrede fiyat belirgin büyür; taşarsa `FittedBox
       scaleDown`, asla kırpılmaz.
    2. **Ürün adı** — ortalı (v1.12), en çok 2 satır + ellipsis, siyah.
    3. **Code128 barkod** — ortalı, **%80 genişlik** (v1.13 deseni), çizgi yüksekliği A5 hücreye oranlı.
    4. **Alt satır:** SOL'da barkod no (tabular) · SAĞ-alt köşe oluşturma tarihi (`formatShortDate`, minik).
    - Öğe boyutları dar-logonun mutlak pt değerlerinin **kopyası DEĞİL**, A5 çeyreğe **oranlanır** (blown-up
      seyreklik tuzağından kaçınmak için); esnek barkod alanı + sabit üst/alt öğe deseni (v1.13 kırpılma
      düzeltmesi) korunur. Baskı siyah/beyaz (logo hariç, renkli).
  - **Barkod → ürün çözme = mevcut mantık BİREBİR:** hane input → **Enter** → `_resolveBarcode` (cache →
    fetchByBarcode → fetchAll) → `price1` çözülür, hane dolar, imleç **bir alt haneye** geçer; kamera sürekli
    tarama desteklenir; scan bip sesi (v1.14.1). Aktif hane = ince sol altın şerit + ink kenarlık (§5);
    çözülemeyen = `danger` ince uyarı. **4 hane, tek sütun** (satış/dar-logo deseni).
  - **State:** ayrı `labelQuadSheetProvider` (4 hane, `keepAlive` — mevcut `labelSheetProvider` /
    `labelWideSheetProvider`'a karışmaz, aynı desen).
  - **Mağaza logosu (KARAR v1.19.1):** Büyük Etiket AYRI logo state'i açmaz — dar-logo (Yeni Etiket) sekmesinin
    Supabase Storage'da kalıcı **tek mağaza logosunu** (`labelSheetProvider.logoDataUrl`) paylaşır; quad
    başlığından da Yükle/Değiştir/Kaldır edilebilir. "TEK mağaza logosu" ilkesi korunur, yeni Storage akışı yok.
  - **Aksiyonlar (kullanıcı: evet):** **Yazdır** (web `window.print`) + **PDF Kaydet** (`pdf` paketi, A4 2×2 = 4
    etiket, aynı etiket-içi düzen; Supabase Storage `etiket_pdfleri` bucket'ı) + ortak **Kayıtlı Dosyalar**
    sekmesi (dar + geniş + büyük PDF'ler aynı listede). Mevcut aksiyon dili.
  - **Ekran krom'u:** **ekran hero'su YOK** (araç/çalışma ekranı, §4 v1.10); stok listesi token dili (Manrope
    başlık, Inter tabular, `cardDecoration`, `goldBg` başlık). Masaüstü iki bölge (sol 4-hane girişi · sağ A4
    önizleme), mobil tek kolon. Yeni renk/altın YOK.
- **Büyük Etiket — kırmızı başlık bandı + renkli fiyat kutusu, rozetler kaldırıldı (KARAR v1.20 — kullanıcı
  isteği, referans `E1.jpg`):** "Büyük Etiket" (2×2 A5, KARAR v1.19) sekmesinin etiket-içi görsel dili yeniden
  tasarlanır; bu **yalnızca Büyük Etiket sekmesini** etkiler — **Yeni Etiket ve Geniş Logo sekmeleri DEĞİŞMEDİ**
  (aynı §4 "iki kavram ayrı: uygulama krom'u palete uyar, baskı çıktısı kendi estetiğine sahiptir" ilkesi;
  KARAR v1.12/v1.14'teki "logo renkli" istisnasının bu sekmede metin/zemine **genişletilmiş** hâli — bilinçli
  bir sapma, "baskı siyah/beyaz" kuralının GENEL istisnası DEĞİL, yalnız bu sekmeye özel).
  - **Kaldırılan öğe (referans madde 3):** Üç pill-rozet ("Güçlü Hava Akışı" vb.) **tamamen kaldırılır** —
    `LabelSlot` modelinde (`barcode`/`productName`/`price`/`createdAt` dışında) böyle bir veri alanı yok;
    uydurma/statik metin eklenmez.
  - **Kaldırılan/birleştirilen öğe (referans madde 2):** Ayrı "marka adı + ürün adı" beyaz kartı **eklenmez**
    — ürün adı zaten başlık bandında (aşağıda) gösteriliyor, tekrar olurdu. Bu kartın yerini mevcut **mağaza
    logosu** (KARAR v1.19.1 paylaşılan `logoDataUrl`) alır, başlık bandının SOL tarafına taşınır. "STOKTA VAR"
    gibi stok-durumu metni de **EKLENMEZ** (veri kaynağı yok, referans madde 1'in alt satırı bu yüzden yalnız
    ürün adını taşır).
  - **1. Üst bant → KIRMIZI zemin (referanstaki mavi DEĞİL):** Tam genişlik dolgu **`AppColors.danger
    #C0392B`** (yeni hex YOK, mevcut paletten — burada "borç/hata" semantiği taşımaz, bu bir **baskı-çıktısı**
    rengidir, §4 iki-kavram ayrımı). Köşe radius YOK (dikdörtgen; mevcut quad hücre diliyle ve baskı
    güvenliğiyle tutarlı). İçerik: **SOL**da logo (renkli, v1.12 istisnası; logo yoksa **beyaz**
    `Icons.storefront` fallback — kırmızı zemin üstünde okunurluk için istisnai olarak beyaz, diğer
    sekmelerin `color.ink` fallback'inden farklı, yalnız bu bantta), yanında dikey iki satır: **"ÖZEL
    FİYAT"** (beyaz, w800, iri — ama fiyat hero'sundan **küçük**, hiyerarşi bozulmaz) + altında **ürün adı
    UPPERCASE** (beyaz ~%90 alfa, daha küçük, en çok 2 satır + ellipsis). ~~Bant sabit yükseklikte değil,
    içerik kadar esner~~ **(v1.20.1 ile DÜZELTİLDİ — bkz. aşağı: bant artık SABİT yükseklikte, 2-satır
    ürün adı dahil en kötü durum baştan hesaba katılır).**
  - **2. Rozetler:** YOK (yukarıda kaldırıldı).
  - **3. Fiyat kutusu ("SATIŞ FİYATI"):** Beyaz zemin + **kırmızı (`#C0392B`) ince kenarlık** (~2px, radius
    ~10 — dekoratif kutu çizgisi, fiziksel kesim değil, baskıda sorunsuz) içinde üç satır: küçük üstte
    **"SATIŞ FİYATI"** (kırmızı, `type.utility` benzeri, geniş harf aralığı), ortada **FİYAT hero** — mevcut
    `${formatNumber(price)} TL` formatı AYNEN korunur, yalnız renk siyah→**kırmızı** değişir ve boyut büyür
    (etiketin en baskın öğesi kalır; §4 "fiyat = baskı hero'su, altın ray YOK" değişmez), altta küçük **"KDV
    DAHİLDİR"** (kırmızı/muted kırmızı). Taşarsa `FittedBox scaleDown`, asla kırpılmaz (mevcut kural).
  - **4. Kesikli ayraç:** Fiyat kutusu ile barkod arası ince **kesikli** çizgi, nötr **`#B8B8B8`** (mevcut
    quad-tab kesim-kılavuzu grisi, KARAR v1.19.1 ile zaten tanımlı — yeni renk DEĞİL). Altın DEĞİL.
  - **5-6. Barkod + alt satır (barkod no sol · tarih sağ):** **DEĞİŞMEDİ** — mevcut v1.19 Code128 %80-genişlik
    + `Expanded` esnek barkod alanı + alt satır deseni birebir korunur. Referans görselin "ortalı barkod no +
    ayrı marka/tarih footer satırı" biçimi **benimsenmedi** — kapsam dışı, gereksiz yeni bileşen; mevcut
    sekmeler arası tutarlılık (Yeni Etiket/Geniş Logo ile aynı alt-satır dili) korunur.
  - **Senkron zorunluluğu:** Üç çıktı (canlı önizleme `_QuadLabelCell`, PDF `buildQuadLabelsPdf`, HTML
    `printQuadLabelsA4`) **BİREBİR AYNI** görünmeli (proje ilkesi) — ölçüler her çıktının kendi biriminde
    (px/pt/mm) orantılı çevrilir.
  - **Altın ekonomisi:** Bu kararda altın KULLANILMAZ — yeni kırmızı zemin/kenarlık `danger` paletinden,
    kesikli çizgi nötr griden gelir; §5 "altın aynı ekranda dekor olarak yığılmaz" kuralı ihlal edilmiyor
    (zaten hiç altın kullanılmıyor bu hücrede).
- **Büyük Etiket — üst bant sabit yükseklik + barkod alanı çökme düzeltmesi (KARAR v1.20.1 — QA #7 FAIL
  düzeltmesi):** `gorsel-elestirmen` QA'sı gerçek bir çökme (crash) tespit etti: v1.20'nin özgün metni üst
  bandın "içerik kadar esnediğini" (2 satırlık ürün adında büyüdüğünü) söylüyordu; ürün adı 2 satıra taştığında
  büyüyen üst bant + yeni fiyat kutusunun sabit yükseklik bütçesi birleşince, barkod `Expanded` alanına
  **sıfır/negatif yükseklik** düşüyor ve `barcode` paketinin `assert(height > 0)` kontrolü **gerçek bir
  Flutter çökmesine** yol açıyor (v1.13'teki "yalnız kırpılır" varsayımı burada geçersiz kalmıştı — kırpılma
  değil çökme). Düzeltme, üç çıktıda da (`_QuadLabelCell`, `_quadCell`, `_quadCellHtml`) uygulanır:
  1. **Üst bant artık SABİT yükseklikte** — 2 satırlık ürün adı **dahil en kötü durum** baştan ölçülüp
     bandın yüksekliği bu değere sabitlenir (1 satırlık adlarda da bant AYNI yükseklikte kalır, içerik
     kısaysa altında boşluk kalabilir). Böylece toplam sabit-yükseklik bütçesi ürün adının uzunluğuna göre
     ASLA değişmez — barkod alanının payı deterministik olur.
  2. **Fiyat kutusunun dikey iç boşluğu hafifçe daraltılır** (ek güvenlik payı için) — görsel hiyerarşi/renk/
     sıralama DEĞİŞMEZ, yalnız padding küçülür.
  3. **Savunma katmanı (defensive):** Barkod `Expanded`/flex alanının gerçekte aldığı yükseklik çok küçük bir
     eşiğin (~8px benzeri) altına düşerse `BarcodeWidget`/eşdeğeri **render edilmez** (boş alan gösterilir) —
     asla `assert`/exception fırlatmaz. Bu, tasarım dilini değiştirmeyen saf bir güvenlik ağıdır; normal
     koşulda (madde 1 ile) bu dala hiç girilmemesi beklenir.
  4. **Regresyon testi zorunlu:** Büyük Etiket için 2-satırlık (uzun) ürün adıyla hücrenin crash/overflow
     vermeden render edildiğini doğrulayan bir widget/golden testi eklenir (`dashboard_render_test.dart`/
     `wide_label_golden_test.dart` emsali) — bu QA turunda böyle bir test bulunmadığı için regresyon
     otomatik yakalanamamıştı.
  - **Kapsam:** Yalnız Büyük Etiket hücresinin iç yerleşimi (yükseklik bütçesi + savunma kodu); renk/tipografi/
    kesikli-ayraç kararları (v1.20) DEĞİŞMEZ. Yeni renk/altın YOK.
- **"Ürün Etiketi" (6×12 = 72/A4) sekmesi — adet-tabanlı, fiyatsız barkod etiketi (KARAR v1.21 — kullanıcı
  isteği, referans `design/urun-etiketi-taslak.html`):** Etiket ekranına **beşinci sekme**. Diğer üç etiket
  sekmesinden (Yeni Etiket/Geniş Logo/Büyük Etiket) **iki temel farkı** vardır: (1) **etkileşim adet-tabanlıdır**
  (numaralı hane değil), (2) **fiyat ve logo YOKTUR** — saf ürün/stok barkod etiketi. Mevcut sekmeleri
  değiştirmez; yan yana yaşar.
  - **Sekme yapısı:** üst `SegmentedButton` **beş segment** olur: **Yeni Etiket · Geniş Logo · Büyük Etiket ·
    Ürün Etiketi · Kayıtlı Dosyalar** (sıra: dar → geniş → büyük → ürün → dosyalar). Aktif sekme token dili (§1
    altın ekonomisi), yeni renk yok. ⚠️ **Responsive:** beş segment 360px'e sığmaz → mobilde segment kontrolü
    **yatay-kaydırılabilir/sarmalı sekme çubuğuna** dönüştürülür (v1.19'daki dört-segment izleme notunun devamı;
    fonksiyon/sıra değişmez, yalnız barındırma). Masaüstünde tam etiket + tek satır.
  - **A4 baskı geometrisi (KİLİTLİ, kullanıcı ölçüleri):** A4 dikey 210×297mm. **Sayfa boşluğu: üst 10mm, alt
    10mm, yatay 0** (etiketler tam genişliği doldurur). **6 sütun × 35mm = 210mm** · **12 satır × 23mm = 276mm**
    (10+276+10 = 296 ≤ 297, ~1mm pay). **Hücre 35 × 23mm**, her kenardan **3mm iç pay** (kenardaki + ortadaki TÜM
    etiketlerde eşit) → **içerik alanı 29 × 17mm**. HTML `@page{size:A4 portrait; margin:10mm 0}` + 6×12 grid;
    PDF `PdfPageFormat.a4` + eşdeğer margin/hücre; önizleme aynı oran (1mm≈3.78px @96dpi). Üç çıktı (önizleme =
    HTML = PDF) BİREBİR.
  - **Kesim çizgisi (kullanıcı: çizgi istemiyorum):** die-cut hazır etiket kağıdı → **baskıda çerçeve/kesim
    çizgisi YOK**. Yalnız **canlı önizlemede** ince nötr baskı-grisi hairline kılavuz (`#C9CDD6`/quad-tab grisi,
    altın DEĞİL) hizalama için gösterilir; `@media print` içinde gizlenir. Altın ekonomisi ihlal edilmez.
  - **Etiket-içi düzen (üstten alta, ortalı; içerik alanı 17mm sıkı bütçe):**
    1. **Ürün adı** — **2 satır sabit** ayrılmış alan (~4.4mm), **ORTALI**, siyah; kısa ad üstte hizalı, uzun ad
       2 satır + ellipsis (`FittedBox`/clip; barkod alanını YEMEZ). **Fiyat/logo YOK.**
    2. **Code128 barkod** — ortalı, **sabit 7mm yükseklik** (KARAR v1.21.1 — kullanıcı; önce 10mm'di, **7mm'ye
       indirildi**); yatayda hücre iç genişliğinde. Barkod → ürün çözme = mevcut mantık BİREBİR.
    3. **Barkod numarası** — alt satır, ortalı, Inter tabular (~2mm), siyah.
    - **Bütçe (v1.21.1 sonrası ferahladı):** 17mm iç yükseklikte 2-satır ad (~4.4mm) + 7mm barkod + numara
      (~2mm) ≈ 13.4mm → ~3.6mm nefes payı. **v1.20.1 crash dersi yine geçerli** (güvenlik ağı korunur): sabit
      öğeler (ad `flex:0 0` + ellipsis, numara `flex:0 0`) + barkod sabit 7mm; barkod alanının gerçek yüksekliği
      ~8px eşiğin altına inerse `BarcodeWidget` render edilmez (assert/exception fırlatmaz). Ayar kolu (gerekirse,
      ayrı KARAR): iç pay 3→2mm veya barkod yüksekliği.
  - **Etkileşim — adet-tabanlı doldurma (yeni model):** Sol panelde bir giriş satırı: **Barkod hanesi** (okut/
    Enter → `_resolveBarcode` cache→fetchByBarcode→fetchAll ile ürün adı çözülür, scan bip sesi v1.14.1) +
    **Adet hanesi** (kaç etiket). Onaylanınca kalem listeye `(ürün adı · barkod · adet)` olarak eklenir, imleç
    yeni boş barkod satırına geçer (satış/dar-logo `_onBarcodeSubmitted` deseni). Sağ panelde: listedeki her
    kalem **adet kadar çoğaltılıp** 72'lik ızgaraya **sırayla** dizilir; toplam > 72 ise **2., 3. sayfaya taşar**
    (çok-sayfalı PDF). Kalem silme + adet düzenleme mümkün. Aktif barkod hanesi = ince sol altın şerit + ink
    kenarlık (§5 altın ekonomisi); çözülemeyen = `danger` ince uyarı.
  - **State:** ayrı `labelProductSheetProvider` (`keepAlive`, kalem listesi — mevcut `labelSheetProvider` /
    `labelWideSheetProvider` / `labelQuadSheetProvider`'a karışmaz, aynı desen). Mağaza logosu paylaşılmaz
    (bu sekmede logo yok).
  - **Aksiyonlar:** **Yazdır** (web `window.print`) + **PDF Kaydet** (`pdf` paketi, **çok-sayfalı**, aynı etiket-
    içi düzen; Supabase Storage `etiket_pdfleri` bucket'ı → ortak **Kayıtlı Dosyalar** sekmesine düşer). Mevcut
    aksiyon dili.
  - **Ekran krom'u:** **ekran hero'su YOK** (araç/çalışma ekranı, §4 v1.10); stok listesi token dili (Manrope
    başlık, Inter tabular, `cardDecoration`, `goldBg` başlık). Masaüstü iki bölge (sol barkod+adet girişi/kalem
    listesi · sağ A4 önizleme), mobil tek kolon. Yeni renk/altın YOK. Baskı siyah/beyaz.
  - **Ürün Etiketi — iç pay daraltma + barkod büyütme + dikey ortalama (KARAR v1.22 — kullanıcı isteği):**
    KARAR v1.21/v1.21.1 etiket-içi geometrisi dört noktada güncellenir (önizleme = HTML = PDF, üçü BİREBİR;
    yeni renk/palet/imza YOK — yalnız baskı geometrisi). Hücre 35×23mm ve 6×12=72/A4 grid **DEĞİŞMEZ**:
    1. **İç pay 3mm → 1.5mm** (kenardaki + ortadaki TÜM etiketlerde 4 kenardan eşit) → **içerik alanı
       29×17mm → 32×20mm** (yatay 35−3=32, dikey 23−3=20). Fiziksel die-cut hücre değişmez; 1.5mm hâlâ
       güvenli baskı payı.
    2. **Barkod çizgi yüksekliği 7mm → 8mm** (SABİT; v1.21.1'in 7mm'sini büyütür). 20mm iç yükseklikte
       rahat sığar. Savunma katmanı (v1.20.1 dersi, ~8px eşiği altında BarcodeWidget render edilmez) korunur.
    3. **Dikey ortalama — 3 öğe grubu (ürün adı + barkod + barkod no) içerik alanında dikey ORTALANIR**
       (`mainAxisAlignment.start`/`justify-content: flex-start` → **`center`**): etikete bakınca üstte ve
       altta kalan boşluklar **eşit** görünür. 20mm − (~4.4 ad + 8 barkod + ~2.5 no ≈ 14.9mm) ≈ ~5mm boşluk
       → üst/alt ~2.5mm eşit nefes payı (v1.20.1 crash savunması korunur; taşma olursa alt satır itilmez).
    4. **Barkod numarası bir font kademesi büyür:** HTML 6pt → **7pt**, PDF 6 → **7**, önizleme 7.5 → **8.5**px
       (Inter tabular, ortalı, siyah). Ürün adı fontu + 2-satır sabit alanı (4.4mm) DEĞİŞMEZ.
