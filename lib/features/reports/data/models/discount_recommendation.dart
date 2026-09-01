/// `discount_recommendations` RPC'sinin (0050 migration) tek satırı — bir
/// ürün için veri-temelli (geçmiş fiyat/adet ilişkisinden log-log regresyonla
/// fit edilmiş) indirim önerisi. Yalnız fiyat esnekliği b < -1 (indirim
/// ciroyu artırır) VE yeterli örnek/fiyat çeşitliliği/uyum (R²) olan ürünler
/// döner — bkz. Analiz sayfası "İndirim Önerileri" sekmesi.
class DiscountRecommendation {
  final String productId;
  final String? equivalentGroupId;
  final String? barcode;
  final String name;
  final num price1;
  final int sampleCount;
  final int pricePoints;
  final num rSquared;
  final num elasticity;
  final num avgDailyQuantity;
  final num historicalMinPrice;
  final num historicalMaxPrice;
  final int recommendedDiscountPercent;
  final num recommendedPrice;
  final num currentEstDailyRevenue;
  final num recommendedEstDailyRevenue;
  final num revenueIncreasePercent;

  const DiscountRecommendation({
    required this.productId,
    this.equivalentGroupId,
    this.barcode,
    required this.name,
    required this.price1,
    required this.sampleCount,
    required this.pricePoints,
    required this.rSquared,
    required this.elasticity,
    required this.avgDailyQuantity,
    required this.historicalMinPrice,
    required this.historicalMaxPrice,
    required this.recommendedDiscountPercent,
    required this.recommendedPrice,
    required this.currentEstDailyRevenue,
    required this.recommendedEstDailyRevenue,
    required this.revenueIncreasePercent,
  });

  factory DiscountRecommendation.fromMap(Map<String, dynamic> map) {
    return DiscountRecommendation(
      productId: map['product_id'] as String,
      equivalentGroupId: map['equivalent_group_id'] as String?,
      barcode: map['barcode'] as String?,
      name: map['name'] as String? ?? '',
      price1: map['price1'] as num? ?? 0,
      sampleCount: (map['sample_count'] as num?)?.toInt() ?? 0,
      pricePoints: (map['price_points'] as num?)?.toInt() ?? 0,
      rSquared: map['r_squared'] as num? ?? 0,
      elasticity: map['elasticity'] as num? ?? 0,
      avgDailyQuantity: map['avg_daily_quantity'] as num? ?? 0,
      historicalMinPrice: map['historical_min_price'] as num? ?? 0,
      historicalMaxPrice: map['historical_max_price'] as num? ?? 0,
      recommendedDiscountPercent:
          (map['recommended_discount_percent'] as num?)?.toInt() ?? 0,
      recommendedPrice: map['recommended_price'] as num? ?? 0,
      currentEstDailyRevenue: map['current_est_daily_revenue'] as num? ?? 0,
      recommendedEstDailyRevenue:
          map['recommended_est_daily_revenue'] as num? ?? 0,
      revenueIncreasePercent: map['revenue_increase_percent'] as num? ?? 0,
    );
  }

  /// Güven rozetinin dayanağı — yalnız görüntüleme için basit bir eşik.
  bool get isHighConfidence => rSquared >= 0.5 && sampleCount >= 20;
}
