/// `discount_recommendations` RPC'sinin (0051 migration — bkz. dosyadaki
/// metodoloji notu) tek satırı — bir ürün için veri-temelli (geçmiş fiyat/adet
/// ilişkisinden log-log regresyonla fit edilmiş) indirim değerlendirmesi.
///
/// v1'in (0050) aksine ARTIK yalnız "önerilen" ürünler değil, eşiği geçemeyen
/// ürünler de `status` ile etiketlenip döner (bkz. Analiz sayfası "İndirim
/// Önerileri" sekmesi — ana liste + "Diğer Ürünler" ikincil bölüm).
enum DiscountRecommendationStatus {
  recommended,
  noSafeDiscount,
  notBeneficial,
  insufficientData;

  static DiscountRecommendationStatus fromDb(String? value) {
    switch (value) {
      case 'recommended':
        return DiscountRecommendationStatus.recommended;
      case 'no_safe_discount':
        return DiscountRecommendationStatus.noSafeDiscount;
      case 'not_beneficial':
        return DiscountRecommendationStatus.notBeneficial;
      default:
        return DiscountRecommendationStatus.insufficientData;
    }
  }
}

/// Esneklik tahmininin dayandığı kaynak — bkz. 0051 migration "partial
/// pooling" notu: `own` ürünün kendi geçmişi, `group` yeterli kendi verisi
/// olmayan ürünler için aynı ürün grubundaki diğer ürünlerden ödünç alınan
/// tahmin.
enum DiscountRecommendationSource {
  own,
  group,
  none;

  static DiscountRecommendationSource fromDb(String? value) {
    switch (value) {
      case 'own':
        return DiscountRecommendationSource.own;
      case 'group':
        return DiscountRecommendationSource.group;
      default:
        return DiscountRecommendationSource.none;
    }
  }
}

class DiscountRecommendation {
  final String productId;
  final String? equivalentGroupId;
  final String? barcode;
  final String name;
  final num price1;
  final DiscountRecommendationStatus status;
  final DiscountRecommendationSource source;
  final String? confidence; // 'yuksek' | 'orta' | 'dusuk' | null
  final int sampleCount;
  final int pricePoints;
  final num? rSquared;
  final num? elasticity;
  final num avgDailyQuantity;
  final num historicalMinPrice;
  final num historicalMaxPrice;
  final int? recommendedDiscountPercent;
  final num? recommendedPrice;
  final num? currentEstDailyRevenue;
  final num? recommendedEstDailyRevenue;
  final num? revenueIncreasePercent;

  const DiscountRecommendation({
    required this.productId,
    this.equivalentGroupId,
    this.barcode,
    required this.name,
    required this.price1,
    required this.status,
    required this.source,
    this.confidence,
    required this.sampleCount,
    required this.pricePoints,
    this.rSquared,
    this.elasticity,
    required this.avgDailyQuantity,
    required this.historicalMinPrice,
    required this.historicalMaxPrice,
    this.recommendedDiscountPercent,
    this.recommendedPrice,
    this.currentEstDailyRevenue,
    this.recommendedEstDailyRevenue,
    this.revenueIncreasePercent,
  });

  factory DiscountRecommendation.fromMap(Map<String, dynamic> map) {
    return DiscountRecommendation(
      productId: map['product_id'] as String,
      equivalentGroupId: map['equivalent_group_id'] as String?,
      barcode: map['barcode'] as String?,
      name: map['name'] as String? ?? '',
      price1: map['price1'] as num? ?? 0,
      status: DiscountRecommendationStatus.fromDb(map['status'] as String?),
      source: DiscountRecommendationSource.fromDb(map['source'] as String?),
      confidence: map['confidence'] as String?,
      sampleCount: (map['sample_count'] as num?)?.toInt() ?? 0,
      pricePoints: (map['price_points'] as num?)?.toInt() ?? 0,
      rSquared: map['r_squared'] as num?,
      elasticity: map['elasticity'] as num?,
      avgDailyQuantity: map['avg_daily_quantity'] as num? ?? 0,
      historicalMinPrice: map['historical_min_price'] as num? ?? 0,
      historicalMaxPrice: map['historical_max_price'] as num? ?? 0,
      recommendedDiscountPercent:
          (map['recommended_discount_percent'] as num?)?.toInt(),
      recommendedPrice: map['recommended_price'] as num?,
      currentEstDailyRevenue: map['current_est_daily_revenue'] as num?,
      recommendedEstDailyRevenue: map['recommended_est_daily_revenue'] as num?,
      revenueIncreasePercent: map['revenue_increase_percent'] as num?,
    );
  }

  bool get isRecommended => status == DiscountRecommendationStatus.recommended;

  /// Kullanıcıya gösterilecek kısa gerekçe — yalnız `isRecommended == false`
  /// iken anlamlıdır ("Diğer Ürünler" bölümü).
  String get reasonLabel {
    switch (status) {
      case DiscountRecommendationStatus.recommended:
        return '';
      case DiscountRecommendationStatus.noSafeDiscount:
        return 'İndirim işe yarar görünüyor ama bu ürün geçmişte hiç bu kadar '
            'düşük fiyattan satılmadığından güvenle bir oran önerilemiyor.';
      case DiscountRecommendationStatus.notBeneficial:
        return 'Bu üründe talep fiyata yeterince duyarlı değil — indirim '
            'modele göre ciroyu artırmaz.';
      case DiscountRecommendationStatus.insufficientData:
        return 'Ne bu ürünün ne de kategorisinin geçmişinde yeterli fiyat '
            'çeşitliliği var — güvenilir bir tahmin üretilemiyor.';
    }
  }
}
