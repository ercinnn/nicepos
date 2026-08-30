import '../../../sales/data/models/sale.dart';

/// Bir ürünün satıldığı TEK bir satıştaki kalemi + o satışın kendi
/// (sale-level) alanları — indirim/ödeme/not `sale_items` değil `sales`
/// tablosunda tutulduğundan buraya da taşınır (bkz. Analiz sayfası bar
/// tıklama diyaloğu, `report_repository.dart` `fetchProductSalesHistory`).
class ProductSaleRecord {
  final String saleId;
  final String saleCode;
  final DateTime saleDate;
  final num quantity;
  final num unitPrice;
  final num total; // bu kalemin toplamı (quantity × unitPrice)
  final String? customerName;

  // Satış (sale) seviyesi alanlar — bu ürünün kalemiyle değil, İÇİNDE
  // bulunduğu satışla ilgili.
  final num saleTotalAmount;
  final num discountPercent;
  final num discountAmount;
  final String discountType; // 'percent' | 'tl'
  final PaymentType paymentType;
  final String? note;

  const ProductSaleRecord({
    required this.saleId,
    required this.saleCode,
    required this.saleDate,
    required this.quantity,
    required this.unitPrice,
    required this.total,
    this.customerName,
    this.saleTotalAmount = 0,
    this.discountPercent = 0,
    this.discountAmount = 0,
    this.discountType = 'percent',
    this.paymentType = PaymentType.nakit,
    this.note,
  });
}
