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

## 4. Bileşen notları

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
- **Sayfa geçişleri**: tüm `go_router` rotaları `_fadeThroughPage` kullanır
  (240ms giriş / 180ms çıkış, `Curves.easeOutCubic`, hafif yukarı kayma +
  fade) — ana uygulamanın `router.dart` `_fadeThroughPage`'iyle BİREBİR aynı
  eğri/süre (iki ayrı Flutter projesi olsa da marka geçiş hissi tutarlı
  kalsın diye kasıtlı kopya).

## 5. KARAR Geçmişi

- **v1.0** (2026-08-07): İlk kuruluş. Hero banner + footer + Space
  Grotesk/Inter tipografik çift + AppBar altın çizgisi + ürün kartı hover +
  sayfa geçiş animasyonu (fade-through). Kategori şeridi yatay
  `ListView`'dan `Wrap`'e çevrildi (200+ kategori taşma sorunu).
