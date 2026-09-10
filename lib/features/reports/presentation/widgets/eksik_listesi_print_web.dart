import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../../../../core/utils/formatters.dart';
import '../../data/models/ciro_analiz_record.dart';

/// Eksik Listesi'ni A4 dikey boyutta yeni bir tarayıcı penceresinde açar ve
/// otomatik olarak yazdırma diyaloğunu tetikler — `sale_print_web.dart`'ın
/// BİREBİR kopyası, yalnız satış sepeti yerine ürün listesi.
void printEksikListesiA4(List<CiroAnalizRecord> records) {
  final html = _buildHtml(records);

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

String _buildHtml(List<CiroAnalizRecord> records) {
  final rows = StringBuffer();
  for (var i = 0; i < records.length; i++) {
    final r = records[i];
    final barcode = _esc(r.barcode);
    rows.writeln('''
      <tr>
        <td class="c">${i + 1}</td>
        <td>${_esc(r.name)}</td>
        <td class="bc">${barcode.isEmpty ? '—' : barcode}</td>
        <td>${_esc(r.companyName)}</td>
        <td class="r">${_esc(formatNumber(r.stockQuantity))}</td>
        <td class="r">${_esc(formatNumber(r.quantitySold))}</td>
      </tr>''');
  }

  return '''
<!DOCTYPE html>
<html lang="tr">
<head>
<meta charset="utf-8">
<title>Eksik Listesi</title>
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
  .foot { margin-top: 30px; font-size: 10px; color: #999; text-align: center; }
</style>
</head>
<body onload="window.focus(); window.print();">
  <div class="head">
    <h1>Eksik Listesi</h1>
    <div class="meta">
      <div>${records.length} ürün — yazdırma tarihi: <b>${_esc(formatDateTime(DateTime.now()))}</b></div>
    </div>
  </div>

  <table>
    <thead>
      <tr>
        <th style="width:28px;">#</th>
        <th>Ürün</th>
        <th style="width:120px;">Barkod</th>
        <th style="width:140px;">Firma</th>
        <th class="r" style="width:60px;">Stok</th>
        <th class="r" style="width:90px;">Satış Adedi</th>
      </tr>
    </thead>
    <tbody>
      $rows
    </tbody>
  </table>

  <div class="foot">Bu belge ${_esc(formatDateTime(DateTime.now()))} tarihinde yazdırılmıştır.</div>
</body>
</html>''';
}
