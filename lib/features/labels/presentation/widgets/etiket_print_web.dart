import 'dart:js_interop';

import 'package:barcode/barcode.dart';
import 'package:web/web.dart' as web;

import '../../../../core/utils/formatters.dart';
import '../../data/models/label_slot.dart';

/// Dolu raf etiketlerini A4 dikey (3 sütun × 8 satır = 24) olarak yeni bir
/// tarayıcı penceresinde açar ve otomatik yazdırma diyaloğunu tetikler
/// (KARAR v1.10). Çıktı SİYAH/BEYAZ + mağaza logosu; uygulama altını baskıya
/// taşınmaz. Barkod = Code128 SVG (baskıda net siyah çizgiler).
void printLabelsA4({
  required List<LabelSlot?> slots,
  String? logoDataUrl,
}) {
  final html = _buildHtml(slots: slots, logoDataUrl: logoDataUrl);

  final blob = web.Blob(
    [html.toJS].toJS,
    web.BlobPropertyBag(type: 'text/html'),
  );
  final url = web.URL.createObjectURL(blob);
  web.window.open(url, '_blank');
  // URL'yi hemen iptal etmiyoruz; yeni pencere yüklenene kadar gerekli.
}

/// Geniş Logo etiketlerini A4 dikey (2 sütun × 5 satır = 10) olarak yeni bir
/// tarayıcı penceresinde açar ve otomatik yazdırır (KARAR v1.14). [tenteDataUrl]
/// = marka tentesi (genis_logo_tente.png) base64 data URL'i (RENKLİ basılır).
void printWideLabelsA4({
  required List<LabelSlot?> slots,
  required String tenteDataUrl,
}) {
  final html = _buildWideHtml(slots: slots, tenteDataUrl: tenteDataUrl);

  final blob = web.Blob(
    [html.toJS].toJS,
    web.BlobPropertyBag(type: 'text/html'),
  );
  final url = web.URL.createObjectURL(blob);
  web.window.open(url, '_blank');
}

String _esc(String? value) {
  if (value == null || value.isEmpty) return '';
  return value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}

// Code128 barkodunu SVG olarak üretir (net siyah, drawText kapalı — no'yu ayrı
// yazıyoruz). Geçersiz karakter vb. durumda boş döner (etikette barkod çizgisi
// gösterilmez ama fiyat/ad korunur).
String _barcodeSvg(String data) {
  if (data.trim().isEmpty) return '';
  try {
    return Barcode.code128().toSvg(
      data,
      width: 260,
      height: 60,
      drawText: false,
    );
  } catch (_) {
    return '';
  }
}

// Logo yoksa siyah/beyaz baskıya uygun standart "mağaza" ikonu (Material store
// path, color.ink). App altını baskıya taşınmaz.
const String _storeIconSvg =
    '<svg viewBox="0 0 24 24" width="100%" height="100%">'
    '<path fill="#1B2A4A" d="M20 4H4v2h16V4zm1 10v-2l-1-5H4l-1 5v2h1v6h10v-6h4v6h2v-6h1zm-9 4H6v-4h6v4z"/>'
    '</svg>';

String _cellHtml(LabelSlot? slot, String? logoDataUrl) {
  if (slot == null) {
    // Boş hane → boş hücre (kesim kılavuzu korunur).
    return '<div class="cell empty"></div>';
  }

  final logoHtml = (logoDataUrl != null && logoDataUrl.isNotEmpty)
      ? '<img class="logo-img" src="${_esc(logoDataUrl)}" alt="logo">'
      : _storeIconSvg;

  final bc = _barcodeSvg(slot.barcode);
  final bcHtml = bc.isEmpty ? '' : '<div class="bc">$bc</div>';
  final bcNo = _esc(slot.barcode);

  return '''
    <div class="cell">
      <div class="top">
        <div class="logo">$logoHtml</div>
        <div class="price">${_esc(formatNumber(slot.price))} TL</div>
      </div>
      <div class="pname">${_esc(slot.productName)}</div>
      $bcHtml
      <div class="bottom">
        <span class="bcno">$bcNo</span>
        <span class="cdate">${_esc(formatShortDate(slot.createdAt))}</span>
      </div>
    </div>''';
}

