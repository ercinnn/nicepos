/// Eksik Listesi raporu satır modeli.
///
/// Bir ürünün seçili tarih aralığındaki toplam satış adedini, Firma bilgisini
/// (`products.description` alanının ilk parçası, bkz. `ReportRepository`
/// `_parseFirmaFromDescription`), güncel stok adedini, gerçek (indirim
/// sonrası) toplam cirosunu ve bu cironun seçili aralıktaki TÜM ürünlerin
/// toplam cirosuna oranını (%) taşır.
class MissingListRecord {
  final String productId;
  final String name;
  final String? barcode;
  final String companyName; // description'dan parse edilir, boşsa '-'
  final num quantitySold; // Seçili aralıkta satılan toplam miktar (Σ quantity)
  final num stockQuantity; // Ürünün güncel stok adedi (products.stock_quantity)
  final num totalRevenue; // Gerçek ciro: satır indirimi + orantılı genel indirim düşülmüş toplam (bkz. ReportRepository.fetchMissingList)
  final num revenueSharePercent; // totalRevenue'nun aralıktaki TÜM ürünlerin toplam cirosuna oranı, 0-100

  const MissingListRecord({
    required this.productId,
    required this.name,
    this.barcode,
    required this.companyName,
    required this.quantitySold,
    required this.stockQuantity,
    required this.totalRevenue,
    required this.revenueSharePercent,
  });
}
