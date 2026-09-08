/// Eksik Listesi raporu satır modeli.
///
/// Bir ürünün seçili tarih aralığındaki toplam satış adedini, Firma bilgisini
/// (`products.description` alanının ilk parçası, bkz. `ReportRepository`
/// `_parseFirmaFromDescription`) ve güncel stok adedini taşır.
class MissingListRecord {
  final String productId;
  final String name;
  final String? barcode;
  final String companyName; // description'dan parse edilir, boşsa '-'
  final num quantitySold; // Seçili aralıkta satılan toplam miktar (Σ quantity)
  final num stockQuantity; // Ürünün güncel stok adedi (products.stock_quantity)

  const MissingListRecord({
    required this.productId,
    required this.name,
    this.barcode,
    required this.companyName,
    required this.quantitySold,
    required this.stockQuantity,
  });
}
