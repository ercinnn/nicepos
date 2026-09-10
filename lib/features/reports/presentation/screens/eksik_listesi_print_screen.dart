import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/utils/formatters.dart';
import '../../data/eksik_listesi_pdf.dart';
import '../../data/models/ciro_analiz_record.dart';
import '../widgets/eksik_listesi_print.dart';

/// Eksik Listesi sekmesinde seçilen ürünlerin (firma, sonra ada göre sıralı)
/// göründüğü ayrı önizleme sayfası — kullanıcı isteği: "seçilen ürünler yeni
/// bir sayfada sıralansın". Bu sayfa yazdırılabilir (yalnız web, `sale_print`
/// ile aynı HTML+`window.print()` deseni) VE PDF olarak kaydedilebilir (tüm
/// platformlar, `pdf` paketiyle gerçek PDF bayt üretimi +
/// `Printing.sharePdf` — Etiket'in aksine Supabase Storage'a YÜKLENMEZ, bu
/// kalıcı bir şablon değil tek seferlik bir sipariş dokümanı).
class EksikListesiPrintScreen extends StatefulWidget {
  final List<CiroAnalizRecord> records;

  const EksikListesiPrintScreen({super.key, required this.records});

  @override
  State<EksikListesiPrintScreen> createState() =>
      _EksikListesiPrintScreenState();
}

class _EksikListesiPrintScreenState extends State<EksikListesiPrintScreen> {
  bool _savingPdf = false;

  void _print() {
    printEksikListesiA4(widget.records);
  }

  Future<void> _savePdf() async {
    if (_savingPdf) return;
    setState(() => _savingPdf = true);
    try {
      final bytes = await buildEksikListesiPdf(widget.records);
      final stamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      await Printing.sharePdf(bytes: bytes, filename: 'eksik_listesi_$stamp.pdf');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF oluşturulamadı: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _savingPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Eksik Listesi'),
        actions: [
          if (kIsWeb)
            IconButton(
              tooltip: 'Yazdır',
              icon: const Icon(Icons.print_outlined),
              onPressed: _print,
            ),
          if (_savingPdf)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              tooltip: 'PDF Kaydet',
              icon: const Icon(Icons.picture_as_pdf_outlined),
              onPressed: _savePdf,
            ),
          const SizedBox(width: AppSizes.space8),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.space16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${widget.records.length} ürün',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
              const SizedBox(height: AppSizes.space12),
              Expanded(
                child: SingleChildScrollView(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor:
                          WidgetStateProperty.all(AppColors.tableHeader),
                      columns: const [
                        DataColumn(label: Text('#')),
                        DataColumn(label: Text('Ürün')),
                        DataColumn(label: Text('Barkod')),
                        DataColumn(label: Text('Firma')),
                        DataColumn(label: Text('Stok'), numeric: true),
                        DataColumn(label: Text('Satış Adedi'), numeric: true),
                      ],
                      rows: [
                        for (var i = 0; i < widget.records.length; i++)
                          DataRow(cells: [
                            DataCell(Text('${i + 1}')),
                            DataCell(Text(widget.records[i].name)),
                            DataCell(Text(
                              (widget.records[i].barcode?.isNotEmpty ?? false)
                                  ? widget.records[i].barcode!
                                  : '—',
                            )),
                            DataCell(Text(widget.records[i].companyName)),
                            DataCell(Text(
                              formatNumber(widget.records[i].stockQuantity),
                              style: const TextStyle(
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            )),
                            DataCell(Text(
                              formatNumber(widget.records[i].quantitySold),
                              style: const TextStyle(
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            )),
                          ]),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
