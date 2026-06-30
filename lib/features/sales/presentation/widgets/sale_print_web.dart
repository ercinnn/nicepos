import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../../../../core/utils/formatters.dart';
import '../../data/models/sale_item.dart';

/// Satış sepetini A4 dikey boyutta yeni bir tarayıcı penceresinde açar ve
/// otomatik olarak yazdırma diyaloğunu tetikler. Kullanıcı bu pencereden
/// sepet listesini detaylı şekilde yazdırabilir.
void printSaleA4({
  required String saleCode,
  required String customerName,
  required DateTime saleDate,
  required List<SaleItem> items,
  required num subtotal,
  required num discountAmount,
  required num netTotal,
}) {
  final html = _buildHtml(
    saleCode: saleCode,
    customerName: customerName,
    saleDate: saleDate,
    items: items,
    subtotal: subtotal,
    discountAmount: discountAmount,
    netTotal: netTotal,
  );

  // Blob URL ile aç — içindeki onload script'i yazdırmayı tetikler.
  final blob = web.Blob(
    [html.toJS].toJS,
    web.BlobPropertyBag(type: 'text/html'),
  );
  final url = web.URL.createObjectURL(blob);
  web.window.open(url, '_blank');
  // URL'yi hemen iptal etmiyoruz; yeni pencere yüklenene kadar gerekli.
}

String _esc(String? value) {
  if (value == null || value.isEmpty) return '';
  return value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}

String _buildHtml({
  required String saleCode,
  required String customerName,
  required DateTime saleDate,
  required List<SaleItem> items,
  required num subtotal,
  required num discountAmount,
  required num netTotal,
}) {
  final rows = StringBuffer();
  var index = 1;
  for (final item in items) {
    rows.writeln('''
      <tr>
        <td class="c">$index</td>
        <td class="bc">${_esc(item.barcode) == '' ? '—' : _esc(item.barcode)}</td>
        <td>${_esc(item.productName)}</td>
        <td class="r">${_esc(formatNumber(item.quantity))}</td>
        <td class="r">${_esc(formatCurrency(item.unitPrice))}</td>
        <td class="r">${_esc(formatCurrency(item.total))}</td>
      </tr>''');
    index++;
  }

  final discountRow = discountAmount > 0
      ? '<tr><td>İskonto</td><td class="r">- ${_esc(formatCurrency(discountAmount))}</td></tr>'
      : '';

  return '''
<!DOCTYPE html>
<html lang="tr">
<head>
<meta charset="utf-8">
<title>Satış ${_esc(saleCode)}</title>
<style>
  @page { size: A4 portrait; margin: 16mm; }
  * { box-sizing: border-box; }
  body {
    font-family: Arial, Helvetica, sans-serif;
    color: #1a2233;
    font-size: 12px;
    margin: 0;
  }
  .head {
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
    border-bottom: 2px solid #1B2A4A;
    padding-bottom: 10px;
    margin-bottom: 14px;
  }
  .head h1 { font-size: 18px; margin: 0 0 4px 0; color: #1B2A4A; }
  .head .meta { font-size: 11px; color: #555; line-height: 1.6; }
  .head .meta b { color: #1a2233; }
  table { width: 100%; border-collapse: collapse; }
  thead th {
    background: #1B2A4A;
    color: #fff;
    text-align: left;
    padding: 7px 8px;
    font-size: 11px;
  }
  tbody td {
    padding: 6px 8px;
    border-bottom: 1px solid #e2e6ee;
    font-size: 11.5px;
  }
  tbody tr:nth-child(even) td { background: #f6f8fc; }
  td.r, th.r { text-align: right; }
  td.c { text-align: center; color: #888; }
  td.bc { font-family: "Courier New", monospace; color: #444; white-space: nowrap; }
  .totals {
    margin-top: 16px;
    width: 280px;
    margin-left: auto;
  }
  .totals table { width: 100%; }
  .totals td { padding: 5px 8px; font-size: 12px; }
  .totals td.r { text-align: right; font-weight: 600; }
  .totals tr.net td {
    border-top: 2px solid #1B2A4A;
    font-size: 15px;
    font-weight: 800;
    color: #1B2A4A;
    padding-top: 8px;
  }
  .foot { margin-top: 30px; font-size: 10px; color: #999; text-align: center; }
</style>
</head>
<body onload="window.focus(); window.print();">
  <div class="head">
    <div>
      <h1>Satış Detayı</h1>
      <div class="meta">
        <div>Belge No: <b>${_esc(saleCode)}</b></div>
        <div>Müşteri: <b>${_esc(customerName)}</b></div>
      </div>
    </div>
    <div class="meta" style="text-align:right;">
      <div>Tarih: <b>${_esc(formatDateTime(saleDate))}</b></div>
    </div>
  </div>

  <table>
    <thead>
      <tr>
        <th style="width:28px;">#</th>
        <th style="width:120px;">Barkod</th>
        <th>Ürün</th>
        <th class="r" style="width:55px;">Miktar</th>
        <th class="r" style="width:80px;">Birim Fiyat</th>
        <th class="r" style="width:90px;">Tutar</th>
      </tr>
    </thead>
    <tbody>
      $rows
    </tbody>
  </table>

  <div class="totals">
    <table>
      <tr><td>Ara Toplam</td><td class="r">${_esc(formatCurrency(subtotal))}</td></tr>
      $discountRow
      <tr class="net"><td>Genel Toplam</td><td class="r">${_esc(formatCurrency(netTotal))}</td></tr>
    </table>
  </div>

  <div class="foot">Bu belge ${_esc(formatDateTime(DateTime.now()))} tarihinde yazdırılmıştır.</div>
</body>
</html>''';
}
