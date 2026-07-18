/// Liste Gir çıkarma algoritmasının ürettiği, önizleme ızgarasında
/// düzenlenebilen tek bir satır. Satış Fiyatı kaynak belgede hiç yok —
/// tamamen kullanıcı girişi.
class ExtractedRow {
  String barcode;
  String name;
  num quantity;
  num purchasePrice;
  num salePrice;

  /// Barkod sistemde zaten kayıtlıysa eşleşen ürünün id'si (birleştirme
  /// önizlemesi + kaydetme adımı için).
  String? existingProductId;
  num? existingStock;

  ExtractedRow({
    this.barcode = '',
    this.name = '',
    this.quantity = 0,
    this.purchasePrice = 0,
    this.salePrice = 0,
    this.existingProductId,
    this.existingStock,
  });

  bool get isEmpty => barcode.isEmpty && name.isEmpty && quantity == 0;
}
