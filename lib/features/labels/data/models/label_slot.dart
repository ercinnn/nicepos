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
