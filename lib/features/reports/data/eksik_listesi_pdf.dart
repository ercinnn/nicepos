import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/utils/formatters.dart';
import 'models/ciro_analiz_record.dart';

/// Eksik Listesi (Ciro Analiz'de filtrelenip firma bazlı seçilen ürünlerin
/// sipariş listesi) için A4 tablo PDF'i. `label_pdf.dart`'taki etiket
/// grid'lerinin aksine standart bir liste/rapor tablosu olduğundan
/// `pw.TableHelper.fromTextArray` kullanılır (codebase'de ilk kullanımı —
/// mevcut PDF'ler yalnız `pw.Column`/`pw.Row` grid'i kullanıyor). Türkçe
/// glyph desteği için `label_pdf.dart` ile BİREBİR aynı `PdfGoogleFonts`
/// yükleme deseni (ağ hatasında gömülü standart yazı tipine düşer).
Future<Uint8List> buildEksikListesiPdf(List<CiroAnalizRecord> records) async {
  pw.ThemeData theme;
  try {
    final base = await PdfGoogleFonts.robotoRegular();
    final bold = await PdfGoogleFonts.robotoBold();
    theme = pw.ThemeData.withFont(base: base, bold: bold);
  } catch (_) {
    theme = pw.ThemeData.base();
  }

  final doc = pw.Document(theme: theme);

  const headers = ['#', 'Ürün', 'Barkod', 'Firma', 'Stok', 'Satış Adedi'];
  final data = <List<String>>[
    for (var i = 0; i < records.length; i++)
      [
        '${i + 1}',
        records[i].name,
        (records[i].barcode?.isNotEmpty ?? false) ? records[i].barcode! : '—',
        records[i].companyName,
        formatNumber(records[i].stockQuantity),
        formatNumber(records[i].quantitySold),
      ],
  ];

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(24),
      header: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Eksik Listesi',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            '${formatDateTime(DateTime.now())}  ·  ${records.length} ürün',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 12),
        ],
      ),
      build: (context) => [
        pw.TableHelper.fromTextArray(
          headers: headers,
          data: data,
          headerStyle: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.white,
            fontSize: 10,
          ),
          headerDecoration:
              const pw.BoxDecoration(color: PdfColor.fromInt(0xFF1B2A4A)),
          cellStyle: const pw.TextStyle(fontSize: 10),
          cellAlignments: const {
            0: pw.Alignment.centerLeft,
            1: pw.Alignment.centerLeft,
            2: pw.Alignment.centerLeft,
            3: pw.Alignment.centerLeft,
            4: pw.Alignment.centerRight,
            5: pw.Alignment.centerRight,
          },
          columnWidths: {
            0: const pw.FixedColumnWidth(24),
            1: const pw.FlexColumnWidth(3),
            2: const pw.FlexColumnWidth(1.4),
            3: const pw.FlexColumnWidth(1.6),
            4: const pw.FlexColumnWidth(0.8),
            5: const pw.FlexColumnWidth(1),
          },
          cellPadding:
              const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
          border: null,
          rowDecoration: const pw.BoxDecoration(
            border: pw.Border(
              bottom: pw.BorderSide(color: PdfColor.fromInt(0xFFE2E6EE)),
            ),
          ),
        ),
      ],
    ),
  );

  return doc.save();
}
