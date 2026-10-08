// Ürün Etiketi (KARAR v1.21) — adet-tabanlı, FİYATSIZ/LOGOSUZ barkod etiketi.
// Diğer etiket sekmelerinden (Yeni/Geniş/Büyük) iki temel farkı: (1) etkileşim
// adet-tabanlıdır (numaralı hane değil), (2) fiyat ve logo YOKTUR. Saf ürün/stok
// barkod etiketi.
//
// A4 baskı geometrisi (KİLİTLİ, kullanıcı ölçüleri): 6 sütun × 12 satır = 72
// etiket/sayfa. Hücre 35×23mm, her kenardan 3mm iç pay → içerik 29×17mm.

/// A4 sayfada Ürün Etiketi ızgara sabitleri (6 sütun × 12 satır = 72/sayfa).
const int kProductLabelCols = 6;
const int kProductLabelRows = 12;
const int kProductLabelPerPage = kProductLabelCols * kProductLabelRows; // 72

/// Uzun Ürün Etiketi ızgara sabitleri — A4 DİKEY, 2 sütun × 17 satır = 34/sayfa.
/// Aynı `ProductLabelItem` modelini kullanır (fiyatsız/logosuz). Hücre
/// 105 × 15.83mm; yan boşluk 0, üst/alt boşluk kalan yükseklikten ortalanır.
const int kLongProductLabelCols = 2;
const int kLongProductLabelRows = 17;
const int kLongProductLabelPerPage =
    kLongProductLabelCols * kLongProductLabelRows; // 34

/// Uzun Ürün Etiketi hücre ölçüleri (mm). Yükseklik eski yatay 2×12 düzeniyle
/// BİREBİR aynı (190mm / 12 ≈ 15.83); genişlik dikey A4'ün yarısı (210 / 2).
const double kLongLabelCellWidthMm = 105;
const double kLongLabelCellHeightMm = 190 / 12;

/// Dikey A4 (297mm) üst/alt sayfa boşluğu — 17 satır ortalanır (≈13.92mm).
const double kLongLabelPageMarginVMm =
    (297 - kLongProductLabelRows * kLongLabelCellHeightMm) / 2;

/// Uzun Ürün Etiketi hücre-içi yatay yerleşim (mm) — önizleme · HTML · PDF
/// BİREBİR paylaşır. Hücre 105mm = 5 (sol boşluk) + 48 (ad sütunu, SABİT,
/// 20 karakterlik satıra göre) + 5 (ara) + 42 (barkod, kalan) + 5 (sağ
/// boşluk) — kullanıcı kararı. Ad sütunu sabit olduğu için tüm etiketlerde
/// barkodlar aynı hizada başlar. 5mm kenar/ara, Code128 quiet zone'u karşılar.
const double kLongLabelSideMarginMm = 5;
const double kLongLabelNameWidthMm = 48;
const double kLongLabelGapMm = 5;

/// Barkod genişliği (mm) — kalan genişlikten türetilir (= 42).
const double kLongLabelBarcodeWidthMm = kLongLabelCellWidthMm -
    2 * kLongLabelSideMarginMm -
    kLongLabelNameWidthMm -
    kLongLabelGapMm;

/// Uzun Ürün Etiketi barkod numarası punto (pt) — üç çıktı paylaşır (önizleme
/// px'e çevirir: pt × 96/72). İç yükseklik 12.83mm − barkod 8mm → numaraya
/// ~4.8mm kalır; 10pt (satır ≈4.2mm) sığan en büyük değere yakın.
const double kLongLabelBarcodeNoPt = 10;

/// Uzun Ürün Etiketi'nde ürün adının satır başına en fazla karakter sayısı.
const int kLongProductNameLineChars = 20;

/// Uzun Ürün Etiketi'nde ürün adının en fazla satır sayısı (20'şer karakterle
/// 3 satır ≈ 60 karakter; 15.83mm hücreye 9pt'de sığar).
const int kLongProductNameMaxLines = 3;

/// Ürün adını (büyük harfe çevirip) satır başına en fazla [maxChars] karakter
/// olacak şekilde KELİME bölmeden satırlara ayırır. Sığmayan kelime bir alt
/// satıra geçer (satır 20'den kısa kalsa bile); tek başına [maxChars]'tan uzun
/// bir kelime bölünmez, kendi satırında durur. Uzun Ürün Etiketi'nin üç çıktısı
/// (önizleme · HTML · PDF) bu TEK fonksiyonu paylaşır → satır kırılımları
/// birebir aynıdır.
List<String> wrapLongProductName(
  String name, {
  int maxChars = kLongProductNameLineChars,
}) {
  final words = name
      .toUpperCase()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty);
  final lines = <String>[];
  var current = '';
  for (final word in words) {
    if (current.isEmpty) {
      current = word;
    } else if (current.length + 1 + word.length <= maxChars) {
      current = '$current $word';
    } else {
      lines.add(current);
      current = word;
    }
  }
  if (current.isNotEmpty) lines.add(current);
  return lines;
}

/// Ürün Etiketi kalemi: bir ürünün (barkod + ad) belirli ADET etiketi. Fiyat ve
/// logo tutulmaz (bu sekmede yok). Adet kadar çoğaltılıp 72'lik ızgaraya dizilir.
class ProductLabelItem {
  final String barcode;
  final String productName;
  final int quantity;

  const ProductLabelItem({
    required this.barcode,
    required this.productName,
    required this.quantity,
  });

  ProductLabelItem copyWith({
    String? barcode,
    String? productName,
    int? quantity,
  }) {
    return ProductLabelItem(
      barcode: barcode ?? this.barcode,
      productName: productName ?? this.productName,
      quantity: quantity ?? this.quantity,
    );
  }
}

/// Kalemleri adet kadar çoğaltıp 72'lik sayfalara böler (her sayfa tam 72 slot;
/// `null` = boş hücre). Toplam > 72 ise 2., 3. sayfaya taşar (çok-sayfalı
/// önizleme + çok-sayfalı PDF/HTML). Kalem yoksa tek boş sayfa döner (önizleme
/// için). Üç çıktı (önizleme = HTML = PDF) bu tek fonksiyonu paylaşır → taşma
/// mantığı BİREBİR aynıdır. [perPage] — Uzun Ürün Etiketi için
/// `kLongProductLabelPerPage` (34) geçilir; varsayılan Ürün Etiketi'nin 72'si.
List<List<ProductLabelItem?>> paginateProductLabels(
  List<ProductLabelItem> items, {
  int perPage = kProductLabelPerPage,
}) {
  final flat = <ProductLabelItem>[];
  for (final it in items) {
    for (var i = 0; i < it.quantity; i++) {
      flat.add(it);
    }
  }
  if (flat.isEmpty) {
    return [List<ProductLabelItem?>.filled(perPage, null)];
  }
  final pages = <List<ProductLabelItem?>>[];
  for (var start = 0; start < flat.length; start += perPage) {
    final page = List<ProductLabelItem?>.filled(perPage, null);
    for (var i = 0;
        i < perPage && start + i < flat.length;
        i++) {
      page[i] = flat[start + i];
    }
    pages.add(page);
  }
  return pages;
}
