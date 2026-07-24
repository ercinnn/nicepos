import 'dart:convert';
import 'dart:typed_data';

import 'package:barcode/barcode.dart' as bc;
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/utils/formatters.dart';
import 'models/label_slot.dart';
import 'models/product_label_item.dart';

// ═══════════════════════════════════════════════════════════════════════════
// Raf etiketi PDF üretimi (KARAR v1.11) — her platformda (native Android dahil)
// gerçek A4 dikey PDF. Izgara: 3 sütun × 8 satır = 24 etiket. Etiket-içi düzen
// KARAR v1.10 ile BİREBİR: üst bant SOL logo (yoksa mağaza ikonu) + baskın FİYAT
// (iri bold, price1 + " TL", altın YOK) → ürün adı → Code128 → en alt barkod no
// (sol) + oluşturma tarihi (sağ). Çıktı SİYAH/BEYAZ; app altını baskıya taşınmaz.
// ═══════════════════════════════════════════════════════════════════════════

const int _kCols = 3;
const int _kRows = 8;

// Mağaza ikonu fallback (logo yoksa) — Material "store" path, ink lacivert
// (KARAR v1.10: standart ikon fallback, aynı yuva boyutu). Baskı için tek renk.
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

const PdfColor _hairline = PdfColor.fromInt(0xFFB8B8B8);
const PdfColor _hairlineEmpty = PdfColor.fromInt(0xFFE0E0E0);
const PdfColor _dateGrey = PdfColor.fromInt(0xFF555555);

/// Dolu/boş 24 haneyi A4 dikey 3×8 raf etiketi PDF'ine dönüştürür ve ham byte'ları
/// döndürür. `logoDataUrl` = base64 data URL (`data:image/...;base64,...`), yoksa
/// mağaza ikonu fallback kullanılır. Türkçe karakterler için Roboto (Google Font)
/// gömülür; ağ/hata durumunda gömülü standart yazı tipine düşer.
Future<Uint8List> buildLabelsPdf({
  required List<LabelSlot?> slots,
  String? logoDataUrl,
}) async {
  // Türkçe glif desteği için Roboto gömülür (varsayılan Helvetica ş/ğ/ı/İ'yi
  // kapsamaz). Ağ erişimi yoksa temel temaya düşer — PDF yine üretilir.
  pw.ThemeData theme;
  try {
    final base = await PdfGoogleFonts.robotoRegular();
    final bold = await PdfGoogleFonts.robotoBold();
    theme = pw.ThemeData.withFont(base: base, bold: bold);
  } catch (_) {
    theme = pw.ThemeData.base();
  }

  // Logo byte'larını PDF başına bir kez çöz (her hücrede tekrar decode etme).
  pw.MemoryImage? logoImage;
  if (logoDataUrl != null && logoDataUrl.isNotEmpty) {
    final i = logoDataUrl.indexOf(',');
    if (i >= 0) {
      try {
        logoImage = pw.MemoryImage(base64Decode(logoDataUrl.substring(i + 1)));
      } catch (_) {
        logoImage = null;
      }
    }
  }

  final doc = pw.Document(theme: theme);
  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.all(5 * PdfPageFormat.mm), // ~5mm kenar
      build: (context) {
        return pw.Column(
          children: List.generate(_kRows, (r) {
            return pw.Expanded(
              child: pw.Row(
                children: List.generate(_kCols, (c) {
                  final idx = r * _kCols + c;
                  final slot = idx < slots.length ? slots[idx] : null;
                  return pw.Expanded(child: _cell(slot, logoImage));
                }),
              ),
            );
          }),
        );
      },
    ),
  );

  return doc.save();
}

