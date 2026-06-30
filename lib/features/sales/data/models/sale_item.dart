class SaleItem {
  final String id;
  final String? saleId;
  final String? productId;
  final String productName;
  final num quantity;
  final num unitPrice;
  final num discountValue;
  final num total;
  final String? note;

  /// Satılan ürünün barkodu. `sale_items` tablosunda saklanmaz; sorguda
  /// `products(barcode)` join'i ile gelir (muhtelif kalemlerde null olur).
  final String? barcode;

  const SaleItem({
    this.id = '',
    this.saleId,
    this.productId,
    required this.productName,
    this.quantity = 1,
    this.unitPrice = 0,
    this.discountValue = 0,
    this.total = 0,
    this.note,
    this.barcode,
  });

  factory SaleItem.fromMap(Map<String, dynamic> map) {
    // Barkod ya doğrudan map'te ya da products(barcode) join'i içinde gelir.
    final productRel = map['products'];
    final barcode = productRel is Map
        ? productRel['barcode'] as String?
        : map['barcode'] as String?;
    return SaleItem(
      id: map['id'] as String? ?? '',
      saleId: map['sale_id'] as String?,
      productId: map['product_id'] as String?,
      productName: map['product_name'] as String,
      quantity: map['quantity'] as num? ?? 1,
      unitPrice: map['unit_price'] as num? ?? 0,
      discountValue: map['discount_value'] as num? ?? 0,
      total: map['total'] as num? ?? 0,
      note: map['note'] as String?,
      barcode: barcode,
    );
  }

  Map<String, dynamic> toInsertMap(String saleId) {
    return {
      'sale_id': saleId,
      'product_id': productId,
      'product_name': productName,
      'quantity': quantity,
      'unit_price': unitPrice,
      'discount_value': discountValue,
      'total': total,
      'note': note,
    };
  }
}
