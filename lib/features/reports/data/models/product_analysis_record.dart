/// Ürün Analizi (Raporlar 5. sekme) — `product_analysis(p_start, p_end)` RPC'sinin
/// tek satırı. Eşlenik barkod grubu varsa TEK birim olarak temsil eder
/// (bkz. `product_analysis` migration'ı, KARAR: 0021/0023 ile aynı gruplama).
class ProductAnalysisRecord {
  final String productId;
  final String? equivalentGroupId;
  final int memberCount;
  final String? barcode;
  final String name;
  final String unit;
  final num stockQuantity;
  final num purchasePrice;
  final num price1;
  final num revenueInPeriod;
  final num quantitySoldInPeriod;
  final DateTime? lastSaleDate; // null = hiç satılmadı

  const ProductAnalysisRecord({
    required this.productId,
    required this.equivalentGroupId,
    required this.memberCount,
    required this.barcode,
    required this.name,
    required this.unit,
    required this.stockQuantity,
    required this.purchasePrice,
    required this.price1,
    required this.revenueInPeriod,
    required this.quantitySoldInPeriod,
    required this.lastSaleDate,
  });

  num get stockValue => stockQuantity * purchasePrice;

  int? get daysSinceLastSale =>
      lastSaleDate == null ? null : DateTime.now().difference(lastSaleDate!).inDays;

  /// Hiç satılmayan ürün sonsuz durağan sayılır.
  bool isStagnant(int thresholdDays) {
    final days = daysSinceLastSale;
    return days == null || days >= thresholdDays;
  }

  factory ProductAnalysisRecord.fromMap(Map<String, dynamic> map) => ProductAnalysisRecord(
        productId: map['product_id'] as String,
        equivalentGroupId: map['equivalent_group_id'] as String?,
        memberCount: (map['member_count'] as num?)?.toInt() ?? 1,
        barcode: map['barcode'] as String?,
        name: (map['name'] as String?) ?? '-',
        unit: map['unit'] as String? ?? 'Adet',
        stockQuantity: map['stock_quantity'] as num? ?? 0,
        purchasePrice: map['purchase_price'] as num? ?? 0,
        price1: map['price1'] as num? ?? 0,
        revenueInPeriod: map['revenue_in_period'] as num? ?? 0,
        quantitySoldInPeriod: map['quantity_sold_in_period'] as num? ?? 0,
        lastSaleDate: map['last_sale_date'] == null
            ? null
            : DateTime.parse(map['last_sale_date'] as String).toLocal(),
      );
}