// Tek etiket hücresi (referans jpg dili). Boş hane → yalnız ince kesim kılavuzu.
pw.Widget _cell(LabelSlot? slot, pw.MemoryImage? logoImage) {
  if (slot == null) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _hairlineEmpty, width: 0.5),
      ),
    );
  }

  final logo = logoImage != null
      ? pw.Image(logoImage, fit: pw.BoxFit.contain)
      : pw.SvgImage(svg: _storeIconSvg);

  return pw.Container(
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: _hairline, width: 0.5),
    ),
    padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      mainAxisAlignment: pw.MainAxisAlignment.start,
      children: [
        // Üst bant: logo (sol) + FİYAT hero (baskın, sağ)
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.SizedBox(width: 52, height: 35, child: logo),
            pw.SizedBox(width: 4),
            pw.Expanded(
              child: pw.FittedBox(
                fit: pw.BoxFit.scaleDown,
                alignment: pw.Alignment.center,
                child: pw.Text(
                  '${formatNumber(slot.price)} TL',
                  style: pw.TextStyle(
                    fontSize: 28.6,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: -0.5,
                    color: PdfColors.black,
                  ),
                ),
              ),
            ),
          ],
        ),
        // Ürün adı (2 satır, taşarsa kısalt) — hücre genişliğine ortalı
        pw.SizedBox(
          width: double.infinity,
          child: pw.Text(
            slot.productName.toUpperCase(),
            textAlign: pw.TextAlign.center,
            maxLines: 2,
            overflow: pw.TextOverflow.clip,
            style: pw.TextStyle(
              fontSize: 8.75,
              fontWeight: pw.FontWeight.bold,
              lineSpacing: 0.5,
              color: PdfColors.black,
            ),
          ),
        ),
        // Barkod çizgileri (Code128; geçersizse boş bırak — fiyat/ad korunur).
        // Esnek öğe: sabit öğeler (üst bant, ürün adı, alt satır) yerini korur;
        // taşarsa yalnız barkod çizgisi kısalır. Yatayda %80'e ortalı
        // (%10 boşluk + %80 barkod + %10 boşluk = 1:8:1 flex; pdf paketinde
        // FractionallySizedBox yok, flex Row eşdeğeri).
        pw.Expanded(
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Spacer(flex: 1),
              pw.Expanded(
                flex: 8,
                child: bc.Barcode.code128().isValid(slot.barcode)
                    ? pw.BarcodeWidget(
                        barcode: bc.Barcode.code128(),
                        data: slot.barcode,
                        drawText: false,
                        color: PdfColors.black,
                      )
                    : pw.SizedBox(),
              ),
              pw.Spacer(flex: 1),
            ],
          ),
        ),
        // En alt: barkod no (sol) + oluşturma tarihi (sağ)
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Expanded(
              child: pw.Text(
                slot.barcode,
                maxLines: 1,
                overflow: pw.TextOverflow.clip,
                style: pw.TextStyle(
                  fontSize: 12,
                  letterSpacing: 0.5,
                  color: PdfColors.black,
                ),
              ),
            ),
            pw.Text(
              formatShortDate(slot.createdAt),
              style: const pw.TextStyle(fontSize: 5, color: _dateGrey),
            ),
          ],
        ),
      ],
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// Geniş Logo etiketi PDF üretimi (KARAR v1.14 / v1.14.2) — 2 sütun × 5 satır =
// 10 etiket. Kesin baskı geometrisi (önizleme = HTML = PDF, üçü BİREBİR):
//   • A4 dikey 210×297mm · hücre 88×55mm · kenar üst/alt 11mm, sol/sağ 17mm
//     (KARAR v1.14.4) → 10 etiket A4'e tam ortalı.
//   • Marka figürü (genis_logo_figur.png, RENKLİ — tente + NiCE + gövde + yan
//     çizgiler + alt çizgi) hücreyi doldurur; fiyat/ad/barkod ÜZERİNE bindirilir.
// Etiket-içi hizalama (figür sınırları içinde, hücre oranıyla):
//   1) FİYAT — tentenin açık turuncu iç dikdörtgeninin tam merkezine (yatay+dikey
//      ortalı), kalın (w800) siyah tabular, taşarsa FittedBox scaleDown, altın YOK.
//   2) Ürün adı — gövdede, yan çizgilerin içinde, ortalı, en çok 2 satır.
//   3) Code128 barkod — gövde iç genişliğinde ortalı, çizgi yüksekliği yarıya
//      indirildi (v1.14.2).
//   4) Alt satır — barkod no SOLDA · tarih SAĞDA, gövde alt çizgisinin içinde.
// Figür bilinçli olarak RENKLİ basılır (siyah/beyaz kuralının marka istisnası).
// ═══════════════════════════════════════════════════════════════════════════

