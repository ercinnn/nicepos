class ProductSaleRecord {
  final String saleId;
  final String saleCode;
  final DateTime saleDate;
  final num quantity;
  final num unitPrice;
  final num total;
  final String? customerName;

  const ProductSaleRecord({
    required this.saleId,
    required this.saleCode,
    required this.saleDate,
    required this.quantity,
    required this.unitPrice,
    required this.total,
    this.customerName,
  });
}
