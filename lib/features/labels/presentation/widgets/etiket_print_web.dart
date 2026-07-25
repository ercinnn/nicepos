import 'dart:js_interop';

import 'package:barcode/barcode.dart';
import 'package:web/web.dart' as web;

import '../../../../core/utils/formatters.dart';
import '../../data/models/label_slot.dart';
import '../../data/models/product_label_item.dart';

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
/// tarayıcı penceresinde açar ve otomatik yazdırır (KARAR v1.14 / v1.14.2).
/// [figurDataUrl] = tam marka figürü (genis_logo_figur.png) base64 data URL'i
/// (RENKLİ basılır; hücreyi doldurur, fiyat/ad/barkod üzerine bindirilir).
void printWideLabelsA4({
  required List<LabelSlot?> slots,
  required String figurDataUrl,
}) {
  final html = _buildWideHtml(slots: slots, figurDataUrl: figurDataUrl);

  final blob = web.Blob(
    [html.toJS].toJS,
    web.BlobPropertyBag(type: 'text/html'),
  );
  final url = web.URL.createObjectURL(blob);
  web.window.open(url, '_blank');
}

/// Dolu Büyük Etiketleri A4 dikey (2 sütun × 2 satır = 4 A5 etiket) olarak yeni
/// bir tarayıcı penceresinde açar ve otomatik yazdırır (KARAR v1.19). Merkez haç
/// (dikey x=105mm / yatay y=148.5mm) hücre ayraçlarından oluşur; dış margin YOK.
/// Etiket-içi düzen dar-logo (Yeni Etiket) ile aynı öğe seti, A5'e oranlanmış.
/// Çıktı SİYAH/BEYAZ + mağaza logosu (RENKLİ); barkod = Code128 SVG.
void printQuadLabelsA4({
  required List<LabelSlot?> slots,
  String? logoDataUrl,
}) {
  final html = _buildQuadHtml(slots: slots, logoDataUrl: logoDataUrl);

  final blob = web.Blob(
    [html.toJS].toJS,
    web.BlobPropertyBag(type: 'text/html'),
  );
  final url = web.URL.createObjectURL(blob);
  web.window.open(url, '_blank');
}

