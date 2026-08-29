import 'dart:js_interop';

import 'package:barcode/barcode.dart';
import 'package:web/web.dart' as web;

import '../../../../core/utils/formatters.dart';
import '../../data/models/discount_label_slot.dart';
import '../../data/models/label_slot.dart';
import '../../data/models/product_label_item.dart';
import '../../data/models/tel_discount_label_slot.dart';

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

/// Dolu Tel Etiketlerini A4 dikey (4 sütun × 8 satır = 32) olarak yeni bir
/// tarayıcı penceresinde açar ve otomatik yazdırma diyaloğunu tetikler. Raf
/// Etiketi'nin (`printLabelsA4`) birebir aynı hücre tasarımı, yalnız 4'lü
/// ızgara. Çıktı SİYAH/BEYAZ + mağaza logosu (Raf'ın kalıcı logoDataUrl'i
/// çağıran taraftan geçirilir).
void printTelLabelsA4({
  required List<LabelSlot?> slots,
  String? logoDataUrl,
}) {
  final html = _buildTelHtml(slots: slots, logoDataUrl: logoDataUrl);

  final blob = web.Blob(
    [html.toJS].toJS,
    web.BlobPropertyBag(type: 'text/html'),
  );
  final url = web.URL.createObjectURL(blob);
  web.window.open(url, '_blank');
}

/// Dolu Tel İndirim Etiketlerini A4 dikey (4 sütun × 8 satır = 32) olarak yeni
/// bir tarayıcı penceresinde açar ve otomatik yazdırır. Tel Etiketi'nin
/// (`printTelLabelsA4`) birebir aynı ızgara/kenar boşluğu, yalnız her hücre
/// çizili eski fiyat + kırmızı/1.5× büyük yeni fiyat basar (rozet YOK).
void printTelDiscountLabelsA4({
  required List<TelDiscountLabelSlot?> slots,
  String? logoDataUrl,
  required TelDiscountKind generalKind,
  required num generalValue,
}) {
  final html = _buildTelDiscountHtml(
    slots: slots,
    logoDataUrl: logoDataUrl,
    generalKind: generalKind,
    generalValue: generalValue,
  );

  final blob = web.Blob(
    [html.toJS].toJS,
    web.BlobPropertyBag(type: 'text/html'),
  );
  final url = web.URL.createObjectURL(blob);
  web.window.open(url, '_blank');
}

/// Geniş Logo etiketlerini A4 dikey (2 sütun × 5 satır = 10) olarak yeni bir
/// tarayıcı penceresinde açar ve otomatik yazdırır (KARAR v1.14 / v1.14.2).
/// [logoDataUrl] = kiracının kendi yüklediği mağaza logosu (Faz D — kiracı-
/// bazlı marka, opsiyonel; yoksa logo alanı boş kalır).
void printWideLabelsA4({
  required List<LabelSlot?> slots,
  String? logoDataUrl,
}) {
  final html = _buildWideHtml(slots: slots, logoDataUrl: logoDataUrl);

  final blob = web.Blob(
    [html.toJS].toJS,
    web.BlobPropertyBag(type: 'text/html'),
  );
  final url = web.URL.createObjectURL(blob);
  web.window.open(url, '_blank');
}

