/// Eşlenik Barkod grubu için okuma-anında hesaplanan toplamlar.
///
/// `product_equivalent_aggregate` view'ından (bkz. 0021_equivalent_barcodes.sql)
/// gelir — ham `products` satırları HİÇ değişmez, bu sadece bir grubun stok
/// toplamını ve "en son güncellenen satırın esas alınan" fiyat/KDV bilgilerini
/// okuma anında birleştirir.
class EquivalentAggregate {
  final num totalStock;
  final int memberCount;
  final String latestProductId;
  final num groupPrice1;
  final num groupPrice2;
  final num groupPurchasePrice;
  final num groupVatRate;

  const EquivalentAggregate({
    required this.totalStock,
    required this.memberCount,
    required this.latestProductId,
    required this.groupPrice1,
    required this.groupPrice2,
    required this.groupPurchasePrice,
    required this.groupVatRate,
  });

  factory EquivalentAggregate.fromMap(Map<String, dynamic> map) => EquivalentAggregate(
        totalStock: map['total_stock'] as num? ?? 0,
        memberCount: (map['member_count'] as num?)?.toInt() ?? 0,
        latestProductId: map['latest_product_id'] as String? ?? '',
        groupPrice1: map['group_price1'] as num? ?? 0,
        groupPrice2: map['group_price2'] as num? ?? 0,
        groupPurchasePrice: map['group_purchase_price'] as num? ?? 0,
        groupVatRate: map['group_vat_rate'] as num? ?? 0,
      );
}
