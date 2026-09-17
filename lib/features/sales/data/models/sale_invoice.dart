/// `sale_invoices` (0066 migration) satırı — NicePOS'tan doğrudan EDM'yi
/// çağırmaz, yalnız bir talep/durum kaydı tutar; kullanıcının bilgisayarındaki
/// Python script (`efatura/`) bunu okuyup EDM'ye gönderir ve sonucu buraya
/// yazar. Detay: notes/e-fatura-entegrasyonu.md
enum SaleInvoiceStatus { pending, sent, failed }

extension SaleInvoiceStatusX on SaleInvoiceStatus {
  static SaleInvoiceStatus fromDb(String value) {
    switch (value) {
      case 'sent':
        return SaleInvoiceStatus.sent;
      case 'failed':
        return SaleInvoiceStatus.failed;
      default:
        return SaleInvoiceStatus.pending;
    }
  }
}

class SaleInvoice {
  final String id;
  final String saleId;
  final String invoiceType; // 'e_fatura' | 'e_arsiv'
  final SaleInvoiceStatus status;
  final String? edmInvoiceId;
  final String? pdfUrl;
  final String? errorMessage;
  final DateTime requestedAt;

  const SaleInvoice({
    required this.id,
    required this.saleId,
    required this.invoiceType,
    required this.status,
    this.edmInvoiceId,
    this.pdfUrl,
    this.errorMessage,
    required this.requestedAt,
  });

  factory SaleInvoice.fromMap(Map<String, dynamic> map) {
    return SaleInvoice(
      id: map['id'] as String,
      saleId: map['sale_id'] as String,
      invoiceType: map['invoice_type'] as String,
      status: SaleInvoiceStatusX.fromDb(map['status'] as String),
      edmInvoiceId: map['edm_invoice_id'] as String?,
      pdfUrl: map['pdf_url'] as String?,
      errorMessage: map['error_message'] as String?,
      requestedAt: DateTime.parse(map['requested_at'] as String).toLocal(),
    );
  }
}
