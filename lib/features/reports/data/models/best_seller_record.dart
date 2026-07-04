/// En Çok Satanlar raporu satır modeli.
///
/// Bir ürünün seçili tarih aralığındaki toplam satış adedini, güncel birim
/// fiyatını (`price1`) ve en son satış tarihini taşır. Toplam gelir alanı YOK —
/// adet × fiyat türevi olduğu için gereksiz (design-tokens §5, KARAR v1.6).
class BestSellerRecord {
  final String productId;
  final String name;
  final String? barcode;
  final num price1; // Ürünün güncel satış fiyatı (products.price1)
  final num quantity; // Seçili aralıkta satılan toplam miktar (Σ quantity)
  final DateTime lastSaleDate; // En son satış tarihi (max sale_date, yerel saat)

  const BestSellerRecord({
    required this.productId,
    required this.name,
    this.barcode,
    required this.price1,
    required this.quantity,
    required this.lastSaleDate,
  });
}
