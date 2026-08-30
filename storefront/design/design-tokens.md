# NicePOS Online Satış (storefront) — Tasarım Sistemi

Bu dosya `storefront/`'un (Cloudflare Pages, `nicepos-online-satis.pages.dev`)
**tek tasarım doğru kaynağıdır**. `magaza-tasarim-lideri` agent'ının tek
sahibidir — ekran tasarımcıları (`magaza-tasarimci`) bu dosyayı **okur,
değiştirmez**. Bir KARAR buraya yazıldıysa, alt agent'a devretmeden ÖNCE
commit edilmelidir (bkz. ana proje `CLAUDE.md`'deki "Sıralama kuralı" —
aynı ders burada da geçerli).

**⚠️ Bu, ana `nicepos/design/design-tokens.md`'den AYRI bir sistemdir.**
Ana uygulama personel için koyu "Enstrüman Konsolu" (v2.0) diliyle çalışır;
storefront müşteri karşısında sıcak/aydınlık bir perakende mağazasıdır.
Palet kökeni ortak (lacivert + altın) ama uygulama dili KASITLI olarak
farklı — `magaza-tasarim-lideri` ana uygulamanın koyu panel dilini
storefront'a taşımaz.

## 1. Palet

Kaynak: `storefront/lib/core/theme.dart` `StoreColors`.

| Token | Hex | Kullanım |
|---|---|---|
| `navy` | `#1B2A4A` | AppBar, birincil buton, hero/footer zemini |
| `navyMid` | `#2E4270` | Hero gradyan ara tonu |
| `navyDeep` | `#121D34` | Hero/footer gradyan koyu ucu |
| `gold` | `#D4B86A` | İmza rayı, hover kenarlığı |
| `goldLight` | `#E3CD94` | Hero eyebrow metni, logo ikonu |
| `pageBg` | `#F7F7F8` | Sayfa zemini (aydınlık) |
| `cardBg` | `#FFFFFF` | Ürün kartı zemini |
| `border` | `#E4E4E7` | Kart/input kenarlığı |
| `textPrimary` | `#1F2430` | Ana metin |
| `textMuted` | `#767B8A` | İkincil metin |
| `danger` | `#B3412C` | Tükendi rozeti, hata metni |
| `success` | `#1B7A45` | Sipariş onay ikonu |

## 2. Tipografi

`google_fonts` paketi ile:
- **Space Grotesk** (w600) — hero başlığı, AppBar logotipi, bölüm başlıkları
  (`displayLarge…titleLarge`, `theme.dart` `_buildTextTheme()`). Ana
  uygulamanın "enstrüman" kimliğine bir gönderme — bu mağaza pratik
  ürün/hırdavat sattığından teknik/hassas bir başlık karakteri anlamlı.
- **Inter** — gövde metni, buton etiketleri, ürün adı/fiyatı, tüm UI kromu.

**Kural:** Space Grotesk YALNIZ başlık rolünde kullanılır (spend boldness in
one place) — gövde/ürün kartı/form metni her zaman Inter kalır.

## 3. İmza öğesi: Tikli Altın Ray (statik)

Ana uygulamanın hero rayının (design-tokens.md §4/§6.3, animasyonlu/ışıltılı)
**sakin, statik** bir yorumu. Kullanıldığı yerler:
- `StoreHeroBanner` — başlığın altında `_TickRail` (ince yatay çizgi + 8 eşit
  aralıklı dikey tik).
- `StoreAppBar` — alt kenarda 1px altın çizgi (rayın en küçük yansıması).

**Kural:** Işıltı/animasyon YOK (ana uygulamanın Anasayfa hero'suna özel
kalır). Storefront'ta altın YALNIZ bu iki yerde + ürün kartı hover
kenarlığında — başka yerde altın kullanılmaz (altın ekonomisi, ana
uygulamadaki aynı disiplin).

## 4. Spacing Ölçeği