// Geniş Logo ızgarası (data katmanı yerel sabitleri; application katmanının
// kWideCols/kWideRows'una bağlı kalmadan, dar PDF'in _kCols/_kRows deseni gibi).
const int _kWideCols = 2;
const int _kWideRows = 5;

// Etiket-içi hizalama oranları (hücre = figür; figür crop'undan ölçüldü, KARAR
// v1.14.2). Üç çıktı (önizleme/HTML/PDF) bu oranları paylaşır.
const double _kWFigPriceLeft = 0.13; // fiyat kutusu: tentenin açık iç dikdörtgeni
const double _kWFigPriceTop = 0.065;
const double _kWFigPriceW = 0.74;
const double _kWFigPriceH = 0.25;
const double _kWFigBodyLeft = 0.10; // gövde (yan çizgilerin içi) metin alanı
const double _kWFigBodyTop = 0.585;
const double _kWFigBodyW = 0.80;
const double _kWFigBodyH = 0.395;
const double _kWFigBarcodeH = 0.13; // barkod çizgi yüksekliği (yarıya indi)
const double _kWFigBottomH = 0.095; // alt satır (barkod no + tarih)

// Ürün adı (KARAR v1.14.4): ad, gövdenin üst esnek alanında ÜSTE hizalı.
// v1.14.3'teki 1.5 harf aşağı-itme, 2 satırlı adlar barkoda giriyordu →
// ~5mm yukarı alındı (shift 0). Barkod + alt satır YERİNDE KALIR.
const double _kWNameSize = 8;
const double _kWNameShift =
    2.5 * PdfPageFormat.mm; // v1.14.6: ad 2.5mm aşağı, üste hizalı sabit offset

/// Dolu/boş 10 haneyi A4 dikey 2×5 Geniş Logo etiketi PDF'ine dönüştürür.
Future<Uint8List> buildWideLabelsPdf({
  required List<LabelSlot?> slots,
}) async {
  pw.ThemeData theme;
  try {
    final base = await PdfGoogleFonts.robotoRegular();
    final bold = await PdfGoogleFonts.robotoBold();
    theme = pw.ThemeData.withFont(base: base, bold: bold);
  } catch (_) {
    theme = pw.ThemeData.base();
  }

  // Marka figürü (RENKLİ) — PDF başına bir kez oku.
  pw.MemoryImage? figurImage;
  try {
    final data = await rootBundle.load('genis_logo_figur.png');
    figurImage = pw.MemoryImage(data.buffer.asUint8List());
  } catch (_) {
    figurImage = null;
  }

  final doc = pw.Document(theme: theme);
  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      // Kenar boşluğu (KARAR v1.14.4 — hücre 94→88mm): üst/alt 11mm, sol/sağ
      // 17mm → 2×5 hücre 88×55mm A4'e tam ortalı ((210−2×88)/2 = 17).
      margin: pw.EdgeInsets.symmetric(
        vertical: 11 * PdfPageFormat.mm,
        horizontal: 17 * PdfPageFormat.mm,
      ),
      build: (context) {
        return pw.Column(
          children: List.generate(_kWideRows, (r) {
            return pw.Expanded(
              child: pw.Row(
                children: List.generate(_kWideCols, (c) {
                  final idx = r * _kWideCols + c;
                  final slot = idx < slots.length ? slots[idx] : null;
                  return pw.Expanded(child: _wideCell(slot, figurImage));
                }),
              ),
            );
          }),
        );
      },
    ),
  );

  return doc.save();
}

