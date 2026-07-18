/// Liste Gir çıkarma algoritmasının ürettiği, önizleme ızgarasında
/// düzenlenebilen tek bir satır. Satış Fiyatı kaynak belgede hiç yok —
/// tamamen kullanıcı girişi.
class ExtractedRow {
  String barcode;
  String name;
  num quantity;
  num purchasePrice;
  num salePrice;

  /// Listeden çıkarılan HAM alış fiyatı (çarpan uygulanmadan önceki hali).
  /// Kaynak listedeki fiyat gerçek alış fiyatından farklı olabilir (iskonto/
  /// +KDV) — kullanıcı önizleme ızgarasında bir çarpan girdiğinde
  /// `purchasePrice = rawPurchasePrice * çarpan` olarak yeniden hesaplanır.
  /// Çarpan değişse bile ham değer kaybolmasın diye ayrı tutulur.
  num rawPurchasePrice;

  /// Barkod sistemde zaten kayıtlıysa eşleşen ürünün id'si (birleştirme
  /// önizlemesi + kaydetme adımı için).
  String? existingProductId;
  num? existingStock;

  ExtractedRow({
    this.barcode = '',
    this.name = '',
    this.quantity = 0,
    this.purchasePrice = 0,
    num? rawPurchasePrice,
    this.salePrice = 0,
    this.existingProductId,
    this.existingStock,
  }) : rawPurchasePrice = rawPurchasePrice ?? purchasePrice;

  bool get isEmpty => barcode.isEmpty && name.isEmpty && quantity == 0;
}
