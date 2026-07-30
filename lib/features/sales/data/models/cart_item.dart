enum DiscountType { percent, tl }

class CartItem {
  final String? productId;
  final String productName;
  final String? barcode;
  final num quantity;
  final num unitPrice;
  final num discountValue;      // raw: % veya TL — discountType'a göre
  final DiscountType discountType;
  final String? note;

  const CartItem({
    this.productId,
    required this.productName,
    this.barcode,
    this.quantity = 1,
    required this.unitPrice,
    this.discountValue = 0,
    this.discountType = DiscountType.tl,
    this.note,
  });

  num get lineTotal => unitPrice * quantity;

  // Her zaman TL cinsinden iskonto tutarı
  num get discountAmount => discountType == DiscountType.percent
      ? lineTotal * discountValue / 100
      : discountValue.clamp(0, lineTotal);

  num get total => lineTotal - discountAmount;

  // Offline satış kuyruğu (`pending_sale.dart`) için JSON-serileştirme —
  // tamamlama anındaki sepeti donduğu haliyle saklar.
  Map<String, dynamic> toMap() {
    return {
      'product_id': productId,
      'product_name': productName,
      'barcode': barcode,
      'quantity': quantity,
      'unit_price': unitPrice,
      'discount_value': discountValue,
      'discount_type': discountType.name,
      'note': note,
    };
  }

  factory CartItem.fromMap(Map<String, dynamic> map) {
    return CartItem(
      productId: map['product_id'] as String?,
      productName: map['product_name'] as String,
      barcode: map['barcode'] as String?,
      quantity: map['quantity'] as num? ?? 1,
      unitPrice: map['unit_price'] as num? ?? 0,
      discountValue: map['discount_value'] as num? ?? 0,
      discountType: DiscountType.values.byName(map['discount_type'] as String? ?? 'tl'),
      note: map['note'] as String?,
    );
  }

  CartItem copyWith({
    String? productId,
    String? productName,
    String? barcode,
    num? quantity,
    num? unitPrice,
    num? discountValue,
    DiscountType? discountType,
    String? note,
  }) {
    return CartItem(
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      barcode: barcode ?? this.barcode,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      discountValue: discountValue ?? this.discountValue,
      discountType: discountType ?? this.discountType,
      note: note ?? this.note,
    );
  }
}
