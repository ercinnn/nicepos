/// Tek bir raf etiketi hanesi (A4 ızgarasında 1..24). Barkod okutulup çözülünce
/// ürün adı + satış fiyatı (`price1`) doldurulur; oluşturma tarihi baskıda köşede
/// gösterilir (KARAR v1.10). Boş hane = `null` slot (bkz. LabelSheetState).
class LabelSlot {
  final String barcode;
  final String productName;
  final num price;
  final DateTime createdAt;

  const LabelSlot({
    required this.barcode,
    required this.productName,
    required this.price,
    required this.createdAt,
  });

  LabelSlot copyWith({
    String? barcode,
    String? productName,
    num? price,
    DateTime? createdAt,
  }) {
    return LabelSlot(
      barcode: barcode ?? this.barcode,
      productName: productName ?? this.productName,
      price: price ?? this.price,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// Poster sekmesi (KARAR v1.23) A4 sayfa başına en çok satır sayısı — bunun
/// üzeri 2., 3. sayfaya taşar (Ürün Etiketi'nin çok-sayfalı deseniyle aynı).
const int kPosterItemsPerPage = 20;

/// Poster kalemlerini (`LabelSlot` — barkod/ad/fiyat) sayfalara böler; her
/// sayfa en çok [kPosterItemsPerPage] satır tutar. Üç çıktı (önizleme = HTML =
/// PDF) bu tek fonksiyonu paylaşır → taşma mantığı BİREBİR aynıdır. Kalem
/// yoksa tek boş liste döner (önizleme "henüz ürün yok" durumunu gösterir).
List<List<LabelSlot>> paginatePosterItems(List<LabelSlot> items) {
  if (items.isEmpty) return [const []];
  final pages = <List<LabelSlot>>[];
  for (var start = 0; start < items.length; start += kPosterItemsPerPage) {
    final end = (start + kPosterItemsPerPage < items.length)
        ? start + kPosterItemsPerPage
        : items.length;
    pages.add(items.sublist(start, end));
  }
  return pages;
}
