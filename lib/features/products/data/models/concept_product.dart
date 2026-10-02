import '../../../sales/data/models/cart_item.dart' show DiscountType;
import 'product.dart';

export '../../../sales/data/models/cart_item.dart' show DiscountType;

/// Konsept ürün — birden çok parçadan oluşan, tek barkodla satılan set
/// (ör. 1× vazo + 2× papatya + 5× okaliptus). Kendi stoku YOKTUR; satışta
/// parçalara açılır, stok parçalardan düşer (bkz. 0067_concept_products.sql).
class ConceptProduct {
  final String id;
  final String barcode;
  final String name;

  /// ESKİ (0067) konsept geneli fiyat — 0069'dan beri form bunu yazmaz
  /// (NULL kaydeder), indirim parça bazındadır. Hiç parça indirimi olmayan
  /// eski bir konseptte satışta hâlâ geçerlidir (fark tüm parçalara dağılır).
  final num? price;
  final List<ConceptProductItem> items;
  final DateTime? createdAt;

  const ConceptProduct({
    required this.id,
    required this.barcode,
    required this.name,
    this.price,
    this.items = const [],
    this.createdAt,
  });

  /// Parçaların indirimsiz Fiyat1 × adet toplamı.
  num get componentsTotal => items.fold<num>(0, (sum, i) => sum + i.grossTotal);

  /// En az bir parçada indirim tanımlı mı (0069 parça bazlı indirim).
  bool get hasItemDiscounts => items.any((i) => i.discountValue > 0);

  /// Satışta sepete yansıyacak tutar: parça indirimleri varsa onlardan
  /// hesaplanır, yoksa eski konsept fiyatı, o da yoksa parça toplamı.
  num get effectivePrice => hasItemDiscounts
      ? items.fold<num>(0, (sum, i) => sum + i.netTotal)
      : (price ?? componentsTotal);

  /// Etiket ekranı için ürün görünümü — tüm etiket sekmeleri `Product`
  /// üzerinden çalıştığından konsept, adı + barkodu + satış fiyatıyla bir
  /// ürün gibi basılır. `id` konseptin id'sidir (products'ta YOKTUR — stok/
  /// ürün tablosuna yazan hiçbir akışa verilmemeli).
  Product asLabelProduct() => Product(
        id: id,
        barcode: barcode,
        name: name,
        price1: effectivePrice,
      );

  factory ConceptProduct.fromMap(Map<String, dynamic> map) {
    final rawItems = map['concept_product_items'] as List? ?? const [];
    final items = rawItems
        .map((r) => ConceptProductItem.fromMap(Map<String, dynamic>.from(r as Map)))
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return ConceptProduct(
      id: map['id'] as String,
      barcode: map['barcode'] as String,
      name: map['name'] as String,
      price: map['price'] as num?,
      items: items,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String)
          : null,
    );
  }
}

class ConceptProductItem {
  final String productId;
  final num quantity;
  final int sortOrder;

  /// Parça bazlı indirim (0069): % ise yüzde, ₺ ise bu parça SATIRININ
  /// (konsept içindeki adetin tamamı) toplam indirim tutarı. 0 → indirim yok.
  final num discountValue;
  final DiscountType discountType;

  /// `products(*)` embed'iyle gelir; ürün okunamazsa null.
  final Product? product;

  const ConceptProductItem({
    required this.productId,
    required this.quantity,
    this.sortOrder = 0,
    this.discountValue = 0,
    this.discountType = DiscountType.percent,
    this.product,
  });

  num get grossTotal => (product?.price1 ?? 0) * quantity;

  /// TL cinsinden indirim — `CartItem.discountAmount` ile birebir aynı kural.
  num get discountAmount => discountType == DiscountType.percent
      ? grossTotal * discountValue / 100
      : discountValue.clamp(0, grossTotal);

  num get netTotal => grossTotal - discountAmount;

  factory ConceptProductItem.fromMap(Map<String, dynamic> map) {
    final rawProduct = map['products'];
    return ConceptProductItem(
      productId: map['product_id'] as String,
      quantity: map['quantity'] as num? ?? 1,
      sortOrder: map['sort_order'] as int? ?? 0,
      discountValue: map['discount_value'] as num? ?? 0,
      discountType: map['discount_type'] == 'tl' ? DiscountType.tl : DiscountType.percent,
      product: rawProduct is Map
          ? Product.fromMap(Map<String, dynamic>.from(rawProduct))
          : null,
    );
  }

  ConceptProductItem copyWith({
    num? quantity,
    num? discountValue,
    DiscountType? discountType,
    Product? product,
  }) {
    return ConceptProductItem(
      productId: productId,
      quantity: quantity ?? this.quantity,
      sortOrder: sortOrder,
      discountValue: discountValue ?? this.discountValue,
      discountType: discountType ?? this.discountType,
      product: product ?? this.product,
    );
  }
}

/// Konsept barkodu biçimi: C + YYAAGG + 3 haneli sıra (ör. C261002001).
final _conceptBarcodePattern = RegExp(r'^[Cc]\d{9}$');

bool looksLikeConceptBarcode(String value) =>
    _conceptBarcodePattern.hasMatch(value.trim());

/// Bugünün konsept barkodu öneki — "C" + YYAAGG (ör. C261002).
String conceptBarcodePrefix(DateTime now) =>
    'C${(now.year % 100).toString().padLeft(2, '0')}'
    '${now.month.toString().padLeft(2, '0')}'
    '${now.day.toString().padLeft(2, '0')}';
