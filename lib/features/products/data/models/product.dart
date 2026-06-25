class Product {
  final String id;
  final String? barcode;
  final String name;
  final String? stockCode;
  final String? groupId;
  final String? groupName;
  final String? parentGroupName;
  final String unit;
  final String? originCountry;
  final num stockQuantity;
  final num criticalStock;
  final num purchasePrice;
  final bool purchasePriceVatIncluded;
  final num price1;
  final bool price1VatIncluded;
  final num price2;
  final bool price2VatIncluded;
  final num vatRate;
  final num? weight;
  final String? description;
  final String? imageUrl;
  final int? quickListOrder;
  final bool isOnlineActive;

  const Product({
    this.id = '',
    this.barcode,
    required this.name,
    this.stockCode,
    this.groupId,
    this.groupName,
    this.parentGroupName,
    this.unit = 'Adet',
    this.originCountry,
    this.stockQuantity = 0,
    this.criticalStock = 0,
    this.purchasePrice = 0,
    this.purchasePriceVatIncluded = true,
    this.price1 = 0,
    this.price1VatIncluded = true,
    this.price2 = 0,
    this.price2VatIncluded = true,
    this.vatRate = 20,
    this.weight,
    this.description,
    this.imageUrl,
    this.quickListOrder,
    this.isOnlineActive = false,
  });

  double get profitMargin1 {
    if (purchasePrice == 0) return 0;
    return ((price1 - purchasePrice) / purchasePrice) * 100;
  }

  double get profitMargin2 {
    if (purchasePrice == 0) return 0;
    return ((price2 - purchasePrice) / purchasePrice) * 100;
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    final rawGroup = map['product_groups'];
    final Map<String, dynamic>? group = rawGroup is Map
        ? Map<String, dynamic>.from(rawGroup)
        : rawGroup is List && rawGroup.isNotEmpty
            ? Map<String, dynamic>.from(rawGroup.first as Map)
            : null;
    return Product(
      id: map['id'] as String,
      barcode: map['barcode'] as String?,
      name: map['name'] as String,
      stockCode: map['stock_code'] as String?,
      groupId: map['group_id'] as String?,
      groupName: group?['name'] as String? ?? map['group_name'] as String?,
      parentGroupName: (group?['parent_group'] is Map)
          ? (group!['parent_group'] as Map)['name'] as String?
          : null,
      unit: map['unit'] as String? ?? 'Adet',
      originCountry: map['origin_country'] as String?,
      stockQuantity: map['stock_quantity'] as num? ?? 0,
      criticalStock: map['critical_stock'] as num? ?? 0,
      purchasePrice: map['purchase_price'] as num? ?? 0,
      purchasePriceVatIncluded: map['purchase_price_vat_included'] as bool? ?? true,
      price1: map['price1'] as num? ?? 0,
      price1VatIncluded: map['price1_vat_included'] as bool? ?? true,
      price2: map['price2'] as num? ?? 0,
      price2VatIncluded: map['price2_vat_included'] as bool? ?? true,
      vatRate: map['vat_rate'] as num? ?? 20,
      weight: map['weight'] as num?,
      description: map['description'] as String?,
      imageUrl: map['image_url'] as String?,
      quickListOrder: (map['quick_list_order'] as num?)?.toInt(),
      isOnlineActive: map['is_online_active'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toInsertMap() {
    return {
      'barcode': (barcode == null || barcode!.isEmpty) ? null : barcode,
      'name': name,
      'stock_code': stockCode,
      'group_id': groupId,
      'unit': unit,
      'origin_country': originCountry,
      'stock_quantity': stockQuantity,
      'critical_stock': criticalStock,
      'purchase_price': purchasePrice,
      'purchase_price_vat_included': purchasePriceVatIncluded,
      'price1': price1,
      'price1_vat_included': price1VatIncluded,
      'price2': price2,
      'price2_vat_included': price2VatIncluded,
      'vat_rate': vatRate,
      'weight': weight,
      'description': description,
      'image_url': imageUrl,
      'quick_list_order': quickListOrder,
      'is_online_active': isOnlineActive,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  Product copyWith({
    String? id, String? barcode, String? name, String? stockCode,
    String? groupId, String? groupName, String? parentGroupName, String? unit, String? originCountry,
    num? stockQuantity, num? criticalStock, num? purchasePrice,
    bool? purchasePriceVatIncluded, num? price1, bool? price1VatIncluded,
    num? price2, bool? price2VatIncluded, num? vatRate, num? weight,
    String? description, String? imageUrl, int? quickListOrder, bool? isOnlineActive,
  }) {
    return Product(
      id: id ?? this.id, barcode: barcode ?? this.barcode, name: name ?? this.name,
      stockCode: stockCode ?? this.stockCode, groupId: groupId ?? this.groupId,
      groupName: groupName ?? this.groupName,
      parentGroupName: parentGroupName ?? this.parentGroupName,
      unit: unit ?? this.unit,
      originCountry: originCountry ?? this.originCountry,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      criticalStock: criticalStock ?? this.criticalStock,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      purchasePriceVatIncluded: purchasePriceVatIncluded ?? this.purchasePriceVatIncluded,
      price1: price1 ?? this.price1, price1VatIncluded: price1VatIncluded ?? this.price1VatIncluded,
      price2: price2 ?? this.price2, price2VatIncluded: price2VatIncluded ?? this.price2VatIncluded,
      vatRate: vatRate ?? this.vatRate, weight: weight ?? this.weight,
      description: description ?? this.description, imageUrl: imageUrl ?? this.imageUrl,
      quickListOrder: quickListOrder ?? this.quickListOrder,
      isOnlineActive: isOnlineActive ?? this.isOnlineActive,
    );
  }
}