Storefront'ta spacing şu ana kadar ad-hoc kod-içi sayılarla yönetildi
(`EdgeInsets.all(16/20/24)`, dağınık 4/6/8/10/12/14/18 karışımı). Aşağıdaki
adlandırılmış ölçek bundan sonra eklenen HER yeni bileşende zorunludur:

| Token | px | Kullanım |
|---|---|---|
| `space.xs` | 4 | En dar boşluk — rozet iç dolgu (dikey), sepet miktar kontrolü rakam-ikon arası, metin bar'ları arası mikro boşluk (skeleton) |
| `space.sm` | 8 | Chip/rozet yatay iç dolgu, kart görsel↔başlık arası, ürün grid `crossAxisSpacing`/`mainAxisSpacing`, `Wrap` satır/kolon aralığı |
| `space.md` | 12 | Kompakt kart iç dolgu, sepet satırı ikon↔metin arası, breadcrumb/stepper dikey boşluğu, chip yatay iç dolgu |
| `space.lg` | 16 | Sayfa kenar dolgusu (mobil), liste `ListView` dış dolgu, form alanları arası, boş durum ikon↔mesaj arası |
| `space.xl` | 20 | Kart/panel iç dolgu (sipariş özeti kutusu, sepet alt bar), buton yatay iç dolgu, boş durum mesaj↔CTA arası |
| `space.xxl` | 24 | Bölüm arası dikey boşluk (ürün grid → footer), sayfa kenar dolgusu (masaüstü) |
| `space.xxxl` | 32 | Hero banner iç dolgu, büyük bölüm ayırıcı |
| `space.huge` | 48 | Sayfa üst/alt büyük nefes payı, boş durum dikey ortalama payı |

**Kural:** Yeni eklenen her widget bu tablodaki bir değeri kullanır — ara
değer (10, 14, 18 gibi) YENİ kodda açılmaz. Mevcut dosyalarda rastlanan ara
değerlere bu turda dokunma zorunluluğu yok (geriye dönük toplu refactor bu
görevin kapsamı dışı), ama bir ekran zaten elden geçiyorsa o dosyadaki
komşu ara değerler fırsatçı olarak en yakın tokene çekilir.

## 5. Skeleton / Shimmer Yükleme Durumu

Şu an her yükleme durumu çıplak, ortalanmış `CircularProgressIndicator` —
sayfa yapısını göstermiyor ve algılanan bekleme süresini uzatıyor. Yeni
standart: içerik biçimini taklit eden shimmer placeholder'lar (paket onayı
§12'de).

- **Renk — ALTIN DEĞİL:** `baseColor = StoreColors.navy.withValues(alpha:
  0.06)`, `highlightColor = StoreColors.navy.withValues(alpha: 0.12)`,
  `pageBg` zemin üstünde. Gold bu örüntüde HİÇ kullanılmaz — "yükleniyor"
  durumu ile hero/hover'ın imza rengi asla karışmaz (altın ekonomisi).
