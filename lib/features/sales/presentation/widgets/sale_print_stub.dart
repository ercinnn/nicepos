import '../../data/models/sale.dart';
import '../../data/models/sale_item.dart';

/// Web dışı platformlarda yazdırma desteklenmez (buton yalnızca web'de görünür).
/// Bu stub yalnızca mobil/masaüstü derlemelerinin geçmesi için vardır.
void printSaleA4({
  required String saleCode,
  required String customerName,
  required DateTime saleDate,
  required List<SaleItem> items,
  required num subtotal,
  required num discountAmount,
  required num netTotal,
}) {
  // No-op
}

/// Web dışı platformlarda toplu yazdırma desteklenmez (buton yalnızca web'de
/// görünür). Bu stub yalnızca mobil/masaüstü derlemelerinin geçmesi için vardır.
void printMultipleSalesA4({
  required String customerName,
  required List<Sale> sales,
  required Map<String, List<SaleItem>> itemsBySaleId,
}) {
  // No-op
}
