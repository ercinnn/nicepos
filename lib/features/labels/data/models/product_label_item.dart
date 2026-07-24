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
/// mantığı BİREBİR aynıdır.
List<List<ProductLabelItem?>> paginateProductLabels(
  List<ProductLabelItem> items,
) {
  final flat = <ProductLabelItem>[];
  for (final it in items) {
    for (var i = 0; i < it.quantity; i++) {
      flat.add(it);
    }
  }
  if (flat.isEmpty) {
    return [List<ProductLabelItem?>.filled(kProductLabelPerPage, null)];
  }
  final pages = <List<ProductLabelItem?>>[];
  for (var start = 0; start < flat.length; start += kProductLabelPerPage) {
    final page = List<ProductLabelItem?>.filled(kProductLabelPerPage, null);
    for (var i = 0;
        i < kProductLabelPerPage && start + i < flat.length;
        i++) {
      page[i] = flat[start + i];
    }
    pages.add(page);
  }
  return pages;
}