- **Kart placeholder** (ürün grid'i): `product_card.dart` ile birebir aynı
  köşe yarıçapı (`BorderRadius.circular(10)`) — üstte görsel alanı bloğu,
  altta iki metin bar (isim: 2 satır, fiyat: 1 satır), her metin bar
  `BorderRadius.circular(4)`.
- **Satır placeholder** (sepet satırı, sipariş özeti kalemi): 56×56 görsel
  kare (`cart_screen.dart`'taki görsel boyutuyla aynı, `BorderRadius.
  circular(8)`) + yanında iki metin bar.
- **Görsel placeholder** (ürün detay ana görseli): tam genişlik, kare/4:3,
  `BorderRadius.circular(10)`.

**Kural:** Shimmer yalnız veri gelene kadarki geçici bir zemindir — gerçek
içerik rengine (dolu navy, gold) hiçbir tonda yaklaşmaz.

## 6. Buton Varyantları

Şu an tek stil var (`theme.dart` `elevatedButtonTheme`, dolu navy, tüm
aksiyonlarda aynı görünüm). Üç varyant tanımlanıyor:

- **Birincil** (mevcut, değişmedi): dolu `navy` zemin, beyaz metin,
  `BorderRadius.circular(8)`, `EdgeInsets.symmetric(horizontal: space.xl,
  vertical: 14)`. Ekranda TEK birincil aksiyon için: Sepete Ekle, Siparişi
  Tamamla, Siparişi Onayla.
- **İkincil / Outline** (yeni): şeffaf zemin, `border: 1.5px solid
  StoreColors.navy`, metin `navy` w600, aynı boyut/köşe/dolgu. Hover:
  `navy@0.04` dolgu. Kullanım: boş durum CTA'sı ("Alışverişe Başla" —
  sayfa değiştiren ama satın-alma olmayan aksiyon), checkout'ta "Sepete
  Dön" gibi ikincil gezinme aksiyonları.
- **Destructive / Tehlike** (yeni): metin+ikon `StoreColors.danger`,
  zemin şeffaf, hover'da `danger@0.06` dolgu, kenarlıksız (metin butonu —
  `TextButton.styleFrom(foregroundColor: danger)`). Kullanım: sepet satırı
  "kaldır" aksiyonu (şu an yalnız soluk bir X ikonu — bu stille netleşir),
  ileride "Siparişi İptal Et" gibi geri döndürülemez aksiyonlar.

**Kural:** Bir ekranda birden fazla dolu-navy birincil buton yan yana
DURMAZ (ana uygulamanın ödeme paneli "iki aksiyon sınıfı" dersiyle aynı
mantık) — ikincil aksiyon her zaman outline/metin stiline düşer.

## 7. Kategori Chip Yeniden Tasarımı

Mevcut `_CategoryChip` (`home_screen.dart`) bare Material `ChoiceChip` —
token'lı görünüm:

- **Seçili değil:** zemin `cardBg` (beyaz), kenarlık 1px `border`, metin
  `textPrimary` 12.5px w500.
- **Seçili:** zemin `navy`, kenarlık `navy`, metin beyaz w600. (Gold
  KULLANILMAZ — "seçili" bir yeni altın yüzey açmamalı; navy zaten "aktif"
  anlamını taşıyor, ürün kartı hover'ındaki tek altın anına rakip
  yaratmaz.)
- **Şekil:** `StadiumBorder` (tam pill) — mevcut görünüme yakın, netleşir.
- **İç dolgu:** yatay `space.md` (12), dikey `space.xs` (4) civarı —
  chip'in kompakt kalması `Wrap`'in `maxHeight: 168` (~3 satır) sınırına
  sığmasını korur.
- **`Wrap` boşluğu:** satır/kolon aralığı `space.sm` (8).

## 8. Breadcrumb Örüntüsü

Ürün detayından kategoriye/anasayfaya dönüş için. Gold KULLANILMAZ.

- Tipografi: Inter 12.5px — pasif segment `textMuted`, mevcut sayfa
  (tıklanamaz, son segment) `textPrimary` w600.
- Ayraç: `Icons.chevron_right` 14px `textMuted@0.6`.
- Tıklanabilir segment: `InkWell`, hover'da `textPrimary`'ye kararma
  (navy'YE DEĞİL — breadcrumb bir aksiyon değil gezinme ipucu, navy
  butonlara ayrılır).
- Konum: sayfa üst kenar dolgusunun hemen altı, başlıktan önce, `space.md`
  (12) dikey boşlukla.
- Örnek: `Anasayfa › Bahçe Aletleri › Bahçe Makası`

## 9. Stepper / İlerleme Göstergesi (checkout)

⚠️ Bu YALNIZ akış-görünürlüğü içindir, bir ÖDEME adımı DEĞİLDİR — iyzico
entegrasyonu henüz yapılmadı (ana `CLAUDE.md` → "Ödeme Entegrasyonu
(planlandı, HENÜZ YAPILMADI)"), sipariş şu an "kapıda/elden ödeme"
modeliyle çalışıyor. Adım adları/dili bunu ima ETMEZ — "Ödeme" kelimesi
bir adım etiketi olarak KULLANILMAZ.

**3 adım:** Sepet → Teslimat Bilgileri → Sipariş Onayı. ("Teslimat
Bilgileri" checkout'taki misafir bilgi formuna karşılık gelir — ad/soyad/
telefon/adres; bir ödeme adımı değil.)

- Yatay üç nokta/segment, aralarında ince bağlayıcı çizgi.
- **Tamamlanan adım:** dolu `navy` daire + beyaz onay ikonu (`Icons.check`,
  12px).
- **Aktif adım:** `navy` 2px kenarlıklı BOŞ daire, içi `navy` numara —
  dolu DEĞİL (dolu = "tamamlandı" anlamı taşımasın).
- **Gelecek adım:** `border` renginde ince kenarlıklı boş daire, içi
  `textMuted` numara.
- Bağlayıcı çizgi: tamamlanan segment `navy`, kalan `border`.
- Adım etiketi: Inter 11px — aktif `textPrimary` w600, diğerleri
  `textMuted`.
- Gold KULLANILMAZ — stepper işlevsel bir gezinme ipucudur, imza öğesi
  değil; altın ekonomisini genişletmez.
- Konum: checkout sayfası üst kısmı (checkout'ta ayrıca breadcrumb
  kullanılmaz, stepper onun işlevini üstlenir).

## 10. Sipariş Özeti Kartı

Checkout'taki mevcut "Toplam" kutusu (`cart_screen.dart`'ın alt barındaki
desenin checkout'taki karşılığı) ile sipariş-onay ekranındaki
(`order_success_screen.dart`) özet AYNI görsel dili paylaşır:

- Zemin `cardBg`, kenarlık 1px `border`, köşe `BorderRadius.circular(10)`
  (ürün kartıyla aynı yarıçap ailesi).
- İç dolgu `space.xl` (20).
- Kalem satırı: sol etiket `textMuted` 13px, sağ değer `textPrimary` 13px
  — `Row` + `Spacer` (mevcut cart_screen alt bar deseniyle aynı).
- Toplam öncesi ince `Divider` (`border` rengi), `space.sm` (8) üst/alt
  boşlukla.
- Toplam satırı: etiket w600 14px, değer `navy` w800 20px — mevcut
  cart_screen alt bar tutarıyla BİREBİR aynı stil (yeni bir hero değil,
  var olan örüntünün genellenmesi).
- Sipariş-onay ekranında ek: üstte sipariş kodu (Space Grotesk, tek
  satır, kartın DIŞINDA/üstünde) — kartın kendisi altın ray TAŞIMAZ, bu
  bir hero değil.

## 11. Boş Durum Örüntüsü

Referans/kanonik: sepetin mevcut boş durumu (`cart_screen.dart` satır
20-42) — bu örüntü anasayfa (boş arama/filtre sonucu) ve checkout'a (boş
sepetle checkout'a erişim) da uygulanır:

- `Center` + `Column(mainAxisSize: MainAxisSize.min)`.
- İkon 48px `textMuted`, duruma özgü outline ikon (sepet:
  `shopping_cart_outlined`, arama sonucu boş: `search_off_outlined`,
  kategori boş: `inventory_2_outlined`).
- `space.md` (12) boşluk.
- Mesaj: `textMuted`, düz Inter gövde metni — operasyonel iddia YOK
  ("şu an ürün yok" gibi nötr; "yakında gelecek/stoklar yenileniyor" gibi
  doğrulanmamış vaat YAZILMAZ).
- `space.lg` (16) boşluk.
- CTA (varsa): §6'daki **ikincil/outline** buton — birincil DEĞİL (boş
  durumda "satın alma" değil "gezinmeye devam" aksiyonu). Sepet boşsa
  "Alışverişe Başla" → anasayfa; checkout'a boş sepetle gelinirse aynı
  CTA.
- CTA yoksa (ör. bir arama sonucu boşsa) yalnız ikon+mesaj yeterlidir.

## 12. Yeni Bağımlılık Onayı

Bu turda iki yeni paketin `storefront/pubspec.yaml`'a eklenmesi
ONAYLANMIŞTIR — bu onay olmadan `magaza-tasarimci` pubspec.yaml'a paket
EKLEYEMEZ (ana `CLAUDE.md`'deki worktree/agent yazma kısıtı gereği bu
onay net yazılı olmalı):

- **`cached_network_image`** — tüm `Image.network` çağrılarının (ürün
  kartı, ürün detay, sepet satırı) yerini alır. Gerekçe: aynı ürün görseli
  anasayfa grid'i → ürün detay → sepet arasında tekrar tekrar ağdan
  çekiliyor (cache yok), her yüklemede çıplak gri kare/spinner sıçraması
  oluyor. `placeholder:` parametresi §5'teki shimmer placeholder'ı
  kullanır; `errorWidget:` mevcut `_ImagePlaceholder`/inline hata ikonu
  davranışını korur (yalnız cache + fade-in ekleniyor, hata davranışı
  değişmiyor).
- **`shimmer`** — §5'teki skeleton örüntüsünü uygular (`Shimmer.
  fromColors(baseColor, highlightColor, child)`). Gerekçe: şu an her
  yükleme durumu çıplak `CircularProgressIndicator` — sayfa yapısını
  göstermiyor, algılanan bekleme süresini uzatıyor.

Her iki paket de yalnız görsel/algısal katman — veri modeli/RPC/state
mimarisine dokunmaz, web derlemesini bozmaz. `flutter clean && flutter pub
get` gerekliliği (ana `CLAUDE.md`'deki `MissingPluginException` dersi) bu
iki paket için de geçerlidir — ilk release build öncesi unutulmamalı.

## 13. Bileşen notları

- **Hero banner** (`store_hero_banner.dart`): koyu lacivert→navyDeep gradyan,
  eyebrow (goldLight, 12px, letterSpacing 2.2) + başlık (Space Grotesk 32px)
  + tikli ray + alt yazı (Inter, white@0.72). Kısa tutulur (tek başlık satırı
  + tek alt yazı) — ürün grid'inin önüne geçmez. Operasyonel iddia (teslimat
  süresi, hizmet bölgesi) İÇERMEZ — doğrulanmamış vaat yazılmaz.
- **Footer** (`store_footer.dart`): navyDeep zemin, marka bloğu + hızlı
  bağlantılar + telif hakkı satırı. Gerçek iletişim/yasal bilgi (KVKK,
  Mesafeli Satış Sözleşmesi, telefon) HENÜZ YOK — sahte bilgi UYDURULMAZ,
  yalnız gerçek veri geldiğinde eklenir.
- **Ürün kartı** (`product_card.dart`): hover'da 3px yukarı kalkma
  (`AnimatedContainer` + `Matrix4.translationValues`, 150ms) + kenarlık
  `border`→`gold@0.7` + gölge (`navy@0.14`, blur 18, offset (0,8)).
- **Kategori şeridi** (`home_screen.dart`): 200+ kategori tek satır yatay
  kaydırmaya SIĞMAZ — `Wrap` ile çoklu satır, `maxHeight: 168` (~3 satır)
  içinde dikey kaydırmalı. Yatay `ListView` KULLANILMAZ (dar/tight
  cross-axis constraint ChoiceChip'i içeriden taşırır — yaşanmış hata).
  Chip'in kendi görünümü artık §7'de tanımlı (bare `ChoiceChip` yerine
  token'lı varyant).
- **Sayfa geçişleri**: tüm `go_router` rotaları `_fadeThroughPage` kullanır
  (240ms giriş / 180ms çıkış, `Curves.easeOutCubic`, hafif yukarı kayma +
  fade) — ana uygulamanın `router.dart` `_fadeThroughPage`'iyle BİREBİR aynı
  eğri/süre (iki ayrı Flutter projesi olsa da marka geçiş hissi tutarlı
  kalsın diye kasıtlı kopya).

## 15. Editoryal Ürün Izgarası (ProductGrid / ProductCard / FilterSidebar)

Kullanıcı isteği (COS/Ferm Living/KITH referanslı) monokrom bir kimlik
öneriyordu — **KARARLAŞTIRILDI: palet/tipografi (§1-2) DEĞİŞMEDİ**, yalnız
YAPISAL/etkileşim kalıpları (grid oranı, hover dinamikleri, sol filtre)
editoryal referanslara göre yenilendi. Altın ekonomisi (§3) korunur.

- **`ProductGrid`** (`widgets/product_grid.dart`): kolon sayısı Tailwind
  referans breakpoint'leriyle BİREBİR — mobil 1, `sm` (≥640) 2, `lg` (≥1024)
  4. Kolon SAYISI kararı `home_screen.dart`'ta (viewport genişliğine göre)
  verilir, `ProductGrid`'in KENDİ yerel genişliğine göre DEĞİL — masaüstünde
  sidebar'ın yanında `ProductGrid`'in genişliği daralmış olabilir, bu yüzden
  kendi genişliğinden breakpoint çıkarması yanlış sonuç verirdi. Gap `space.
  xxl` (24, Tailwind `gap-6`). Hücre `childAspectRatio`'su görsel oranı
  (3:4) + sabit metin bloğu yüksekliğinden (`ProductCard.textBlockHeight`,
  96) hesaplanır — ikisi arasında SENKRON kalmalı (biri değişirse diğeri de).
- **`ProductCard`** (`widgets/product_card.dart`):
  - Görsel: kesin `3:4` dikey oran (`AspectRatio` + `BoxFit.cover`).
  - Hover dinamiği: **ikinci ürün görseli veri modelinde YOK**
    (`StoreProduct` tek `image_url` taşır — ikinci görsel eklemek ayrı bir
    şema/form işi, bu turun kapsamı dışı bırakıldı). Görsel takas yerine
    hafif bir `AnimatedScale` yakınlaştırması (1.0→1.06, 300ms) kullanılır.
  - Quick-add barı: görselin altına yaslanan, `AnimatedSlide` ile beliren
    dolu-navy bar (§6 birincil buton diliyle aynı). **Yalnız hover'a bağlı
    DEĞİL** — `MediaQuery` genişliği <1024 ise (dokunmatik varsayımı, hover
    hiç tetiklenmez) bar HER ZAMAN görünür kalır; a11y/kullanılabilirlik
    gereği (yaşanmış ders: yalnız hover'a bağlı bir CTA dokunmatik
    kullanıcıyı tamamen dışarıda bırakırdı).
  - Renk swatch'ları **eklenmedi** — sistemde ürün varyant/renk modeli hiç
    yok (POS envanteri, moda kataloğu değil); sahte/placeholder veri
    UYDURULMADI.
  - Metin bloğu: kategori etiketi (varsa, `textMuted` uppercase, opsiyonel —
    `StoreProduct.groupId` her zaman dolu olmayabilir) + başlık (sol hizalı,
    2 satır) + fiyat (`navy` w700, `Spacer()` ile bloğun altına sabitlenir).
    Sabit yükseklik (`textBlockHeight`) — kategori etiketi olsun/olmasın
    kart boyu hizalı kalır, `ProductGrid`'in aspect-ratio hesabıyla taşma
    riski oluşmaz (başlık zaten `maxLines:2` ile üstten sınırlı).
  - Kart hover'ı (kenarlık→gold, gölge, 3px kalkma) **KORUNDU** (v1.1'den
    değişmedi) — bu, storefront'un tek gold-hover imza anı.
- **`FilterSidebar`** (`widgets/filter_sidebar.dart`): `w-64` (256px)
  sabit genişlik, yalnız `lg` (≥1024) genişlikte gösterilir — dar/orta
  ekranda 256px sabit bir sütun sığmaz, mevcut yatay kategori chip şeridi
  (§7) korunur. Görsel dil pill/chip DEĞİL — sol 2px gold kenarlıklı düz
  metin listesi (editoryal, "filtre" bir navigasyon listesi gibi okunur).
  Seçili satırda gold kenarlık + `textPrimary` w600; pasifte `textMuted`
  w400. Kendi `SingleChildScrollView`'ı var (200+ kategori). **"Sticky"
  gerçek CSS `position:sticky` DEĞİL** — sayfa `Row(crossAxisAlignment:
  stretch)` ile sidebar'ı sağdaki ürün ızgarasından BAĞIMSIZ bir sütuna
  koyar (`Expanded(SingleChildScrollView(...))` yalnız sağ taraf kaydırılır)
  — sidebar `Scaffold.body`'nin tam yüksekliğini kaplar ve kendi içeriği
  taşarsa yalnız KENDİSİ kaydırılır; pratik sonuç aynı ("filtre her zaman
  görünür kalır") ama scroll-offset'e bağlı animasyonlu bir sticky değil,
  daha basit/kırılgan-olmayan bir ikiz-scroll deseni.

## 16. KARAR Geçmişi

- **v1.0** (2026-08-07): İlk kuruluş. Hero banner + footer + Space
  Grotesk/Inter tipografik çift + AppBar altın çizgisi + ürün kartı hover +
  sayfa geçiş animasyonu (fade-through). Kategori şeridi yatay
  `ListView`'dan `Wrap`'e çevrildi (200+ kategori taşma sorunu).
- **v1.1** (2026-08-09): Kapsamlı UI/UX güçlendirme turu — dört ekran
  (anasayfa/ürün detay/sepet/checkout) için ortak örüntüler eklendi:
  §4 adlandırılmış spacing ölçeği (4/8/12/16/20/24/32/48), §5 skeleton/
  shimmer stili (navy-alfa sweep, ALTIN DEĞİL), §6 üç buton varyantı
  (birincil dolu + ikincil outline + destructive metin), §7 kategori
  chip'in token'lı yeniden tasarımı, §8 breadcrumb örüntüsü (gold yok),
  §9 checkout stepper'ı (Sepet→Teslimat Bilgileri→Sipariş Onayı — bir
  ödeme adımı DEĞİL, iyzico entegrasyonu henüz yok), §10 sipariş-özeti
  kartı (cart_screen "Toplam" barının genellenmesi), §11 tek bir boş durum
  örüntüsü (sepetin mevcut deseni kanonikleşti). **Paket onayı:**
  `cached_network_image` + `shimmer` eklenmesi onaylandı (§12) — bu onay
  olmadan `magaza-tasarimci` pubspec.yaml'a dokunamaz. Eski §4 (Bileşen
  notları) → §13'e, eski §5 (KARAR) → §14'e kaydı; palet/tipografi/imza
  öğesi (§1-3) DEĞİŞMEDİ, altın ekonomisi kuralı tüm yeni örüntülerde
  korundu (gold yalnız hero rayı + AppBar çizgisi + ürün kartı hover'ında
  kalmaya devam ediyor).
- **v1.2** (2026-08-30): Editoryal ürün ızgarası turu (kullanıcı isteği:
  COS/Ferm Living/KITH referanslı yeniden tasarım). **KARAR (kullanıcı
  onaylı):** palet/tipografi (§1-2) DEĞİŞMEDİ — yalnız YAPISAL kalıplar
  yenilendi: §15 — `ProductGrid` (kesin 1/`sm`:2/`lg`:4 kolon, `space.xxl`
  gap, kolon kararı viewport genişliğine göre sayfa seviyesinde verilir),
  `ProductCard` (kesin 3:4 görsel oranı, hover'da ikinci-görsel-takas YERİNE
  hafif zoom — veri modelinde ikinci görsel yok, uydurulmadı —, dokunmatikte
  DAİMA görünen quick-add barı, renk swatch'ları YOK — varyant modeli
  sistemde hiç yok), `FilterSidebar` (256px, yalnız `lg`, dar ekranda mevcut
  yatay chip şeridi korunur, gerçek CSS sticky değil ikiz-scroll deseni).
  Kart hover'ının gold kenarlık/gölge/kalkma imzası (v1.1) DEĞİŞMEDİ. Eski
  §14 (KARAR) → §16'ya kaydı (yeni §15 aralarına eklendiği için).