String _buildHtml({
  required List<LabelSlot?> slots,
  String? logoDataUrl,
}) {
  final cells = StringBuffer();
  for (final slot in slots) {
    cells.writeln(_cellHtml(slot, logoDataUrl));
  }

  // A4 portrait: 210×297mm, kenar 5mm → yazdırılabilir 200×287mm.
  // 3 sütun → ~66.6mm, 8 satır → ~35.9mm hücre (KARAR v1.10 ~66×36mm).
  return '''
<!DOCTYPE html>
<html lang="tr">
<head>
<meta charset="utf-8">
<title>Raf Etiketleri</title>
<style>
  @page { size: A4 portrait; margin: 5mm; }
  * { box-sizing: border-box; }
  html, body { margin: 0; padding: 0; }
  body {
    font-family: Arial, Helvetica, sans-serif;
    color: #000;
    -webkit-print-color-adjust: exact;
    print-color-adjust: exact;
  }
  .sheet {
    width: 200mm;
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    grid-auto-rows: 35.9mm;
    gap: 0;
  }
  .cell {
    /* İnce nötr hairline kesim kılavuzu (altın YOK). */
    border: 0.2mm solid #b8b8b8;
    padding: 1.5mm 2.5mm;
    overflow: hidden;
    display: flex;
    flex-direction: column;
    justify-content: flex-start;
  }
  .cell.empty { border-color: #e0e0e0; }
  .top {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 2mm;
    flex: 0 0 auto;
  }
  .logo {
    width: 18mm;
    height: 13mm;
    flex: 0 0 auto;
    display: flex;
    align-items: center;
    justify-content: center;
  }
  .logo-img { max-width: 100%; max-height: 100%; object-fit: contain; }
  .price {
    font-weight: 800;
    font-size: 39pt;
    line-height: 1;
    letter-spacing: -0.5px;
    text-align: center;
    flex: 1 1 auto;
    white-space: nowrap;
    font-variant-numeric: tabular-nums;
  }
  .pname {
    font-size: 10pt;
    font-weight: 600;
    line-height: 1.15;
    text-transform: uppercase;
    text-align: center;
    flex: 0 0 auto;
    /* En fazla 2 satır, taşarsa kısalt. */
    display: -webkit-box;
    -webkit-line-clamp: 2;
    -webkit-box-orient: vertical;
    overflow: hidden;
  }
  .bc {
    /* Esnek: sabit öğeler (üst bant, ürün adı, alt satır) yerini korur;
       taşarsa yalnız barkod çizgisi kısalır. Yatayda %80'e ortalı. */
    flex: 1 1 auto;
    min-height: 0;
    width: 80%;
    margin: 0 auto;
  }
  .bc svg { width: 100%; height: 100%; display: block; }
  .bottom {
    display: flex;
    align-items: flex-end;
    justify-content: space-between;
    flex: 0 0 auto;
    font-variant-numeric: tabular-nums;
  }
  .bcno { font-size: 14pt; letter-spacing: 0.5px; }
  .cdate { font-size: 5.5pt; color: #444; }
</style>
</head>
<body onload="window.focus(); window.print();">
  <div class="sheet">
    $cells
  </div>
</body>
</html>''';
}

// ─── Geniş Logo etiketi (KARAR v1.14) — 2 sütun × 5 satır = 10 etiket ─────────

String _wideCellHtml(LabelSlot? slot, String tenteDataUrl) {
  if (slot == null) {
    return '<div class="wcell empty"></div>';
  }

  final bc = _barcodeSvg(slot.barcode);
  final bcHtml = bc.isEmpty ? '' : '<div class="wbc">$bc</div>';

  return '''
    <div class="wcell">
      <div class="wtente">
        <img class="wtente-img" src="${_esc(tenteDataUrl)}" alt="tente">
        <div class="wprice"><span>${_esc(formatNumber(slot.price))} TL</span></div>
      </div>
      <div class="wpname">${_esc(slot.productName)}</div>
      $bcHtml
      <div class="wbcno">${_esc(slot.barcode)}</div>
      <div class="wdate">${_esc(formatShortDate(slot.createdAt))}</div>
    </div>''';
}

String _buildWideHtml({
  required List<LabelSlot?> slots,
  required String tenteDataUrl,
}) {
  final cells = StringBuffer();
  for (final slot in slots) {
    cells.writeln(_wideCellHtml(slot, tenteDataUrl));
  }

  // A4 portrait: 200×287mm yazdırılabilir. 2 sütun → 100mm, 5 satır → 57.4mm.
  return '''
<!DOCTYPE html>
<html lang="tr">
<head>
<meta charset="utf-8">
<title>Geniş Logo Etiketleri</title>
<style>
  @page { size: A4 portrait; margin: 5mm; }
  * { box-sizing: border-box; }
  html, body { margin: 0; padding: 0; }
  body {
    font-family: Arial, Helvetica, sans-serif;
    color: #000;
    -webkit-print-color-adjust: exact;
    print-color-adjust: exact;
  }
  .sheet {
    width: 200mm;
    display: grid;
    grid-template-columns: repeat(2, 1fr);
    grid-auto-rows: 57.4mm;
    gap: 0;
  }
  .wcell {
    border: 0.2mm solid #b8b8b8;
    padding: 2mm 3mm;
    overflow: hidden;
    display: flex;
    flex-direction: column;
    align-items: center;
  }
  .wcell.empty { border-color: #e0e0e0; }
  /* Tente + fiyat overlay (fiyat flat üst banda ortalı). */
  .wtente {
    position: relative;
    width: 68%;
    flex: 0 0 auto;
  }
  .wtente-img { width: 100%; display: block; }
  .wprice {
    position: absolute;
    top: 4%;
    left: 8%;
    right: 8%;
    height: 58%;
    display: flex;
    align-items: center;
    justify-content: center;
  }
  .wprice span {
    font-weight: 800;
    font-size: 22pt;
    line-height: 1;
    letter-spacing: -0.5px;
    color: #000;
    white-space: nowrap;
    font-variant-numeric: tabular-nums;
  }
  .wpname {
    font-size: 9pt;
    font-weight: 700;
    line-height: 1.15;
    text-transform: uppercase;
    text-align: center;
    flex: 0 0 auto;
    margin-top: 1.5mm;
    display: -webkit-box;
    -webkit-line-clamp: 2;
    -webkit-box-orient: vertical;
    overflow: hidden;
  }
  .wbc {
    flex: 1 1 auto;
    min-height: 0;
    width: 80%;
    margin: 1mm auto 0 auto;
  }
  .wbc svg { width: 100%; height: 100%; display: block; }
  .wbcno {
    font-size: 12pt;
    letter-spacing: 0.5px;
    text-align: center;
    flex: 0 0 auto;
    font-variant-numeric: tabular-nums;
  }
  .wdate {
    align-self: flex-end;
    font-size: 5.5pt;
    color: #444;
    flex: 0 0 auto;
  }
</style>
</head>
<body onload="window.focus(); window.print();">
  <div class="sheet">
    $cells
  </div>
</body>
</html>''';
}
