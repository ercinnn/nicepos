import 'dart:convert';
import 'dart:typed_data';

import 'package:barcode/barcode.dart' as bc;
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/utils/formatters.dart';
import 'models/discount_label_slot.dart';
import 'models/label_slot.dart';
import 'models/product_label_item.dart';
import 'models/tel_discount_label_slot.dart';

// ═══════════════════════════════════════════════════════════════════════════
// Raf etiketi PDF üretimi (KARAR v1.11) — her platformda (native Android dahil)
// gerçek A4 dikey PDF. Izgara: 3 sütun × 8 satır = 24 etiket. Etiket-içi düzen
// KARAR v1.10 ile BİREBİR: üst bant SOL logo (yoksa mağaza ikonu) + baskın FİYAT
// (iri bold, price1 + " TL", altın YOK) → ürün adı → Code128 → en alt barkod no
// (sol) + oluşturma tarihi (sağ). Çıktı SİYAH/BEYAZ; app altını baskıya taşınmaz.
// ═══════════════════════════════════════════════════════════════════════════

const int _kCols = 3;
const int _kRows = 8;

// Tel Etiketi ızgarası: Raf ile birebir aynı satır sayısı (yükseklik), yalnız
// yan yana 4 adet.
const int _kTelCols = 4;
const int _kTelRows = _kRows;

// Mağaza ikonu fallback (logo yoksa) — Material "store" path, ink lacivert
// (KARAR v1.10: standart ikon fallback, aynı yuva boyutu). Baskı için tek renk.
const String _storeIconSvg =
    '<svg viewBox="0 0 24 24" width="100%" height="100%">'
    '<path fill="#1B2A4A" d="M20 4H4v2h16V4zm1 10v-2l-1-5H4l-1 5v2h1v6h10v-6h4v6h2v-6h1zm-9 4H6v-4h6v4z"/>'
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
}) =>
    buildLabelsPdfMultiPage(pages: [slots], logoDataUrl: logoDataUrl);

/// Etiket Havuzu (KARAR — bkz. 0032_label_pool.sql): kapasiteyi (24) aşan
/// birikimi TEK pdf'te çok sayfaya böler ([pages] — her sayfa zaten
/// `paginateLabelPoolItems` ile 24'lük parçalara ayrılmış olmalı). Tema/logo
/// kurulumu PDF başına BİR KEZ yapılır (mevcut tek-sayfalı `buildLabelsPdf`
/// bunu `pages: [slots]` ile çağıran ince bir sarmalayıcıdır — davranışı/
/// imzası DEĞİŞMEDİ).
Future<Uint8List> buildLabelsPdfMultiPage({
  required List<List<LabelSlot?>> pages,
  String? logoDataUrl,
}) =>
    _buildGridLabelsPdfMultiPage(
      cols: _kCols,
      rows: _kRows,
      pages: pages,
      logoDataUrl: logoDataUrl,
    );

/// Tel Etiketi PDF'i: Raf Etiketi ile birebir aynı hücre tasarımı/yüksekliği
/// (`_cell` paylaşılır), yalnız 4×8=32 ızgara. Mağaza logosu Raf'ın kalıcı
/// logoDataUrl'i çağıran taraftan geçirilir (ayrı bir logo kavramı YOK).
Future<Uint8List> buildTelLabelsPdf({
  required List<LabelSlot?> slots,
  String? logoDataUrl,
}) =>
    buildTelLabelsPdfMultiPage(pages: [slots], logoDataUrl: logoDataUrl);

/// Tel Etiketi Havuz sürümü — `buildLabelsPdfMultiPage` ile aynı gerekçe,
/// yalnız 4×8=32 ızgara.
Future<Uint8List> buildTelLabelsPdfMultiPage({
  required List<List<LabelSlot?>> pages,
  String? logoDataUrl,
}) =>
    _buildGridLabelsPdfMultiPage(
      cols: _kTelCols,
      rows: _kTelRows,
      pages: pages,
      logoDataUrl: logoDataUrl,
    );

