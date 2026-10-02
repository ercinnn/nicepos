import 'product.dart';

/// Konsept ürün — birden çok parçadan oluşan, tek barkodla satılan set
/// (ör. 1× vazo + 2× papatya + 5× okaliptus). Kendi stoku YOKTUR; satışta
/// parçalara açılır, stok parçalardan düşer (bkz. 0067_concept_products.sql).
class ConceptProduct {
  final String id;
  final String barcode;
  final String name;

  /// Konseptin satış fiyatı. null → parçaların Fiyat1 toplamı geçerli.
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

  /// Parçaların Fiyat1 × adet toplamı (konsept fiyatı yokken satış fiyatı).
  num get componentsTotal =>
      items.fold<num>(0, (sum, i) => sum + (i.product?.price1 ?? 0) * i.quantity);

  /// Satışta sepete yansıyacak tutar.
  num get effectivePrice => price ?? componentsTotal;

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

  /// `products(*)` embed'iyle gelir; ürün okunamazsa null.
  final Product? product;

  const ConceptProductItem({
    required this.productId,
    required this.quantity,
    this.sortOrder = 0,
    this.product,
  });

  factory ConceptProductItem.fromMap(Map<String, dynamic> map) {
    final rawProduct = map['products'];
    return ConceptProductItem(
      productId: map['product_id'] as String,
      quantity: map['quantity'] as num? ?? 1,
      sortOrder: map['sort_order'] as int? ?? 0,
      product: rawProduct is Map
          ? Product.fromMap(Map<String, dynamic>.from(rawProduct))
          : null,
    );
  }

  ConceptProductItem copyWith({num? quantity, Product? product}) {
    return ConceptProductItem(
      productId: productId,
      quantity: quantity ?? this.quantity,
      sortOrder: sortOrder,
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
