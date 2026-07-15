import 'dart:convert';
import 'dart:typed_data';

import 'package:barcode/barcode.dart' as bc;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/utils/formatters.dart';
import 'models/label_slot.dart';

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