/// Poster listesini (barkod okutulan ürünlerin ad+fiyatı, çok-sayfalı) A4 dikey
/// profesyonel ürün listesi olarak yeni bir tarayıcı penceresinde açar ve
/// otomatik yazdırır (KARAR v1.23). `logoDataUrl` = Yeni Etiket'in kalıcı mağaza
/// logosu (opsiyonel). Çıktı SİYAH/BEYAZ + isteğe bağlı RENKLİ logo.
void printPosterA4({
  required List<LabelSlot> items,
  required String title,
  bool showBarcode = false,
  String? logoDataUrl,
}) {
  final html = _buildPosterHtml(
    items: items,
    title: title,
    showBarcode: showBarcode,
    logoDataUrl: logoDataUrl,
  );

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

/// Dolu İndirim Etiketlerini A4 dikey (2 sütun × 2 satır = 4) olarak yeni bir
/// tarayıcı penceresinde açar ve otomatik yazdırma diyaloğunu tetikler. Eski
/// fiyat siyah (üzeri KIRMIZI çizili), yeni fiyat kırmızı hero, tek satır
/// kırmızı "%X İNDİRİM" bandı. [logoDataUrl]/[tagline] — Faz D kiracı-bazlı
/// marka (Geniş Logo ile PAYLAŞILIR); logo yoksa alan boş, tagline boşsa
/// satır basılmaz.
void printDiscountLabelsA4({
  required List<DiscountLabelSlot?> slots,
  String? logoDataUrl,
  required num defaultPercent,
  String tagline = '',
}) {
  final html = _buildDiscountHtml(
    slots: slots,
    logoDataUrl: logoDataUrl,
    defaultPercent: defaultPercent,
    tagline: tagline,
  );

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
  .bcno { font-size: 14pt; letter-spacing: 0.5px; text-align: center; }
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

// ─── Tel Etiketi — 4 sütun × 8 satır = 32 etiket ─────────────────────────────
// Raf Etiketi ile birebir aynı hücre tasarımı/yükseklik (_cellHtml paylaşılır);
// yalnız sütun sayısı ve hücre genişliği farklı.

String _buildTelHtml({
  required List<LabelSlot?> slots,
  String? logoDataUrl,
}) {
  final cells = StringBuffer();
  for (final slot in slots) {
    cells.writeln(_cellHtml(slot, logoDataUrl));
  }

  // A4 portrait: 210×297mm, kenar 5mm → yazdırılabilir 200×287mm.
  // 4 sütun → 50mm, 8 satır → ~35.9mm hücre (Raf ile birebir aynı yükseklik).
  return '''
<!DOCTYPE html>
<html lang="tr">
<head>
<meta charset="utf-8">
<title>Tel Etiketleri</title>
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
    grid-template-columns: repeat(4, 1fr);
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
  .bcno { font-size: 14pt; letter-spacing: 0.5px; text-align: center; }
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

// ─── Tel İndirim Etiketi — Tel ile AYNI 4×8 ızgara, indirimli fiyat çifti ────

String _telDiscountCellHtml(
  TelDiscountLabelSlot? slot,
  String? logoDataUrl,
  TelDiscountKind generalKind,
  num generalValue,
) {
  if (slot == null) {
    return '<div class="tdcell empty"></div>';
  }

  final logoHtml = (logoDataUrl != null && logoDataUrl.isNotEmpty)
      ? '<img class="tdlogo-img" src="${_esc(logoDataUrl)}" alt="logo">'
      : _storeIconSvg;

  final bc = _barcodeSvg(slot.barcode);
  final bcHtml = bc.isEmpty ? '' : '<div class="tdbc">$bc</div>';
  final bcNo = _esc(slot.barcode);

  return '''
    <div class="tdcell">
      <div class="tdtop">
        <div class="tdlogo">$logoHtml</div>
        <div class="tdold">${_esc(formatNumber(slot.oldPrice))} TL</div>
      </div>
      <div class="tdnew">${_esc(formatNumber(slot.newPrice(generalKind, generalValue)))} TL</div>
      <div class="tdpname">${_esc(slot.productName)}</div>
      $bcHtml
      <div class="tdbottom">
        <span class="tdbcno">$bcNo</span>
        <span class="tdcdate">${_esc(formatShortDate(slot.createdAt))}</span>
      </div>
    </div>''';
}

String _buildTelDiscountHtml({
  required List<TelDiscountLabelSlot?> slots,
  String? logoDataUrl,
  required TelDiscountKind generalKind,
  required num generalValue,
}) {
  final cells = StringBuffer();
  for (final slot in slots) {
    cells.writeln(
        _telDiscountCellHtml(slot, logoDataUrl, generalKind, generalValue));
  }

  // A4 portrait: 210×297mm, kenar 5mm → yazdırılabilir 200×287mm.
  // 4 sütun → 50mm, 8 satır → ~35.9mm hücre (Tel Etiketi ile birebir aynı).
  return '''
<!DOCTYPE html>
<html lang="tr">
<head>
<meta charset="utf-8">
<title>Tel İndirim Etiketleri</title>
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
    grid-template-columns: repeat(4, 1fr);
    grid-auto-rows: 35.9mm;
    gap: 0;
  }
  .tdcell {
    border: 0.2mm solid #b8b8b8;
    padding: 1.2mm 2mm;
    overflow: hidden;
    display: flex;
    flex-direction: column;
    justify-content: flex-start;
  }
  .tdcell.empty { border-color: #e0e0e0; }
  /* Üst satır (logo + çizili eski fiyat), yeni fiyat, ürün adı, barkod —
     DÖRDÜ flex ORANI (40:33:19:80, ekrandaki `_TelDiscountLabelCell` ve
     PDF'teki `_telDiscountCell` ile BİREBİR aynı oran) ile hücre boyunu
     paylaşır — kullanıcının canlı gözden geçirmede istediği 2×/2×/0.5×/4×
     büyüklükler dar hücreye (35.9mm) mutlak pikselde/mm'de birlikte
     sığmadığından (toplamı bütçeyi aşıyor) SABİT mm yerine bu ORANLAR
     kullanılır — hücreye göre ölçeklenir, taşma riski YOK. Alt satır
     (barkod no + tarih) DIŞARIDA, SABİT/değişmedi. */
  .tdtop {
    display: flex;
    align-items: center;
    justify-content: flex-end;
    gap: 1.5mm;
    flex: 40 1 0;
    min-height: 0;
    overflow: hidden;
  }
  .tdlogo {
    width: 18mm;
    height: 100%;
    flex: 0 0 auto;
    margin-right: auto;
    display: flex;
    align-items: center;
    justify-content: center;
  }
  .tdlogo-img { max-width: 100%; max-height: 100%; object-fit: contain; }
  .tdold {
    font-size: 16pt;
    font-weight: 700;
    color: #000;
    text-decoration: line-through;
    text-decoration-color: #C0392B;
    white-space: nowrap;
    font-variant-numeric: tabular-nums;
  }
  /* Yeni fiyat hero'su — kullanıcı isteğiyle barkod yarıya inince (80→40)
     açılan pay buraya eklendi: 17pt → 38pt. */
  .tdnew {
    flex: 73 1 0;
    min-height: 0;
    display: flex;
    align-items: center;
    justify-content: center;
    overflow: hidden;
    font-weight: 800;
    font-size: 38pt;
    line-height: 1;
    letter-spacing: -0.5px;
    color: #C0392B;
    white-space: nowrap;
    font-variant-numeric: tabular-nums;
  }
  /* Ürün adı — kullanıcı isteğiyle 2×: 7pt → 14pt. */
  .tdpname {
    flex: 19 1 0;
    min-height: 0;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 14pt;
    font-weight: 600;
    line-height: 1.1;
    text-transform: uppercase;
    text-align: center;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }
  /* Barkod — kullanıcı isteğiyle yarıya indirildi (flex 80 → 40), açılan pay yeni fiyata eklendi. */
  .tdbc {
    flex: 40 1 0;
    min-height: 0;
    width: 80%;
    margin: 0 auto;
  }
  .tdbc svg { width: 100%; height: 100%; display: block; }
  .tdbottom {
    display: flex;
    align-items: flex-end;
    justify-content: space-between;
    flex: 0 0 auto;
    font-variant-numeric: tabular-nums;
  }
  .tdbcno { font-size: 9pt; letter-spacing: 0.3px; text-align: center; }
  .tdcdate { font-size: 5pt; color: #444; }
</style>
</head>
<body onload="window.focus(); window.print();">
  <div class="sheet">
    $cells
  </div>
</body>
</html>''';
}

// ─── Geniş Logo etiketi — 2 sütun × 5 satır = 10 etiket ───────────────────────
// Hücre 88×55mm, kenar 11mm/17mm. Faz D: sabit marka figürü KALDIRILDI —
// kiracının kendi logosu (opsiyonel) düz zeminde ortalı, dikey flex akış
// (logo → fiyat → ad → barkod → alt satır). Önizleme = HTML = PDF BİREBİR.

String _wideCellHtml(LabelSlot? slot, String? logoDataUrl) {
  if (slot == null) {
    return '<div class="wcell empty"></div>';
  }

  final logoHtml = (logoDataUrl != null && logoDataUrl.isNotEmpty)
      ? '<img class="wlogo-img" src="${_esc(logoDataUrl)}" alt="logo">'
      : '';

  final bc = _barcodeSvg(slot.barcode);
  final bcHtml = bc.isEmpty ? '' : '<div class="wbc">$bc</div>';

  return '''
    <div class="wcell">
      <div class="wlogo">$logoHtml</div>
      <div class="wprice"><span>${_esc(formatNumber(slot.price))} TL</span></div>
      <div class="wpname">${_esc(slot.productName)}</div>
      $bcHtml
      <div class="wbottom">
        <span class="wbcno">${_esc(slot.barcode)}</span>
        <span class="wdate">${_esc(formatShortDate(slot.createdAt))}</span>
      </div>
    </div>''';
}

String _buildWideHtml({
  required List<LabelSlot?> slots,
  String? logoDataUrl,
}) {
  final cells = StringBuffer();
  for (final slot in slots) {
    cells.writeln(_wideCellHtml(slot, logoDataUrl));
  }

  // A4 portrait 210×297mm; kenar üst/alt 11mm, sol/sağ 17mm → yazdırılabilir
  // 176×275mm. 2 sütun → 88mm, 5 satır → 55mm.
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
    width: 88mm;
    height: 55mm;
    border: 0.2mm solid #b8b8b8;
    overflow: hidden;
    box-sizing: border-box;
    padding: 2mm;
    display: flex;
    flex-direction: column;
    align-items: center;
    background: #fff;
  }
  .wcell.empty { border-color: #e0e0e0; }
  .wlogo {
    flex: 0 0 32%;
    width: 100%;
    display: flex;
    align-items: center;
    justify-content: center;
    overflow: hidden;
  }
  .wlogo-img { max-width: 90%; max-height: 100%; object-fit: contain; }
  .wprice {
    flex: 0 0 22%;
    width: 100%;
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
  .wpname {
    flex: 0 0 20%;
    width: 100%;
    font-size: 9pt;
    font-weight: 700;
    line-height: 1.15;
    text-transform: uppercase;
    text-align: center;
    display: -webkit-box;
    -webkit-line-clamp: 2;
    -webkit-box-orient: vertical;
    overflow: hidden;
  }
  /* Barkod. */
  .wbc {
    flex: 0 0 13%;
    width: 100%;
    display: flex;
    align-items: center;
    justify-content: center;
  }
  .wbc svg { width: 100%; height: 100%; display: block; }
  /* Alt satır: barkod no SOLDA · tarih SAĞDA. */
  .wbottom {
    flex: 0 0 9%;
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

// ─── Poster (KARAR v1.23) — tek sütunlu profesyonel ürün listesi ─────────────
// A4 dikey; sabit ızgara YOK, satır sayısı 1..20 (bkz. `kPosterItemsPerPage`)
// arasında değişir. Sayfa BOŞ kalmasın diye satır yüksekliği/fontu JS ile değil
// (üç çıktı BİREBİR kalsın diye) inline `style` ile satır sayısına göre
// ORANLANARAK hesaplanır — Flutter/PDF tarafıyla aynı formül. Toplam > 20 ise
// 2., 3. sayfaya taşar (`page-break-after`). Çıktı SİYAH/BEYAZ + isteğe bağlı
// RENKLİ mağaza logosu (Yeni Etiket'in kalıcı store logosu paylaşılır).

double _posterClampWeb(double v, double lo, double hi) =>
    v < lo ? lo : (v > hi ? hi : v);

String _posterPageHtml(
  List<LabelSlot> page,
  String title,
  bool showBarcode,
  String? logoDataUrl,
  DateTime generatedAt,
  String? pageLabel,
) {
  final logoHtml = (logoDataUrl != null && logoDataUrl.isNotEmpty)
      ? '<img class="plogo-img" src="${_esc(logoDataUrl)}" alt="logo">'
      : '';

  final rows = StringBuffer();
  if (page.isEmpty) {
    rows.write('<div class="pempty">Henüz ürün okutulmadı.</div>');
  } else {
    // Satır yüksekliği (mm): kalan yükseklik ≈ 297 − 36 (dış margin) − ~34
    // (başlık) − ~10 (alt bilgi) ≈ 217mm; kalem sayısına oranlı, min/max ile
    // sınırlı (az kalem → iri "poster" satırı, çok kalem → kompakt tablo).
    // Barkod satırı açıksa taban yükseklik yükselir (2. satıra yer açılır).
    final minRow = showBarcode ? 16.0 : 11.0;
    final rowH = _posterClampWeb(217 / page.length, minRow, 50);
    final nameSize =
        _posterClampWeb(rowH * (showBarcode ? 0.56 : 0.72), 10, 28);
    final priceSize = _posterClampWeb(rowH * 0.8, 13, 34);
    final numSize = _posterClampWeb(rowH * 0.4, 8, 16);
    final barcodeSize = _posterClampWeb(rowH * 0.26, 7, 12);
    for (var i = 0; i < page.length; i++) {
      final it = page[i];
      final barcodeHtml = (showBarcode && it.barcode.isNotEmpty)
          ? '<span class="pbarcode" style="font-size:${barcodeSize}pt">${_esc(it.barcode)}</span>'
          : '';
      rows.write('''
        <div class="prow" style="height:${rowH}mm;background:${i.isEven ? '#fff' : '#f4f5f7'}">
          <span class="pnum" style="font-size:${numSize}pt">${i + 1}.</span>
          <span class="pnamecol">
            <span class="pname" style="font-size:${nameSize}pt">${_esc(it.productName)}</span>
            $barcodeHtml
          </span>
          <span class="pprice" style="font-size:${priceSize}pt">${_esc(formatNumber(it.price))} TL</span>
        </div>''');
    }
  }

  final pageLabelHtml =
      pageLabel == null ? '' : '<span class="ppage">Sayfa $pageLabel</span>';

  return '''
    <div class="psheet">
      <div class="phead">
        $logoHtml
        <span class="ptitle">${_esc(title)}</span>
        $pageLabelHtml
      </div>
      <div class="prule"></div>
      <div class="plist">$rows</div>
      <div class="pfootrule"></div>
      <div class="pfoot">
        <span>Toplam ${page.length} ürün</span>
        <span>${_esc(formatShortDate(generatedAt))}</span>
      </div>
    </div>''';
}

String _buildPosterHtml({
  required List<LabelSlot> items,
  required String title,
  bool showBarcode = false,
  String? logoDataUrl,
}) {
  final pages = paginatePosterItems(items);
  final now = DateTime.now();
  final sheets = StringBuffer();
  for (var p = 0; p < pages.length; p++) {
    sheets.writeln(_posterPageHtml(
      pages[p],
      title,
      showBarcode,
      logoDataUrl,
      now,
      pages.length > 1 ? '${p + 1} / ${pages.length}' : null,
    ));
  }

  // A4 portrait 210×297mm; kenar üst/alt 18mm, sol/sağ 16mm.
  return '''
<!DOCTYPE html>
<html lang="tr">
<head>
<meta charset="utf-8">
<title>${_esc(title)}</title>
<style>
  @page { size: A4 portrait; margin: 18mm 16mm; }
  * { box-sizing: border-box; }
  html, body { margin: 0; padding: 0; }
  body {
    font-family: Arial, Helvetica, sans-serif;
    color: #000;
    -webkit-print-color-adjust: exact;
    print-color-adjust: exact;
  }
  .psheet {
    width: 178mm;
    min-height: 261mm;
    display: flex;
    flex-direction: column;
    page-break-after: always;
  }
  .psheet:last-child { page-break-after: auto; }
  .phead {
    display: flex;
    align-items: center;
    gap: 8mm;
  }
  .plogo-img { max-width: 30mm; max-height: 16mm; object-fit: contain; }
  .ptitle {
    flex: 1 1 auto;
    min-width: 0;
    font-size: 22pt;
    font-weight: 800;
    letter-spacing: 0.5px;
    color: #1B2A4A;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }
  .ppage { font-size: 9pt; color: #6b7280; }
  .prule { height: 1.2mm; background: #1B2A4A; margin: 3mm 0 4mm; }
  .plist { flex: 1 1 auto; display: flex; flex-direction: column; }
  .pempty {
    flex: 1 1 auto;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 12pt;
    color: #6b7280;
  }
  .prow {
    display: flex;
    align-items: center;
    padding: 0 4mm;
    font-variant-numeric: tabular-nums;
  }
  .pnum { flex: 0 0 9mm; color: #6b7280; }
  .pnamecol {
    flex: 1 1 auto;
    min-width: 0;
    display: flex;
    flex-direction: column;
  }
  .pname { font-weight: 700; }
  .pbarcode { color: #6b7280; font-variant-numeric: tabular-nums; }
  .pprice {
    flex: 0 0 auto;
    font-weight: 700;
    color: #1B2A4A;
    letter-spacing: -0.3px;
    margin-left: 6mm;
    white-space: nowrap;
  }
  .pfootrule { height: 0.6mm; background: #b8b8b8; margin: 3mm 0 1.5mm; }
  .pfoot {
    display: flex;
    justify-content: space-between;
    font-size: 8pt;
    color: #6b7280;
  }
</style>
</head>
<body onload="window.focus(); window.print();">
  $sheets
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

// ─── İndirim Etiketi — 2 sütun × 2 satır = 4 etiket ───────────────────────────
// Logo/tagline Faz D'den itibaren kiracı-bazlı (Geniş Logo ile PAYLAŞILIR) +
// ince ayraç + ürün adı (BÜYÜK HARF) + tek satır kırmızı "%X İNDİRİM" bandı +
// "ESKİ FİYAT: " (siyah, üzeri KIRMIZI çizili) + kutulu "YENİ FİYAT" (kırmızı
// hero) + Code128 + alt satır (barkod no + tarih YYAAGG). Kullanıcı referans
// mockup'ına göre tasarlanmıştır.

String _discountDateLabelWeb(DateTime d) =>
    '${(d.year % 100).toString().padLeft(2, '0')}'
    '${d.month.toString().padLeft(2, '0')}'
    '${d.day.toString().padLeft(2, '0')}';

String _discountCellHtml(DiscountLabelSlot? slot, String? logoDataUrl,
    num defaultPercent, String tagline) {
  if (slot == null) {
    return '<div class="dscell empty"></div>';
  }

  final bc = _barcodeSvg(slot.barcode);
  final bcHtml = bc.isEmpty ? '' : '<div class="ds-bc">$bc</div>';
  final bcNo = _esc(slot.barcode);
  // Hane-başı tik — tiksizse VEYA logo yüklenmediyse logo alanı BOŞ bırakılır
  // (slot yüksekliği .ds-logo-slot ile korunur, satır kaymaz).
  final logoHtml = (slot.showLogo && logoDataUrl != null && logoDataUrl.isNotEmpty)
      ? '<img class="ds-logo-img" src="${_esc(logoDataUrl)}" alt="logo">'
      : '';
  final taglineHtml =
      tagline.isEmpty ? '' : '<div class="ds-tagline">${_esc(tagline)}</div>';

  return '''
    <div class="dscell">
      <div class="ds-logo-slot">$logoHtml</div>
      $taglineHtml
      <div class="ds-rule"></div>
      <div class="ds-pname">${_esc(slot.productName)}</div>
      <div class="ds-badge">%${slot.effectivePercent(defaultPercent).round()} İNDİRİM</div>
      <div class="ds-old-row">
        <span class="ds-old-label">ESKİ FİYAT:&nbsp;</span>
        <span class="ds-old">${_esc(formatNumber(slot.oldPrice))} TL</span>
      </div>
      <div class="ds-new-box">
        <div class="ds-new-label">YENİ FİYAT</div>
        <div class="ds-new">${_esc(formatNumber(slot.newPrice(defaultPercent)))} TL</div>
      </div>
      $bcHtml
      <div class="ds-bottom">
        <span class="ds-bcno">$bcNo</span>
        <span class="ds-cdate">${_esc(_discountDateLabelWeb(slot.createdAt))}</span>
      </div>
    </div>''';
}

String _buildDiscountHtml({
  required List<DiscountLabelSlot?> slots,
  String? logoDataUrl,
  required num defaultPercent,
  String tagline = '',
}) {
  final pages = paginateDiscountSlots(slots);
  final sheets = StringBuffer();
  for (final page in pages) {
    final cells = StringBuffer();
    for (final slot in page) {
      cells.writeln(
          _discountCellHtml(slot, logoDataUrl, defaultPercent, tagline));
    }
    sheets.writeln('<div class="sheet">$cells</div>');
  }

  // A4 portrait 210×297mm, kenar 10mm → yazdırılabilir 190×277mm.
  // 2 sütun → 95mm, 2 satır → ~138.5mm hücre (4 etiket/sayfa, ferah,
  // profesyonel); toplam > 4 ise 2., 3. sayfaya taşar (`page-break-after`).
  return '''
<!DOCTYPE html>
<html lang="tr">
<head>
<meta charset="utf-8">
<title>İndirim Etiketleri</title>
<style>
  @page { size: A4 portrait; margin: 10mm; }
  * { box-sizing: border-box; }
  html, body { margin: 0; padding: 0; }
  body {
    font-family: Arial, Helvetica, sans-serif;
    color: #000;
    -webkit-print-color-adjust: exact;
    print-color-adjust: exact;
  }
  .sheet {
    width: 190mm;
    display: grid;
    grid-template-columns: repeat(2, 1fr);
    grid-auto-rows: 138.5mm;
    gap: 0;
    page-break-after: always;
  }
  .sheet:last-child { page-break-after: auto; }
  .dscell {
    position: relative;
    border: 0.2mm solid #b8b8b8;
    padding: 3mm 4mm;
    overflow: hidden;
    display: flex;
    flex-direction: column;
    align-items: center;
  }
  .dscell.empty { border-color: #e0e0e0; }
  .ds-logo-slot {
    height: 17mm;
    width: 100%;
    flex: 0 0 auto;
    display: flex;
    align-items: center;
    justify-content: center;
  }
  .ds-logo-img {
    max-width: 60%;
    max-height: 100%;
    object-fit: contain;
  }
  .ds-tagline {
    font-size: 7.5pt;
    font-weight: 800;
    letter-spacing: 0.3px;
    color: #000;
    text-align: center;
    flex: 0 0 auto;
    margin-top: 0.5mm;
  }
  .ds-rule {
    width: 100%;
    height: 0.2mm;
    background: #ccc;
    margin: 1.5mm 0;
    flex: 0 0 auto;
  }
  .ds-pname {
    font-size: 12pt;
    font-weight: 800;
    line-height: 1.15;
    text-transform: uppercase;
    text-align: center;
    flex: 0 0 auto;
    width: 100%;
    display: -webkit-box;
    -webkit-line-clamp: 2;
    -webkit-box-orient: vertical;
    overflow: hidden;
  }
  .ds-badge {
    width: 100%;
    box-sizing: border-box;
    margin-top: 1.5mm;
    padding: 1.2mm 0;
    border-radius: 1.2mm;
    background: #C0392B;
    color: #fff;
    font-weight: 800;
    font-size: 17pt;
    text-align: center;
    flex: 0 0 auto;
  }
  .ds-old-row {
    margin-top: 1.5mm;
    flex: 0 0 auto;
    white-space: nowrap;
  }
  .ds-old-label { font-size: 9pt; font-weight: 700; color: #000; }
  .ds-old {
    font-size: 20pt;
    font-weight: 800;
    color: #000;
    text-decoration: line-through;
    text-decoration-color: #C0392B;
    font-variant-numeric: tabular-nums;
  }
  .ds-new-box {
    width: 100%;
    box-sizing: border-box;
    margin-top: 1mm;
    padding: 0.8mm 0;
    border: 0.3mm solid #C0392B;
    border-radius: 1.2mm;
    text-align: center;
    flex: 0 0 auto;
  }
  .ds-new-label {
    font-size: 7.5pt;
    font-weight: 800;
    letter-spacing: 0.4px;
    color: #C0392B;
  }
  .ds-new {
    font-weight: 800;
    font-size: 40pt;
    line-height: 1.1;
    letter-spacing: -0.5px;
    white-space: nowrap;
    color: #C0392B;
    font-variant-numeric: tabular-nums;
  }
  .ds-bc {
    /* Bölge mevcut merkezde KALIR (flex:1 1 auto değişmedi); asıl barkod
       grafiği yalnız bu bölgenin 1/3 yüksekliğini kaplar, dikey ortalı
       (align-items:center) — kullanıcı isteği, konum sabit. */
    flex: 1 1 auto;
    min-height: 0;
    width: 75%;
    margin: 1.5mm auto 0;
    display: flex;
    align-items: center;
    justify-content: center;
  }
  .ds-bc svg { width: 100%; height: 33%; display: block; }
  .ds-bottom {
    display: flex;
    align-items: flex-end;
    justify-content: space-between;
    width: 100%;
    flex: 0 0 auto;
    font-variant-numeric: tabular-nums;
  }
  .ds-bcno { font-size: 15pt; letter-spacing: 0.5px; text-align: center; }
  .ds-cdate { font-size: 7pt; color: #444; }
</style>
</head>
<body onload="window.focus(); window.print();">
  $sheets
</body>
</html>''';
}
