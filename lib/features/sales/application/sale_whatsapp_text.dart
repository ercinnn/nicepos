import '../../../core/utils/formatters.dart';
import '../data/models/cart_item.dart';
import '../data/models/sale.dart';
import '../data/models/sale_item.dart';

/// WhatsApp mesajındaki tek bir kalem. `SaleItem` (kayıtlı satış) ve
/// `CartItem` (az önce tamamlanan sepet) buna çevrilir — metin üreticisi
/// iki modelden bağımsız kalır.
class ReceiptLine {
  final String name;
  final num quantity;
  final num unitPrice;

  /// Satır iskontosu SONRASI tutar.
  final num lineTotal;

  const ReceiptLine({
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
  });

  factory ReceiptLine.fromSaleItem(SaleItem item) => ReceiptLine(
        name: item.productName,
        quantity: item.quantity,
        unitPrice: item.unitPrice,
        lineTotal: item.total,
      );

  factory ReceiptLine.fromCartItem(CartItem item) => ReceiptLine(
        name: item.productName,
        quantity: item.quantity,
        unitPrice: item.unitPrice,
        lineTotal: item.total,
      );
}

/// Tek satışın WhatsApp metni (WhatsApp biçimi: `*kalın*`). Kalemler satır
/// iskontosu sonrası tutarla yazılır; sepet geneli iskonto yalnız >0 ise
/// ayrı satır olur.
String buildSaleWhatsAppText({
  String? tenantName,
  required String saleCode,
  required DateTime saleDate,
  String? customerName,
  required List<ReceiptLine> lines,
  required num subtotal,
  required num discountAmount,
  required num netTotal,
}) {
  final b = StringBuffer();
  _writeHeader(b, tenantName: tenantName, customerName: customerName);
  b.writeln('Satış No: $saleCode');
  b.writeln('Tarih: ${formatDateTime(saleDate)}');
  b.writeln();
  _writeLines(b, lines);
  b.writeln();
  if (discountAmount > 0) {
    b.writeln('Ara Toplam: ${formatCurrency(subtotal)}');
    b.writeln('İskonto: -${formatCurrency(discountAmount)}');
  }
  b.writeln('*Toplam: ${formatCurrency(netTotal)}*');
  b.writeln();
  b.write('Teşekkür ederiz.');
  return b.toString();
}

/// Birden çok satışın tek WhatsApp mesajı — her satış kendi bölümü, sonda
/// genel toplam (`printMultipleSalesA4` ile aynı yapı ve toplam tanımı:
/// genel toplam = satışların `totalAmount` toplamı).
String buildMultiSaleWhatsAppText({
  String? tenantName,
  String? customerName,
  required List<Sale> sales,
  required Map<String, List<SaleItem>> itemsBySaleId,
}) {
  final b = StringBuffer();
  _writeHeader(b, tenantName: tenantName, customerName: customerName);
  num grandTotal = 0;
  for (final s in sales) {
    final items = itemsBySaleId[s.id] ?? const <SaleItem>[];
    final subtotal = items.fold<num>(0, (sum, it) => sum + it.total);
    grandTotal += s.totalAmount;

    b.writeln('*${s.saleCode}* — ${formatDateTime(s.saleDate)}');
    _writeLines(b, items.map(ReceiptLine.fromSaleItem).toList());
    if (s.discountAmount > 0) {
      b.writeln('Ara Toplam: ${formatCurrency(subtotal)}');
      b.writeln('İskonto: -${formatCurrency(s.discountAmount)}');
    }
    b.writeln('Toplam: ${formatCurrency(s.totalAmount)}');
    b.writeln();
  }
  b.writeln('*Genel Toplam (${sales.length} satış): ${formatCurrency(grandTotal)}*');
  b.writeln();
  b.write('Teşekkür ederiz.');
  return b.toString();
}

void _writeHeader(StringBuffer b, {String? tenantName, String? customerName}) {
  final tenant = tenantName?.trim() ?? '';
  if (tenant.isNotEmpty) b.writeln('*$tenant*');
  final customer = customerName?.trim() ?? '';
  if (customer.isNotEmpty) b.writeln('Sayın $customer,');
  if (tenant.isNotEmpty || customer.isNotEmpty) b.writeln();
}

void _writeLines(StringBuffer b, List<ReceiptLine> lines) {
  for (final l in lines) {
    final gross = l.unitPrice * l.quantity;
    final lineDiscount = gross - l.lineTotal;
    final discountNote =
        lineDiscount > 0.004 ? ' (${formatCurrency(lineDiscount)} indirim)' : '';
    b.writeln('• ${l.name}');
    b.writeln('   ${formatNumber(l.quantity)} × ${formatCurrency(l.unitPrice)} = '
        '${formatCurrency(l.lineTotal)}$discountNote');
  }
}