// Tek Geniş Logo etiket hücresi (figür arka planı + fiyat/ad/barkod overlay).
// Boş hane → yalnız ince kesim kılavuzu.
pw.Widget _wideCell(LabelSlot? slot, pw.MemoryImage? figurImage) {
  if (slot == null) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _hairlineEmpty, width: 0.5),
      ),
    );
  }

  final hasBarcode = bc.Barcode.code128().isValid(slot.barcode);

  return pw.Container(
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: _hairline, width: 0.5),
    ),
    child: pw.LayoutBuilder(
      builder: (context, cons) {
        final w = cons!.maxWidth;
        final h = cons.maxHeight;
        return pw.Stack(
          children: [
            // Figür arka planı — hücreyi doldurur (BoxFit.fill).
            if (figurImage != null)
              pw.Positioned.fill(
                child: pw.Image(figurImage, fit: pw.BoxFit.fill),
              ),
            // FİYAT — tentenin açık iç dikdörtgeni merkezine ortalı.
            // (pdf paketinin Positioned'ı width/height almaz → çocuk SizedBox.)
            pw.Positioned(
              left: w * _kWFigPriceLeft,
              top: h * _kWFigPriceTop,
              child: pw.SizedBox(
                width: w * _kWFigPriceW,
                height: h * _kWFigPriceH,
                child: pw.Center(
                  child: pw.FittedBox(
                    fit: pw.BoxFit.scaleDown,
                    child: pw.Text(
                      '${formatNumber(slot.price)} TL',
                      style: pw.TextStyle(
                        fontSize: 30,
                        fontWeight: pw.FontWeight.bold,
                        letterSpacing: -0.5,
                        color: PdfColors.black,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Gövde: ürün adı + barkod + alt satır (yan çizgilerin içinde).
            pw.Positioned(
              left: w * _kWFigBodyLeft,
              top: h * _kWFigBodyTop,
              child: pw.SizedBox(
                width: w * _kWFigBodyW,
                height: h * _kWFigBodyH,
                child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  // Ürün adı (ortalı, en çok 2 satır) — üstteki esnek alan.
                  // v1.14.4: ÜSTE hizalı (_kWNameShift=0); 2 satır artık
                  // barkoda girmez. ClipRect taşarsa kırpar.
                  pw.Expanded(
                    child: pw.ClipRect(
                      child: pw.Padding(
                        padding: const pw.EdgeInsets.only(top: _kWNameShift),
                        child: pw.Align(
                          alignment: pw.Alignment.topCenter,
                          child: pw.Text(
                            slot.productName.toUpperCase(),
                            textAlign: pw.TextAlign.center,
                            maxLines: 2,
                            overflow: pw.TextOverflow.clip,
                            style: pw.TextStyle(
                              fontSize: _kWNameSize,
                              fontWeight: pw.FontWeight.bold,
                              lineSpacing: 0.5,
                              color: PdfColors.black,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Code128 barkod — yarı yükseklik, gövde iç genişliğinde ortalı.
                  pw.SizedBox(
                    height: h * _kWFigBarcodeH,
                    width: double.infinity,
                    child: hasBarcode
                        ? pw.BarcodeWidget(
                            barcode: bc.Barcode.code128(),
                            data: slot.barcode,
                            drawText: false,
                            color: PdfColors.black,
                          )
                        : pw.SizedBox(),
                  ),
                  // Alt satır: barkod no SOLDA · tarih SAĞDA.
                  pw.SizedBox(
                    height: h * _kWFigBottomH,
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Expanded(
                          child: pw.Text(
                            slot.barcode,
                            maxLines: 1,
                            overflow: pw.TextOverflow.clip,
                            style: pw.TextStyle(
                              fontSize: 8,
                              letterSpacing: 0.3,
                              color: PdfColors.black,
                            ),
                          ),
                        ),
                        pw.Text(
                          formatShortDate(slot.createdAt),
                          style: const pw.TextStyle(
                              fontSize: 5, color: _dateGrey),
                        ),
                      ],
                    ),
                  ),
                ],
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// Büyük Etiket PDF üretimi (KARAR v1.19) — A4 dikey, merkez haç ile 2 sütun ×
// 2 satır = 4 A5 etiket. Kesin baskı geometrisi (önizleme = HTML = PDF, üçü
// BİREBİR): hücre 105×148.5mm, dış margin YOK (merkez haç = bitişik hücre
// kenarlıkları), iç güvenli boşluk 6mm. Etiket-içi düzen dar-logo (Yeni Etiket)
// ile aynı öğe seti, A5'e oranlanmış (~1.8× büyük). Çıktı SİYAH/BEYAZ + RENKLİ
// mağaza logosu (yoksa mağaza ikonu fallback).
// ═══════════════════════════════════════════════════════════════════════════

const int _kQuadCols = 2;
const int _kQuadRows = 2;

// KARAR v1.20.1 — üst bant (kırmızı) SABİT yükseklik (Flutter
// `_kQuadTopBandHeightMm` ile birebir aynı mm değeri; üç çıktı BİREBİR): v1.20
// bandı "içerik kadar esniyordu", 2 satırlık ürün adında büyüyen bant + fiyat
// kutusunun sabit bütçesi birleşince barkod alanı sıfır/negatif yüksekliğe
// düşüp `barcode` paketinin `assert(height > 0)` çökmesine yol açıyordu. Bant
// artık 2 satırlık ürün adı DAHİL en kötü durum baştan hesaplanıp SABİTLENİR.
const double _kQuadTopBandHeightMm = 23.3;

// Savunma katmanı (madde 3): barkod alanına ayrılan gerçek yükseklik bu
// eşiğin altına düşerse `pw.BarcodeWidget` HİÇ render edilmez — `assert`
// asla fırlatılmaz. Normal koşulda (madde 1 ile) bu dala girilmesi beklenmez.
const double _kQuadBarcodeMinHeightMm = 2;

/// Dolu/boş 4 haneyi A4 dikey 2×2 Büyük Etiket PDF'ine dönüştürür.
Future<Uint8List> buildQuadLabelsPdf({
  required List<LabelSlot?> slots,
  String? logoDataUrl,
}) async {
  pw.ThemeData theme;
  try {
    final base = await PdfGoogleFonts.robotoRegular();
    final bold = await PdfGoogleFonts.robotoBold();
    theme = pw.ThemeData.withFont(base: base, bold: bold);
  } catch (_) {
    theme = pw.ThemeData.base();
  }

  pw.MemoryImage? logoImage;
  if (logoDataUrl != null && logoDataUrl.isNotEmpty) {
    final i = logoDataUrl.indexOf(',');
    if (i >= 0) {
      try {
        logoImage = pw.MemoryImage(base64Decode(logoDataUrl.substring(i + 1)));
      } catch (_) {
        logoImage = null;
      }
    }
  }

  final doc = pw.Document(theme: theme);
  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero, // dış margin YOK; merkez haç = hücre ayraçları
      build: (context) {
        return pw.Column(
          children: List.generate(_kQuadRows, (r) {
            return pw.Expanded(
              child: pw.Row(
                children: List.generate(_kQuadCols, (c) {
                  final idx = r * _kQuadCols + c;
                  final slot = idx < slots.length ? slots[idx] : null;
                  return pw.Expanded(child: _quadCell(slot, logoImage));
                }),
              ),
            );
          }),
        );
      },
    ),
  );

  return doc.save();
}

// Kırmızı başlık bandı zemini (KARAR v1.20) — `AppColors.danger` #C0392B,
// bu bir baskı-çıktısı rengi (§4 iki-kavram ayrımı), app "hata" semantiği YOK.
const PdfColor _quadRed = PdfColor.fromInt(0xFFC0392B);

// Tek Büyük Etiket hücresi (KARAR v1.20 — kırmızı başlık bandı + renkli fiyat
// kutusu, rozetler kaldırıldı). Boş hane → yalnız ince kesim kılavuzu.
pw.Widget _quadCell(LabelSlot? slot, pw.MemoryImage? logoImage) {
  if (slot == null) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _hairlineEmpty, width: 0.5),
      ),
    );
  }

  final logo = logoImage != null
      ? pw.Image(logoImage, fit: pw.BoxFit.contain)
      : pw.SvgImage(svg: _storeIconSvgWhite);

  return pw.Container(
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: _hairline, width: 0.5),
    ),
    padding: pw.EdgeInsets.all(6 * PdfPageFormat.mm),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      mainAxisAlignment: pw.MainAxisAlignment.start,
      children: [
        // 1. Üst bant: KIRMIZI zemin, tam genişlik, köşe radius YOK. SOL logo
        //    (renkli; yoksa BEYAZ storefront fallback) + "ÖZEL FİYAT" + ürün
        //    adı (UPPERCASE, beyaz ~%90 alfa).
        pw.Container(
          width: double.infinity,
          height: _kQuadTopBandHeightMm * PdfPageFormat.mm,
          color: _quadRed,
          padding: const pw.EdgeInsets.symmetric(
            horizontal: 3 * PdfPageFormat.mm,
            vertical: 2.4 * PdfPageFormat.mm,
          ),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.SizedBox(width: 45, height: 39, child: logo),
              pw.SizedBox(width: 6),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  mainAxisSize: pw.MainAxisSize.min,
                  children: [
                    pw.Text(
                      'ÖZEL FİYAT',
                      maxLines: 1,
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        letterSpacing: 0.5,
                        color: PdfColors.white,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      slot.productName.toUpperCase(),
                      maxLines: 2,
                      overflow: pw.TextOverflow.clip,
                      style: pw.TextStyle(
                        fontSize: 9.5,
                        fontWeight: pw.FontWeight.bold,
                        lineSpacing: 1,
                        color: PdfColors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 3 * PdfPageFormat.mm),
        // 3. Fiyat kutusu: beyaz zemin + kırmızı ince kenarlık.
        pw.Container(
          width: double.infinity,
          // KARAR v1.20.1 madde 2: dikey iç boşluk ~25% daraltıldı (3mm →
          // 2.25mm) — ek güvenlik payı için; renk/sıra/hiyerarşi DEĞİŞMEDİ.
          padding: const pw.EdgeInsets.symmetric(
            horizontal: 4 * PdfPageFormat.mm,
            vertical: 2.25 * PdfPageFormat.mm,
          ),
          decoration: pw.BoxDecoration(
            color: PdfColors.white,
            border: pw.Border.all(color: _quadRed, width: 1.4),
            borderRadius: pw.BorderRadius.circular(3 * PdfPageFormat.mm),
          ),
          child: pw.Column(
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              pw.Text(
                'SATIŞ FİYATI',
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  letterSpacing: 1,
                  color: _quadRed,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.FittedBox(
                fit: pw.BoxFit.scaleDown,
                alignment: pw.Alignment.center,
                child: pw.Text(
                  '${formatNumber(slot.price)} TL',
                  style: pw.TextStyle(
                    fontSize: 58,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: -0.5,
                    color: _quadRed,
                  ),
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'KDV DAHİLDİR',
                style: pw.TextStyle(
                  fontSize: 7.5,
                  color: PdfColor.fromInt(0xFFCB6156), // muted kırmızı
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 2 * PdfPageFormat.mm),
        // 4. Kesikli ayraç — nötr `#B8B8B8` (mevcut kesim-kılavuzu grisi);
        //    pdf paketinde native dashed-border yok, eşit segment döngüsüyle
        //    aynı görsel dil (HTML tarafı native `border-top:dashed` kullanır).
        pw.Row(
          children: List.generate(24, (i) {
            return pw.Expanded(
              child: pw.Container(
                height: 0.5 * PdfPageFormat.mm,
                color: i.isEven ? _hairline : PdfColors.white,
              ),
            );
          }),
        ),
        pw.SizedBox(height: 2 * PdfPageFormat.mm),
        // 5. Barkod çizgileri (Code128) — esnek öğe; %80'e ortalı (1:8:1 flex).
        // Savunma katmanı (KARAR v1.20.1 madde 3): gerçek yükseklik eşiğin
        // altındaysa barkodu HİÇ render etme — `assert(height > 0)` çökmesi
        // asla tetiklenmez.
        pw.Expanded(
          child: pw.LayoutBuilder(
            builder: (context, constraints) {
              final maxHeight = constraints?.maxHeight ?? double.infinity;
              if (maxHeight < _kQuadBarcodeMinHeightMm * PdfPageFormat.mm) {
                return pw.SizedBox();
              }
              return pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Spacer(flex: 1),
                  pw.Expanded(
                    flex: 8,
                    child: bc.Barcode.code128().isValid(slot.barcode)
                        ? pw.BarcodeWidget(
                            barcode: bc.Barcode.code128(),
                            data: slot.barcode,
                            drawText: false,
                            color: PdfColors.black,
                          )
                        : pw.SizedBox(),
                  ),
                  pw.Spacer(flex: 1),
                ],
              );
            },
          ),
        ),
        // 6. En alt: barkod no (sol) + oluşturma tarihi (sağ) — DEĞİŞMEDİ.
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Expanded(
              child: pw.Text(
                slot.barcode,
                maxLines: 1,
                overflow: pw.TextOverflow.clip,
                style: pw.TextStyle(
                  fontSize: 22,
                  letterSpacing: 0.5,
                  color: PdfColors.black,
                ),
              ),
            ),
            pw.Text(
              formatShortDate(slot.createdAt),
              style: const pw.TextStyle(fontSize: 9, color: _dateGrey),
            ),
          ],
        ),
      ],
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// Ürün Etiketi PDF üretimi (KARAR v1.21) — adet-tabanlı, FİYATSIZ/LOGOSUZ barkod
// etiketi. A4 dikey, 6 sütun × 12 satır = 72 etiket/sayfa. Sayfa boşluğu üst/alt
// 10mm, yatay 0. Hücre 35×23mm, her kenardan 3mm iç pay → içerik 29×17mm. Toplam
// > 72 ise 2., 3. sayfaya taşar (çok-sayfalı). Etiket-içi (ortalı, üstten alta):
// ürün adı 2 satır sabit + Code128 barkod (SABİT 7mm) + barkod no. Çıktı
// SİYAH/BEYAZ; die-cut → baskıda kesim çizgisi YOK. Önizleme = HTML = PDF birebir.
// ═══════════════════════════════════════════════════════════════════════════

/// Kalemleri (adet kadar çoğaltarak) çok-sayfalı A4 dikey 6×12 Ürün Etiketi
/// PDF'ine dönüştürür ve ham byte'ları döndürür.
Future<Uint8List> buildProductLabelsPdf({
  required List<ProductLabelItem> items,
}) async {
  pw.ThemeData theme;
  try {
    final base = await PdfGoogleFonts.robotoRegular();
    final bold = await PdfGoogleFonts.robotoBold();
    theme = pw.ThemeData.withFont(base: base, bold: bold);
  } catch (_) {
    theme = pw.ThemeData.base();
  }

  final pages = paginateProductLabels(items);
  final doc = pw.Document(theme: theme);
  for (final page in pages) {
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        // Sayfa boşluğu: üst/alt 10mm, yatay 0 (etiketler tam genişliği doldurur).
        margin: pw.EdgeInsets.symmetric(vertical: 10 * PdfPageFormat.mm),
        build: (context) {
          return pw.Column(
            children: List.generate(kProductLabelRows, (r) {
              return pw.Expanded(
                child: pw.Row(
                  children: List.generate(kProductLabelCols, (c) {
                    final idx = r * kProductLabelCols + c;
                    final it = idx < page.length ? page[idx] : null;
                    return pw.Expanded(child: _productCell(it));
                  }),
                ),
              );
            }),
          );
        },
      ),
    );
  }

  return doc.save();
}

// Tek Ürün Etiketi hücresi (KARAR v1.21). Boş hane → tamamen boş (die-cut →
// kesim çizgisi YOK). Etiket-içi: ürün adı 2 satır sabit (ortalı) + Code128
// barkod (SABİT 7mm; artan pay alt satırın altında kalır) + barkod no (ortalı,
// tabular). Fiyat/logo YOK. Ad `flex:0` + numara `flex:0`, barkod SABİT 7mm
// `SizedBox`; savunma katmanı (v1.20.1 dersi): gerçek yükseklik eşiğin altındaysa
// barkod HİÇ render edilmez (sabit 7mm'de tetiklenmez ama katman korunur).
pw.Widget _productCell(ProductLabelItem? it) {
  if (it == null) {
    // Boş hücre — die-cut, çerçeve/kesim çizgisi YOK.
    return pw.Container();
  }

  return pw.Container(
    padding: pw.EdgeInsets.all(3 * PdfPageFormat.mm),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      mainAxisAlignment: pw.MainAxisAlignment.start,
      children: [
        // 1. Ürün adı — 2 satır sabit alan (~4.4mm), ORTALI, uzun ad kırpılır.
        pw.SizedBox(
          height: 4.4 * PdfPageFormat.mm,
          width: double.infinity,
          child: pw.Center(
            child: pw.Text(
              it.productName.toUpperCase(),
              textAlign: pw.TextAlign.center,
              maxLines: 2,
              overflow: pw.TextOverflow.clip,
              style: pw.TextStyle(
                fontSize: 5,
                fontWeight: pw.FontWeight.bold,
                lineSpacing: 0.3,
                color: PdfColors.black,
              ),
            ),
          ),
        ),
        // 2. Code128 barkod — SABİT 7mm (KARAR v1.21.1), yatayda %80'e ortalı
        //    (1:8:1 flex). Artan ~3.6mm boşluk alt satırın altında kalır
        //    (Column mainAxisAlignment.start). Savunma: yükseklik eşiğin
        //    altındaysa HİÇ render etme (sabit 7mm'de tetiklenmez ama korunur).
        pw.SizedBox(
          height: 7 * PdfPageFormat.mm,
          child: pw.LayoutBuilder(
            builder: (context, constraints) {
              final maxHeight = constraints?.maxHeight ?? double.infinity;
              if (maxHeight < 2 * PdfPageFormat.mm) {
                return pw.SizedBox();
              }
              return pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Spacer(flex: 1),
                  pw.Expanded(
                    flex: 8,
                    child: bc.Barcode.code128().isValid(it.barcode)
                        ? pw.BarcodeWidget(
                            barcode: bc.Barcode.code128(),
                            data: it.barcode,
                            drawText: false,
                            color: PdfColors.black,
                          )
                        : pw.SizedBox(),
                  ),
                  pw.Spacer(flex: 1),
                ],
              );
            },
          ),
        ),
        // 3. Barkod no — ORTALI, tabular (fontFeatures pdf'te yok → düz), siyah.
        pw.SizedBox(
          width: double.infinity,
          child: pw.Text(
            it.barcode,
            textAlign: pw.TextAlign.center,
            maxLines: 1,
            overflow: pw.TextOverflow.clip,
            style: pw.TextStyle(
              fontSize: 6,
              letterSpacing: 0.3,
              color: PdfColors.black,
            ),
          ),
        ),
      ],
    ),
  );
}