/// Tel İndirim Etiketi PDF'i: Tel Etiketi ile AYNI 4×8 ızgara/kenar boşluğu,
/// yalnız her hücre çizili eski fiyat + kırmızı/1.5× büyük yeni fiyat basar
/// (İndirim Etiketi'nin `buildDiscountLabelsPdfMultiPage` yapısı mirror'lanır
/// — kendi hücre çizim fonksiyonu `_telDiscountCell`, tek sayfa, çok-sayfalı
/// destek YOK — Tel Etiketi'nin sabit 32 haneli tek-sayfa deseniyle aynı).
Future<Uint8List> buildTelDiscountLabelsPdf({
  required List<TelDiscountLabelSlot?> slots,
  String? logoDataUrl,
  required TelDiscountKind generalKind,
  required num generalValue,
}) async {
  pw.ThemeData theme;
  try {
    final base = await PdfGoogleFonts.robotoRegular();
    final bold = await PdfGoogleFonts.robotoBold();
    theme = pw.ThemeData.withFont(base: base, bold: bold);
  } catch (_) {
    theme = pw.ThemeData.base();
  }

  pw.ImageProvider? logoImage;
  if (logoDataUrl != null) {
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
      margin: const pw.EdgeInsets.all(5 * PdfPageFormat.mm),
      build: (context) {
        return pw.Column(
          children: List.generate(_kTelRows, (r) {
            return pw.Expanded(
              child: pw.Row(
                children: List.generate(_kTelCols, (c) {
                  final idx = r * _kTelCols + c;
                  final slot = idx < slots.length ? slots[idx] : null;
                  return pw.Expanded(
                    child: _telDiscountCell(
                        slot, logoImage, generalKind, generalValue),
                  );
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

// Tek Tel İndirim etiketi hücresi — Tel'in `_cell`'iyle aynı çerçeve/dolgu,
// yalnız fiyat bandı yerine çizili eski fiyat + kırmızı/büyük yeni fiyat
// (ekrandaki `_TelDiscountLabelCell` ile BİREBİR aynı düzen/oranlar).
pw.Widget _telDiscountCell(
  TelDiscountLabelSlot? slot,
  pw.ImageProvider? logoImage,
  TelDiscountKind generalKind,
  num generalValue,
) {
  if (slot == null) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _hairlineEmpty, width: 0.5),
      ),
    );
  }

  return pw.Container(
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: _hairline, width: 0.5),
    ),
    padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      mainAxisAlignment: pw.MainAxisAlignment.start,
      children: [
        // Üst satır (logo + ÇİZİLİ eski fiyat), yeni fiyat, ürün adı, barkod
        // — DÖRDÜ `pw.Expanded` flex ORANI (40:33:19:80, ekrandaki
        // `_TelDiscountLabelCell` ile BİREBİR aynı oran) ile paylaşır. `pw`
        // paketinde bir Row/SizedBox(height:) zincirinin altındaki
        // `pw.Expanded(flex:)` barkod widget'ına GERÇEK (sıfır olmayan)
        // yükseklik vermeyebiliyor (`height > 0` assertion'ı fırlatan
        // yaşanmış hata) — Raf/Tel'in kanıtlanmış deseni doğrudan
        // `pw.Expanded`'ın Column'un ANA eksenindeki (dikey) flex payını
        // kullanmaktı, burada da AYNI desene dönüldü (SizedBox(height:)
        // KULLANILMAZ). Alt satır (barkod no + tarih) DIŞARIDA, değişmedi.
        pw.Expanded(
          flex: 40,
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.SizedBox(
                width: 26,
                child: logoImage != null
                    ? pw.Image(logoImage, fit: pw.BoxFit.contain)
                    : pw.SizedBox(),
              ),
              pw.SizedBox(width: 3),
              pw.Expanded(
                child: pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.FittedBox(
                    fit: pw.BoxFit.contain,
                    child: pw.Text(
                      '${formatNumber(slot.oldPrice)} TL',
                      maxLines: 1,
                      style: pw.TextStyle(
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.black,
                        decoration: pw.TextDecoration.lineThrough,
                        decorationColor: _discountRed,
                        decorationThickness: 1.8,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Yeni fiyat hero'su — kırmızı (kullanıcı isteğiyle barkod yarıya
        // inince (80→40) açılan pay buraya eklendi: 26 → 58).
        pw.Expanded(
          flex: 73,
          child: pw.Align(
            alignment: pw.Alignment.center,
            child: pw.FittedBox(
              fit: pw.BoxFit.contain,
              child: pw.Text(
                '${formatNumber(slot.newPrice(generalKind, generalValue))} TL',
                textAlign: pw.TextAlign.center,
                maxLines: 1,
                style: pw.TextStyle(
                  fontSize: 58,
                  fontWeight: pw.FontWeight.bold,
                  letterSpacing: -0.5,
                  color: _discountRed,
                ),
              ),
            ),
          ),
        ),
        // Ürün adı — TEK satır (kullanıcı isteğiyle 2× — 7 → 14).
        pw.Expanded(
          flex: 19,
          child: pw.Align(
            alignment: pw.Alignment.center,
            child: pw.FittedBox(
              fit: pw.BoxFit.scaleDown,
              child: pw.Text(
                slot.productName.toUpperCase(),
                textAlign: pw.TextAlign.center,
                maxLines: 1,
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.black,
                ),
              ),
            ),
          ),
        ),
        // Barkod çizgileri (Code128; geçersizse boş bırak) — kullanıcı
        // isteğiyle yarıya indirildi (80→40), açılan pay yeni fiyata
        // eklendi. `pw.Expanded`'ın Column ANA eksenindeki flex payı
        // kullanılır (yukarıdaki not) — bu HER ZAMAN sıfırdan büyük, kesin
        // bir yükseklik verir.
        pw.Expanded(
          flex: 40,
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
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
        // En alt: barkod no (sol) + oluşturma tarihi (sağ) — Tel'le AYNI format.
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Expanded(
              child: pw.Text(
                slot.barcode,
                textAlign: pw.TextAlign.center,
                maxLines: 1,
                overflow: pw.TextOverflow.clip,
                style: const pw.TextStyle(
                  fontSize: 9,
                  letterSpacing: 0.3,
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

Future<Uint8List> _buildGridLabelsPdfMultiPage({
  required int cols,
  required int rows,
  required List<List<LabelSlot?>> pages,
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
  for (final slots in pages) {
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(5 * PdfPageFormat.mm), // ~5mm kenar
        build: (context) {
          return pw.Column(
            children: List.generate(rows, (r) {
              return pw.Expanded(
                child: pw.Row(
                  children: List.generate(cols, (c) {
                    final idx = r * cols + c;
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
  }

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
                textAlign: pw.TextAlign.center,
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
}) =>
    buildWideLabelsPdfMultiPage(pages: [slots]);

/// Geniş Logo Havuz sürümü (KARAR — bkz. 0032_label_pool.sql): kapasiteyi
/// (10) aşan birikimi TEK pdf'te çok sayfaya böler ([pages] — her sayfa
/// zaten `paginateLabelPoolItems` ile 10'luk parçalara ayrılmış olmalı).
/// Tema/figür kurulumu PDF başına BİR KEZ yapılır; mevcut tek-sayfalı
/// `buildWideLabelsPdf` bunu `pages: [slots]` ile çağıran ince bir
/// sarmalayıcıdır — davranışı/imzası DEĞİŞMEDİ.
Future<Uint8List> buildWideLabelsPdfMultiPage({
  required List<List<LabelSlot?>> pages,
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
  for (final slots in pages) {
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
  }

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
// İndirim Etiketi PDF üretimi — A4 dikey 2 sütun × 2 satır = 4 etiket/sayfa
// (kullanıcı isteği, çok sayfalı YOK). Logo SABİT marka figürü
// (`nice_logo_indirim.png`, Geniş Logo'nun `genis_logo_figur.png` deseniyle
// birebir aynı — kendi içinde yüklenir, çağıran taraf logo geçirmez).
// Hücre-içi (kullanıcı referans mockup'ına göre, KARAR): logo + "EV
// GEREÇLERİ & HIRDAVAT" (siyah) + ince ayraç + ürün adı (BÜYÜK HARF) + tek
// satır kırmızı "%X İNDİRİM" bandı + "ESKİ FİYAT: " (siyah, üzeri KIRMIZI
// çizili) + kutulu "YENİ FİYAT" (kırmızı, hero) + Code128 + alt satır
// (barkod no + tarih, YYAAGG — örn. 260819).
// ═══════════════════════════════════════════════════════════════════════════

const int _kDiscountCols = 2;
const int _kDiscountRows = 2;
const PdfColor _discountRed = PdfColor.fromInt(0xFFC0392B); // AppColors.danger

String _discountDateLabel(DateTime d) =>
    '${(d.year % 100).toString().padLeft(2, '0')}'
    '${d.month.toString().padLeft(2, '0')}'
    '${d.day.toString().padLeft(2, '0')}';

/// Dolu/boş 4 haneyi A4 dikey 2×2 indirim etiketi PDF'ine dönüştürür.
/// [defaultPercent] sayfa geneli "ana indirim %"si — hane kendi yüzdesini
/// girmemişse (`discountPercent == null`) bu değer kullanılır.
Future<Uint8List> buildDiscountLabelsPdf({
  required List<DiscountLabelSlot?> slots,
  required num defaultPercent,
}) =>
    buildDiscountLabelsPdfMultiPage(
        pages: paginateDiscountSlots(slots), defaultPercent: defaultPercent);

/// Çok-sayfalı sürüm — `buildDiscountLabelsPdf` `paginateDiscountSlots` ile
/// böldüğü sayfaları buraya geçirir; her sayfa 2×2 ızgara olarak basılır.
Future<Uint8List> buildDiscountLabelsPdfMultiPage({
  required List<List<DiscountLabelSlot?>> pages,
  required num defaultPercent,
}) async {
  pw.ThemeData theme;
  try {
    final base = await PdfGoogleFonts.robotoRegular();
    final bold = await PdfGoogleFonts.robotoBold();
    theme = pw.ThemeData.withFont(base: base, bold: bold);
  } catch (_) {
    theme = pw.ThemeData.base();
  }

  final logoImage =
      pw.MemoryImage((await rootBundle.load('nice_logo_indirim.png')).buffer.asUint8List());

  final doc = pw.Document(theme: theme);
  for (final slots in pages) {
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(10 * PdfPageFormat.mm), // 4 etiket → ferah kenar
        build: (context) {
          return pw.Column(
            children: List.generate(_kDiscountRows, (r) {
              return pw.Expanded(
                child: pw.Row(
                  children: List.generate(_kDiscountCols, (c) {
                    final idx = r * _kDiscountCols + c;
                    final slot = idx < slots.length ? slots[idx] : null;
                    return pw.Expanded(
                        child: _discountCell(slot, logoImage, defaultPercent));
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

// Tek indirim etiketi hücresi. Boş hane → yalnız ince kesim kılavuzu.
pw.Widget _discountCell(
    DiscountLabelSlot? slot, pw.MemoryImage logoImage, num defaultPercent) {
  if (slot == null) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _hairlineEmpty, width: 0.5),
      ),
    );
  }

  return pw.Container(
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: _hairline, width: 0.5),
    ),
    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      mainAxisAlignment: pw.MainAxisAlignment.start,
      children: [
        // Logo — hane başı `showLogo` tikliyse sabit marka figürü (tagline
        // metni kırpılmış, aşağıda kod-render); tiksizse alan BOŞ (yükseklik
        // korunur, yalnız görsel basılmaz).
        pw.SizedBox(
          height: 68,
          child: slot.showLogo
              ? pw.Image(logoImage, fit: pw.BoxFit.contain)
              : pw.SizedBox(),
        ),
        pw.SizedBox(height: 3),
        pw.Text(
          'EV GEREÇLERİ & HIRDAVAT',
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(
            fontSize: 8,
            fontWeight: pw.FontWeight.bold,
            letterSpacing: 0.3,
            color: PdfColors.black,
          ),
        ),
        pw.SizedBox(height: 5),
        pw.Container(height: 0.6, color: _hairline),
        pw.SizedBox(height: 5),
        // Ürün adı (2 satır, taşarsa kısalt) — hücre genişliğine ortalı
        pw.SizedBox(
          width: double.infinity,
          child: pw.Text(
            slot.productName.toUpperCase(),
            textAlign: pw.TextAlign.center,
            maxLines: 2,
            overflow: pw.TextOverflow.clip,
            style: pw.TextStyle(
              fontSize: 11.5,
              fontWeight: pw.FontWeight.bold,
              lineSpacing: 0.5,
              color: PdfColors.black,
            ),
          ),
        ),
        pw.SizedBox(height: 6),
        // %X İndirim — tek satır, kırmızı bant (2x eski rozet boyutu)
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(vertical: 4),
          decoration: pw.BoxDecoration(
            color: _discountRed,
            borderRadius: pw.BorderRadius.circular(3),
          ),
          alignment: pw.Alignment.center,
          child: pw.Text(
            '%${slot.effectivePercent(defaultPercent).round()} İNDİRİM',
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
              fontSize: 22,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
              letterSpacing: 0.3,
            ),
          ),
        ),
        pw.SizedBox(height: 6),
        // Eski fiyat — siyah metin, üzeri KIRMIZI çizili (2x eski font boyutu)
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            pw.Text(
              'ESKİ FİYAT: ',
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.black),
            ),
            pw.Text(
              '${formatNumber(slot.oldPrice)} TL',
              style: pw.TextStyle(
                fontSize: 26,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.black,
                decoration: pw.TextDecoration.lineThrough,
                decorationColor: _discountRed,
                decorationThickness: 2,
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 4),
        // Yeni fiyat — kutulu, kırmızı hero (2x eski font boyutu)
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(vertical: 3),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _discountRed, width: 1),
            borderRadius: pw.BorderRadius.circular(3),
          ),
          child: pw.Column(
            children: [
              pw.Text(
                'YENİ FİYAT',
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: _discountRed,
                  letterSpacing: 0.5,
                ),
              ),
              pw.FittedBox(
                fit: pw.BoxFit.scaleDown,
                child: pw.Text(
                  '${formatNumber(slot.newPrice(defaultPercent))} TL',
                  style: pw.TextStyle(
                    fontSize: 52,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: -0.5,
                    color: _discountRed,
                  ),
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 6),
        // Barkod çizgileri (Code128; geçersizse boş bırak). Bölge (Expanded)
        // mevcut merkezde KALIR (kullanıcı isteği); asıl barkod grafiği bu
        // bölgenin yalnız ORTA 1/3'ünü kaplar (üst/alt eşit boş 1/3 ile
        // çevrili) → toplam yükseklik mevcudun 1/3'ü, konum sabit.
        pw.Expanded(
          child: pw.Column(
            children: [
              pw.Expanded(child: pw.SizedBox()),
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
              pw.Expanded(child: pw.SizedBox()),
            ],
          ),
        ),
        // En alt: barkod no (sol) + tarih YYAAGG (sağ)
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Expanded(
              child: pw.Text(
                slot.barcode,
                textAlign: pw.TextAlign.center,
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
              _discountDateLabel(slot.createdAt),
              style: const pw.TextStyle(fontSize: 6, color: _dateGrey),
            ),
          ],
        ),
      ],
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// Poster PDF üretimi (KARAR v1.23) — A4 dikey, tek sütunlu profesyonel ürün
// listesi (ürün adı solda · fiyat sağda). Sabit ızgara YOK: satır sayısı 1'den
// 20'ye (bkz. `kPosterItemsPerPage`) kadar değişebilir; sayfa BOŞ kalmasın diye
// satır yüksekliği/fontu kalem sayısına göre ORANLANIR (az kalem → iri "poster"
// satırları, çok kalem → kompakt tablo). Toplam > 20 ise 2., 3. sayfaya taşar.
// Çıktı SİYAH/BEYAZ + isteğe bağlı RENKLİ mağaza logosu (Yeni Etiket'in kalıcı
// logosu paylaşılır). Önizleme = HTML = PDF birebir.
// ═══════════════════════════════════════════════════════════════════════════

const PdfColor _posterInk = PdfColor.fromInt(0xFF1B2A4A); // AppColors.primary
const PdfColor _posterMuted = PdfColor.fromInt(0xFF6B7280);
const PdfColor _posterZebra = PdfColor.fromInt(0xFFF4F5F7);

double _posterClamp(double v, double lo, double hi) =>
    v < lo ? lo : (v > hi ? hi : v);

/// Poster kalemlerini (çok-sayfalı, [paginatePosterItems]) A4 dikey profesyonel
/// ürün listesi PDF'ine dönüştürür. [title] boşsa çağıran taraf
/// `kPosterDefaultTitle` göndermelidir (`LabelPosterSheetState.effectiveTitle`).
/// [showBarcode] true ise her satırda ürün adının altında barkod no da basılır
/// (barkodu olmayan — ad araması ile eklenen — kalemlerde satır atlanır).
Future<Uint8List> buildPosterPdf({
  required List<LabelSlot> items,
  required String title,
  bool showBarcode = false,
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

  final pages = paginatePosterItems(items);
  final now = DateTime.now();
  final doc = pw.Document(theme: theme);
  for (var p = 0; p < pages.length; p++) {
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(
          vertical: 18 * PdfPageFormat.mm,
          horizontal: 16 * PdfPageFormat.mm,
        ),
        build: (context) => _posterPage(
          page: pages[p],
          title: title,
          showBarcode: showBarcode,
          logoImage: logoImage,
          generatedAt: now,
          pageLabel: pages.length > 1 ? '${p + 1} / ${pages.length}' : null,
        ),
      ),
    );
  }

  return doc.save();
}

pw.Widget _posterPage({
  required List<LabelSlot> page,
  required String title,
  required bool showBarcode,
  required pw.MemoryImage? logoImage,
  required DateTime generatedAt,
  required String? pageLabel,
}) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      // Başlık: logo (varsa) + kullanıcı başlığı (boşsa varsayılan) + lacivert ayraç.
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          if (logoImage != null)
            pw.SizedBox(
              width: 30 * PdfPageFormat.mm,
              height: 16 * PdfPageFormat.mm,
              child: pw.Image(logoImage, fit: pw.BoxFit.contain),
            ),
          if (logoImage != null) pw.SizedBox(width: 8 * PdfPageFormat.mm),
          pw.Expanded(
            child: pw.Text(
              title,
              maxLines: 1,
              overflow: pw.TextOverflow.clip,
              style: pw.TextStyle(
                fontSize: 22,
                fontWeight: pw.FontWeight.bold,
                letterSpacing: 0.5,
                color: _posterInk,
              ),
            ),
          ),
          if (pageLabel != null)
            pw.Text(
              'Sayfa $pageLabel',
              style: pw.TextStyle(fontSize: 9, color: _posterMuted),
            ),
        ],
      ),
      pw.SizedBox(height: 3 * PdfPageFormat.mm),
      pw.Container(height: 1.2, color: _posterInk),
      pw.SizedBox(height: 4 * PdfPageFormat.mm),
      // Liste — kalan alanı doldurur; satır yüksekliği kalem sayısına göre
      // oranlanır (az kalem → iri poster satırı, çok kalem → kompakt tablo).
      // barkod satırı açıksa taban yükseklik yükselir (2. satıra yer açılır).
      pw.Expanded(
        child: page.isEmpty
            ? pw.Center(
                child: pw.Text(
                  'Henüz ürün okutulmadı.',
                  style: pw.TextStyle(fontSize: 12, color: _posterMuted),
                ),
              )
            : pw.LayoutBuilder(
                builder: (context, constraints) {
                  final maxH = constraints?.maxHeight ?? 400;
                  final minRowMm = showBarcode ? 16.0 : 11.0;
                  final rowH = _posterClamp(maxH / page.length,
                      minRowMm * PdfPageFormat.mm, 50 * PdfPageFormat.mm);
                  final nameSize = _posterClamp(
                      rowH / PdfPageFormat.mm * (showBarcode ? 0.56 : 0.72),
                      10,
                      28);
                  final priceSize =
                      _posterClamp(rowH / PdfPageFormat.mm * 0.8, 13, 34);
                  final numSize =
                      _posterClamp(rowH / PdfPageFormat.mm * 0.4, 8, 16);
                  final barcodeSize =
                      _posterClamp(rowH / PdfPageFormat.mm * 0.26, 7, 12);
                  return pw.Column(
                    mainAxisAlignment: pw.MainAxisAlignment.start,
                    children: List.generate(page.length, (i) {
                      final it = page[i];
                      return pw.Container(
                        height: rowH,
                        color: i.isEven ? PdfColors.white : _posterZebra,
                        padding: const pw.EdgeInsets.symmetric(
                            horizontal: 4 * PdfPageFormat.mm),
                        child: pw.Row(
                          crossAxisAlignment: pw.CrossAxisAlignment.center,
                          children: [
                            pw.SizedBox(
                              width: 9 * PdfPageFormat.mm,
                              child: pw.Text(
                                '${i + 1}.',
                                style: pw.TextStyle(
                                    fontSize: numSize, color: _posterMuted),
                              ),
                            ),
                            pw.Expanded(
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                mainAxisSize: pw.MainAxisSize.min,
                                children: [
                                  pw.Text(
                                    it.productName,
                                    maxLines: 2,
                                    overflow: pw.TextOverflow.clip,
                                    style: pw.TextStyle(
                                      fontSize: nameSize,
                                      fontWeight: pw.FontWeight.bold,
                                      color: PdfColors.black,
                                    ),
                                  ),
                                  if (showBarcode && it.barcode.isNotEmpty)
                                    pw.Text(
                                      it.barcode,
                                      style: pw.TextStyle(
                                        fontSize: barcodeSize,
                                        color: _posterMuted,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            pw.SizedBox(width: 6 * PdfPageFormat.mm),
                            pw.Text(
                              '${formatNumber(it.price)} TL',
                              style: pw.TextStyle(
                                fontSize: priceSize,
                                fontWeight: pw.FontWeight.bold,
                                color: _posterInk,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  );
                },
              ),
      ),
      pw.SizedBox(height: 3 * PdfPageFormat.mm),
      pw.Container(height: 0.6, color: _hairline),
      pw.SizedBox(height: 1.5 * PdfPageFormat.mm),
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Toplam ${page.length} ürün',
            style: pw.TextStyle(fontSize: 8, color: _posterMuted),
          ),
          pw.Text(
            formatShortDate(generatedAt),
            style: pw.TextStyle(fontSize: 8, color: _posterMuted),
          ),
        ],
      ),
    ],
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// Ürün Etiketi PDF üretimi (KARAR v1.21) — adet-tabanlı, FİYATSIZ/LOGOSUZ barkod
// etiketi. A4 dikey, 6 sütun × 12 satır = 72 etiket/sayfa. Sayfa boşluğu üst/alt
// 10mm, yatay 0. Hücre 35×23mm, her kenardan 1.5mm iç pay → içerik 32×20mm (KARAR
// v1.22). Toplam > 72 ise 2., 3. sayfaya taşar (çok-sayfalı). Etiket-içi (dikey
// ORTALI): ürün adı 2 satır sabit + Code128 barkod (SABİT 8mm) + barkod no. Çıktı
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

// Tek Ürün Etiketi hücresi (KARAR v1.22). Boş hane → tamamen boş (die-cut →
// kesim çizgisi YOK). Etiket-içi: ürün adı 2 satır sabit (ortalı) + Code128
// barkod (SABİT 8mm) + barkod no (ortalı, tabular); 3 öğe grubu içerik alanında
// dikey ORTALANIR. Fiyat/logo YOK. Ad `flex:0` + numara `flex:0`, barkod SABİT
// 8mm `SizedBox`; savunma katmanı (v1.20.1 dersi): gerçek yükseklik eşiğin
// altındaysa barkod HİÇ render edilmez (sabit 8mm'de tetiklenmez ama korunur).
pw.Widget _productCell(ProductLabelItem? it) {
  if (it == null) {
    // Boş hücre — die-cut, çerçeve/kesim çizgisi YOK.
    return pw.Container();
  }

  return pw.Container(
    padding: pw.EdgeInsets.all(1.5 * PdfPageFormat.mm),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      mainAxisAlignment: pw.MainAxisAlignment.center,
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
        // 2. Code128 barkod — SABİT 8mm (KARAR v1.22), yatayda %80'e ortalı
        //    (1:8:1 flex). Grup dikey ortalı (Column mainAxisAlignment.center).
        //    Savunma: yükseklik eşiğin altındaysa HİÇ render etme (sabit 8mm'de
        //    tetiklenmez ama katman korunur).
        pw.SizedBox(
          height: 8 * PdfPageFormat.mm,
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
              fontSize: 7,
              letterSpacing: 0.3,
              color: PdfColors.black,
            ),
          ),
        ),
      ],
    ),
  );
}
