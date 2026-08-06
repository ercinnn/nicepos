// `online_products` view'ından (nicepos/supabase/migrations/0028_online_satis.sql)
// okunur — yalnız public-safe sütunlar, alım fiyatı/kritik stok gibi iç veriler
// bu view'da zaten yok.
class StoreProduct {
  final String id;
  final String name;
  final String? barcode;
  final String? stockCode;
  final String unit;
  final num price;
  final num vatRate;
  final String? imageUrl;
  final String? description;
  final num? weight;
  final String? groupId;
  final bool inStock;

  const StoreProduct({
    required this.id,
    required this.name,
    this.barcode,
    this.stockCode,
    this.unit = 'Adet',
    this.price = 0,
    this.vatRate = 20,
    this.imageUrl,
    this.description,
    this.weight,
    this.groupId,
    this.inStock = true,
  });

  factory StoreProduct.fromMap(Map<String, dynamic> map) {
    return StoreProduct(
      id: map['id'] as String,
      name: map['name'] as String? ?? '',
      barcode: map['barcode'] as String?,
      stockCode: map['stock_code'] as String?,
      unit: map['unit'] as String? ?? 'Adet',
      price: (map['price'] as num?) ?? 0,
      vatRate: (map['vat_rate'] as num?) ?? 20,
      imageUrl: map['image_url'] as String?,
      description: map['description'] as String?,
      weight: map['weight'] as num?,
      groupId: map['group_id'] as String?,
      inStock: map['in_stock'] as bool? ?? true,
    );
  }
}