/// Ürün Etiketlerini (adet kadar çoğaltarak) çok-sayfalı A4 dikey (6 sütun × 12
/// satır = 72/sayfa) olarak yeni bir tarayıcı penceresinde açar ve otomatik
/// yazdırır (KARAR v1.21). FİYAT ve LOGO YOK; çıktı SİYAH/BEYAZ; die-cut → kesim
/// çizgisi YOK. Toplam > 72 ise 2., 3. sayfaya taşar. Barkod = Code128 SVG.
void printProductLabelsA4({
  required List<ProductLabelItem> items,
}) {
  final html = _buildProductHtml(items: items);

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

// Büyük Etiket kırmızı başlık bandı fallback ikonu (KARAR v1.20) — bu bantta
// istisnai olarak BEYAZ (kırmızı zemin üstünde okunurluk için), diğer
// sekmelerin ink-lacivert fallback'inden farklı.
const String _storeIconSvgWhite =
    '<svg viewBox="0 0 24 24" width="100%" height="100%">'
    '<path fill="#FFFFFF" d="M20 4H4v2h16V4zm1 10v-2l-1-5H4l-1 5v2h1v6h10v-6h4v6h2v-6h1zm-9 4H6v-4h6v4z"/>'
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

// ─── Geniş Logo etiketi (KARAR v1.14 / v1.14.2) — 2 sütun × 5 satır = 10 etiket ─
// Hücre 94×55mm, kenar 11mm. Marka figürü (RENKLİ) hücreyi doldurur; fiyat/ad/
// barkod figür üzerine oranlı bindirilir (önizleme = HTML = PDF BİREBİR).

String _wideCellHtml(LabelSlot? slot, String figurDataUrl) {
  if (slot == null) {
    return '<div class="wcell empty"></div>';
  }

  final bc = _barcodeSvg(slot.barcode);
  final bcHtml = bc.isEmpty ? '' : '<div class="wbc">$bc</div>';

  return '''
    <div class="wcell">
      <img class="wfig" src="${_esc(figurDataUrl)}" alt="figur">
      <div class="wprice"><span>${_esc(formatNumber(slot.price))} TL</span></div>
      <div class="wbody">
        <div class="wpname">${_esc(slot.productName)}</div>
        $bcHtml
        <div class="wbottom">
          <span class="wbcno">${_esc(slot.barcode)}</span>
          <span class="wdate">${_esc(formatShortDate(slot.createdAt))}</span>
        </div>
      </div>
    </div>''';
}

String _buildWideHtml({
  required List<LabelSlot?> slots,
  required String figurDataUrl,
}) {
  final cells = StringBuffer();
  for (final slot in slots) {
    cells.writeln(_wideCellHtml(slot, figurDataUrl));
  }

  // A4 portrait 210×297mm; kenar üst/alt 11mm, sol/sağ 17mm (KARAR v1.14.4) →
  // yazdırılabilir 176×275mm. 2 sütun → 88mm, 5 satır → 55mm. Konum oranları
  // figürün iç bölgelerine göre (fiyat=tentenin açık iç dikdörtgeni, gövde=yan çizgi içi).
  return '''
<!DOCTYPE html>
<html lang="tr">
<head>
<meta charset="utf-8">
<title>Geniş Logo Etiketleri</title>
<style>
  @page { size: A4 portrait; margin: 11mm 17mm; }
  * { box-sizing: border-box; }
  html, body { margin: 0; padding: 0; }
  body {
    font-family: Arial, Helvetica, sans-serif;
    color: #000;
    -webkit-print-color-adjust: exact;
    print-color-adjust: exact;
  }
  .sheet {
    width: 176mm;
    display: grid;
    grid-template-columns: repeat(2, 88mm);
    grid-auto-rows: 55mm;
    gap: 0;
  }
  .wcell {
    position: relative;
    width: 88mm;
    height: 55mm;
    border: 0.2mm solid #b8b8b8;
    overflow: hidden;
  }
  .wcell.empty { border-color: #e0e0e0; }
  /* Figür hücreyi doldurur (RENKLİ marka grafiği). */
  .wfig {
    position: absolute;
    inset: 0;
    width: 100%;
    height: 100%;
    display: block;
  }
  /* FİYAT — tentenin açık iç dikdörtgeni merkezine ortalı. */
  .wprice {
    position: absolute;
    left: 13%;
    top: 6.5%;
    width: 74%;
    height: 25%;
    display: flex;
    align-items: center;
    justify-content: center;
  }
  .wprice span {
    font-weight: 800;
    font-size: 26pt;
    line-height: 1;
    letter-spacing: -0.5px;
    color: #000;
    white-space: nowrap;
    font-variant-numeric: tabular-nums;
  }
  /* Gövde metin alanı — yan çizgilerin içinde, alt çizginin üstünde. */
  .wbody {
    position: absolute;
    left: 10%;
    top: 58.5%;
    width: 80%;
    height: 39.5%;
    display: flex;
    flex-direction: column;
    align-items: center;
  }
  /* Ürün adı — v1.14.4: ÜSTE hizalı (padding-top 0). v1.14.3'teki aşağı-itme
     2 satırlı adları barkoda sokuyordu → ~5mm yukarı alındı. Barkod + alt satır
     yerinde kalır; taşarsa yalnız ad kırpılır. */
  .wpname {
    font-size: 9pt;
    font-weight: 700;
    line-height: 1.15;
    text-transform: uppercase;
    text-align: center;
    margin-top: 2.5mm; /* v1.14.6: ad 2.5mm aşağı, üste hizalı; barkod yerinde kalır */
    flex: 1 1 auto;
    min-height: 0;
    display: -webkit-box;
    -webkit-line-clamp: 2;
    -webkit-box-orient: vertical;
    overflow: hidden;
    align-self: stretch;
  }
  /* Barkod — yarı yükseklik (v1.14.2), gövde iç genişliğinde ortalı. */
  .wbc {
    flex: 0 0 auto;
    height: 33%;
    width: 100%;
    margin: 0 auto;
  }
  .wbc svg { width: 100%; height: 100%; display: block; }
  /* Alt satır: barkod no SOLDA · tarih SAĞDA. */
  .wbottom {
    flex: 0 0 auto;
    width: 100%;
    display: flex;
    align-items: flex-end;
    justify-content: space-between;
    font-variant-numeric: tabular-nums;
  }
  .wbcno { font-size: 10pt; letter-spacing: 0.3px; color: #000; }
  .wdate { font-size: 5.5pt; color: #444; }
</style>
</head>
<body onload="window.focus(); window.print();">
  <div class="sheet">
    $cells
  </div>
</body>
</html>''';
}

// ─── Büyük Etiket (KARAR v1.19) — 2 sütun × 2 satır = 4 A5 etiket ─────────────
// Merkez haç (dikey x=105mm / yatay y=148.5mm) hücre ayraçlarından oluşur; dış
// margin YOK. Hücre 105×148.5mm, iç güvenli boşluk 6mm. Etiket-içi düzen
// dar-logo (Yeni Etiket) ile BİREBİR aynı öğe seti, A5'e oranlanmış (fontlar
// ~1.8× büyütüldü). Çıktı SİYAH/BEYAZ + RENKLİ mağaza logosu.

String _quadCellHtml(LabelSlot? slot, String? logoDataUrl) {
  if (slot == null) {
    return '<div class="qcell empty"></div>';
  }

  final logoHtml = (logoDataUrl != null && logoDataUrl.isNotEmpty)
      ? '<img class="qlogo-img" src="${_esc(logoDataUrl)}" alt="logo">'
      : _storeIconSvgWhite;

  final bc = _barcodeSvg(slot.barcode);
  final bcHtml = bc.isEmpty ? '' : '<div class="qbc">$bc</div>';

  // KARAR v1.20: üst bant KIRMIZI zemin (logo + "ÖZEL FİYAT" + ürün adı) →
  // beyaz+kırmızı-kenarlıklı fiyat kutusu ("SATIŞ FİYATI"/fiyat hero/"KDV
  // DAHİLDİR") → kesikli nötr ayraç → barkod + alt satır (DEĞİŞMEDİ).
  return '''
    <div class="qcell">
      <div class="qtop">
        <div class="qlogo">$logoHtml</div>
        <div class="qtoptext">
          <div class="qlabel">ÖZEL FİYAT</div>
          <div class="qpname">${_esc(slot.productName)}</div>
        </div>
      </div>
      <div class="qpricebox">
        <div class="qsflabel">SATIŞ FİYATI</div>
        <div class="qprice">${_esc(formatNumber(slot.price))} TL</div>
        <div class="qkdv">KDV DAHİLDİR</div>
      </div>
      <div class="qdash"></div>
      $bcHtml
      <div class="qbottom">
        <span class="qbcno">${_esc(slot.barcode)}</span>
        <span class="qdate">${_esc(formatShortDate(slot.createdAt))}</span>
      </div>
    </div>''';
}

String _buildQuadHtml({
  required List<LabelSlot?> slots,
  String? logoDataUrl,
}) {
  final cells = StringBuffer();
  for (final slot in slots) {
    cells.writeln(_quadCellHtml(slot, logoDataUrl));
  }

  // A4 portrait 210×297mm, dış margin 0. 2 sütun → 105mm, 2 satır → 148.5mm.
  // Merkez haç = hücrelerin bitişik hairline kenarlıkları (nötr, altın YOK).
  return '''
<!DOCTYPE html>
<html lang="tr">
<head>
<meta charset="utf-8">
<title>Büyük Etiketler</title>
<style>
  @page { size: A4 portrait; margin: 0; }
  * { box-sizing: border-box; }
  html, body { margin: 0; padding: 0; }
  body {
    font-family: Arial, Helvetica, sans-serif;
    color: #000;
    -webkit-print-color-adjust: exact;
    print-color-adjust: exact;
  }
  .sheet {
    width: 210mm;
    display: grid;
    grid-template-columns: repeat(2, 105mm);
    grid-auto-rows: 148.5mm;
    gap: 0;
  }
  .qcell {
    /* İnce nötr hairline (merkez haç + kesim kılavuzu; altın YOK). */
    border: 0.2mm solid #b8b8b8;
    padding: 6mm;
    overflow: hidden;
    display: flex;
    flex-direction: column;
    justify-content: flex-start;
  }
  .qcell.empty { border-color: #e0e0e0; }
  /* 1. Üst bant — KIRMIZI zemin, tam genişlik, köşe radius YOK (KARAR v1.20).
     SABİT yükseklik (KARAR v1.20.1) — Flutter/PDF ile birebir aynı 23.3mm;
     2 satırlık ürün adı dahil en kötü durum baştan hesaba katılır, bant
     ürün adı uzunluğuna göre ASLA büyümez (barkod alanının payı deterministik
     kalır). box-sizing:border-box sayesinde padding bu yüksekliğe dahildir. */
  .qtop {
    background: #C0392B;
    width: 100%;
    height: 23.3mm;
    display: flex;
    align-items: center;
    gap: 4mm;
    flex: 0 0 23.3mm;
    padding: 3mm 4mm;
    overflow: hidden;
  }
  .qlogo {
    width: 20mm;
    height: 16mm;
    flex: 0 0 auto;
    display: flex;
    align-items: center;
    justify-content: center;
  }
  .qlogo-img { max-width: 100%; max-height: 100%; object-fit: contain; }
  .qtoptext {
    flex: 1 1 auto;
    display: flex;
    flex-direction: column;
    min-width: 0;
  }
  .qlabel {
    font-size: 20pt;
    font-weight: 800;
    letter-spacing: 0.5px;
    color: #fff;
  }
  .qpname {
    font-size: 11pt;
    font-weight: 600;
    line-height: 1.15;
    text-transform: uppercase;
    text-align: left;
    color: rgba(255, 255, 255, 0.9);
    margin-top: 1mm;
    /* En fazla 2 satır, taşarsa kısalt. */
    display: -webkit-box;
    -webkit-line-clamp: 2;
    -webkit-box-orient: vertical;
    overflow: hidden;
  }
  /* 3. Fiyat kutusu — beyaz zemin + kırmızı ince kenarlık (KARAR v1.20).
     Dikey iç boşluk ~25% daraltıldı (KARAR v1.20.1 madde 2: 3mm → 2.25mm,
     ek güvenlik payı için) — renk/sıra/hiyerarşi DEĞİŞMEDİ. */
  .qpricebox {
    background: #fff;
    border: 0.6mm solid #C0392B;
    border-radius: 3mm;
    margin: 3mm 0;
    padding: 2.25mm 4mm;
    display: flex;
    flex-direction: column;
    align-items: center;
    flex: 0 0 auto;
  }
  .qsflabel {
    font-size: 9pt;
    font-weight: 700;
    letter-spacing: 1px;
    color: #C0392B;
  }
  .qprice {
    font-weight: 800;
    font-size: 70pt;
    line-height: 1;
    letter-spacing: -0.5px;
    text-align: center;
    white-space: nowrap;
    font-variant-numeric: tabular-nums;
    color: #C0392B;
  }
  .qkdv { font-size: 7.5pt; color: #cb6156; }
  /* 4. Kesikli ayraç — nötr `#b8b8b8` (mevcut kesim-kılavuzu grisi), altın YOK. */
  .qdash {
    border-top: 0.35mm dashed #b8b8b8;
    margin: 2mm 0;
    flex: 0 0 auto;
  }
  .qbc {
    /* Esnek: sabit öğeler (üst bant, fiyat kutusu, alt satır) yerini korur;
       taşarsa yalnız barkod çizgisi kısalır. Yatayda %80'e ortalı.
       min-height (KARAR v1.20.1 madde 3, orantılı minimum — Flutter/PDF'teki
       savunma eşiğinin HTML eşdeğeri): barkod SVG'si sabit 260×60 viewBox ile
       üretilir (bkz. `_barcodeSvg`), bu yüzden HTML'de gerçek bir `assert`
       çökmesi riski YOK; bu yalnız görsel bir güvenlik payıdır. */
    flex: 1 1 auto;
    min-height: 2mm;
    width: 80%;
    margin: 0 auto;
  }
  .qbc svg { width: 100%; height: 100%; display: block; }
  .qbottom {
    display: flex;
    align-items: flex-end;
    justify-content: space-between;
    flex: 0 0 auto;
    font-variant-numeric: tabular-nums;
  }
  .qbcno { font-size: 25pt; letter-spacing: 0.5px; }
  .qdate { font-size: 10pt; color: #444; }
</style>
</head>
<body onload="window.focus(); window.print();">
  <div class="sheet">
    $cells
  </div>
</body>
</html>''';
}

// ─── Ürün Etiketi (KARAR v1.21) — 6 sütun × 12 satır = 72 etiket/sayfa ────────
// Adet-tabanlı, FİYATSIZ/LOGOSUZ. A4 dikey; sayfa boşluğu üst/alt 10mm, yatay 0.
// Hücre 35×23mm, her kenardan 1.5mm iç pay → içerik 32×20mm (KARAR v1.22). Toplam
// > 72 ise 2., 3. sayfaya taşar (her sayfa `page-break-after`). Etiket-içi (dikey
// ORTALI): ürün adı 2 satır sabit + Code128 barkod (SABİT 8mm) + barkod no.
// die-cut → baskıda çerçeve/kesim çizgisi YOK. Önizleme = HTML = PDF birebir.

String _productCellHtml(ProductLabelItem? it) {
  if (it == null) {
    // Boş hücre — die-cut, çerçeve YOK.
    return '<div class="dcell"></div>';
  }
  final bc = _barcodeSvg(it.barcode);
  final bcHtml = bc.isEmpty ? '' : '<div class="dbc">$bc</div>';
  return '''
    <div class="dcell">
      <div class="dname">${_esc(it.productName)}</div>
      $bcHtml
      <div class="dbcno">${_esc(it.barcode)}</div>
    </div>''';
}

String _buildProductHtml({
  required List<ProductLabelItem> items,
}) {
  final pages = paginateProductLabels(items);
  final sheets = StringBuffer();
  for (final page in pages) {
    final cells = StringBuffer();
    for (final it in page) {
      cells.writeln(_productCellHtml(it));
    }
    sheets.writeln('<div class="dsheet">$cells</div>');
  }

  // A4 portrait 210×297mm; sayfa boşluğu üst/alt 10mm, yatay 0. 6 sütun × 35mm =
  // 210mm, 12 satır × 23mm = 276mm. die-cut → hücre kenarlığı YOK.
  return '''
<!DOCTYPE html>
<html lang="tr">
<head>
<meta charset="utf-8">
<title>Ürün Etiketleri</title>
<style>
  @page { size: A4 portrait; margin: 10mm 0; }
  * { box-sizing: border-box; }
  html, body { margin: 0; padding: 0; }
  body {
    font-family: Arial, Helvetica, sans-serif;
    color: #000;
    -webkit-print-color-adjust: exact;
    print-color-adjust: exact;
  }
  .dsheet {
    width: 210mm;
    display: grid;
    grid-template-columns: repeat(6, 35mm);
    grid-auto-rows: 23mm;
    gap: 0;
    page-break-after: always;
  }
  .dsheet:last-child { page-break-after: auto; }
  /* Hücre — 1.5mm iç pay (KARAR v1.22); die-cut → çerçeve/kesim çizgisi YOK.
     3 öğe grubu dikey ORTALI (justify-content: center). */
  .dcell {
    width: 35mm;
    height: 23mm;
    padding: 1.5mm;
    overflow: hidden;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
  }
  /* Ürün adı — 2 satır sabit alan, ORTALI, uzun ad kısalır (flex:0). */
  .dname {
    flex: 0 0 4.4mm;
    width: 100%;
    font-size: 5.4pt;
    font-weight: 700;
    line-height: 1.05;
    text-transform: uppercase;
    text-align: center;
    display: -webkit-box;
    -webkit-line-clamp: 2;
    -webkit-box-orient: vertical;
    overflow: hidden;
  }
  /* Barkod — SABİT 8mm (KARAR v1.22); grup dikey ortalı (dcell
     justify-content: center). Yatayda %80'e ortalı. */
  .dbc {
    flex: 0 0 8mm;
    height: 8mm;
    width: 80%;
    margin: 0 auto;
  }
  .dbc svg { width: 100%; height: 100%; display: block; }
  /* Barkod no — ORTALI, tabular, siyah (flex:0). */
  .dbcno {
    flex: 0 0 auto;
    width: 100%;
    font-size: 7pt;
    letter-spacing: 0.3px;
    text-align: center;
    font-variant-numeric: tabular-nums;
  }
</style>
</head>
<body onload="window.focus(); window.print();">
  $sheets
</body>
</html>''';
}
