import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../application/products_provider.dart';
import '../../data/models/liste_gir/column_band.dart';
import '../../data/models/liste_gir/column_type.dart';
import '../../data/models/liste_gir/extracted_row.dart';
import '../../data/models/liste_gir/pdf_document_handle.dart';
import '../../data/models/liste_gir/rendered_page.dart';
import '../../data/models/product.dart';
import '../../data/services/liste_gir/column_row_extractor.dart';
import '../../data/services/liste_gir/document_page_source.dart';
import '../widgets/liste_gir/liste_gir_column_select_step.dart';
import '../widgets/liste_gir/liste_gir_review_grid.dart';

enum _Step { upload, columnSelect, review, saving, done }

/// Ürünler → Liste Gir sekmesi: tedarikçi PDF/JPEG listesini yükleyip
/// sütunları renkli dikdörtgenlerle işaretleme → önizleme/düzenleme →
/// kaydetme akışı. Yalnız masaüstünde gösterilir (`products_tabs_screen.dart`
/// `context.isDesktop` guard'ı) — pdf.js/Tesseract.js interop'u
/// `document_page_source_web.dart` yalnız web'de çalışır.
class ListeGirScreen extends ConsumerStatefulWidget {
  const ListeGirScreen({super.key});

  @override
  ConsumerState<ListeGirScreen> createState() => _ListeGirScreenState();
}

class _ListeGirScreenState extends ConsumerState<ListeGirScreen> {
  static const double _targetWidthPx = 1000;

  _Step _step = _Step.upload;
  bool _busy = false;
  String? _error;
  String? _fileName;

  bool _isPdf = false;
  PdfDocumentHandle? _pdfHandle;
  RenderedPage? _page1;

  final Map<ColumnType, ColumnBand> _bands = {};

  List<ExtractedRow> _rows = [];

  int _created = 0;
  int _updated = 0;
  int _errors = 0;

  Future<void> _pickAndProcess() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null) return;

    final ext = (file.extension ?? '').toLowerCase();
    setState(() {
      _busy = true;
      _error = null;
      _fileName = file.name;
      _isPdf = ext == 'pdf';
    });

    try {
      RenderedPage page;
      if (_isPdf) {
        final handle = await loadPdfDocument(bytes);
        _pdfHandle = handle;
        page = await renderPdfPage(docId: handle.docId, pageNum: 1, targetWidthPx: _targetWidthPx);
        if (!page.hasUsableTextLayer) {
          page = await _ocrPage(page);
        }
      } else {
        page = await _ocrImageBytes(bytes);
      }

      if (!mounted) return;
      setState(() {
        _page1 = page;
        _bands.clear();
        _step = _Step.columnSelect;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Dosya işlenemedi: $e';
      });
    }
  }

  Future<RenderedPage> _ocrPage(RenderedPage page) async {
    final words = await ocrRecognize(imageBytes: page.imageBytes);
    return RenderedPage(imageBytes: page.imageBytes, width: page.width, height: page.height, textItems: words);
  }

  Future<RenderedPage> _ocrImageBytes(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final width = frame.image.width.toDouble();
    final height = frame.image.height.toDouble();
    final words = await ocrRecognize(imageBytes: bytes);
    return RenderedPage(imageBytes: bytes, width: width, height: height, textItems: words);
  }

  Future<RenderedPage> _loadPreviewPage(int pageNum) async {
    final handle = _pdfHandle;
    if (handle == null) return _page1!;
    var page = await renderPdfPage(docId: handle.docId, pageNum: pageNum, targetWidthPx: _targetWidthPx);
    if (!page.hasUsableTextLayer) {
      page = await _ocrPage(page);
    }
    return page;
  }

  Future<void> _confirmColumns() async {
    setState(() => _busy = true);
    try {
      final bandList = _bands.values.toList();
      final rows = extractRows(items: _page1!.textItems, bands: bandList);

      final handle = _pdfHandle;
      if (handle != null && handle.numPages > 1) {
        for (var p = 2; p <= handle.numPages; p++) {
          final page = await _loadPreviewPage(p);
          rows.addAll(extractRows(items: page.textItems, bands: bandList));
        }
      }

      final consolidated = consolidateDuplicateBarcodes(rows);

      final barcodes = consolidated.map((r) => r.barcode).where((b) => b.isNotEmpty).toSet().toList();
      final existing = await ref.read(productRepositoryProvider).fetchByBarcodes(barcodes);
      for (final row in consolidated) {
        final match = existing[row.barcode];
        if (match != null) {
          row.existingProductId = match.id;
          row.existingStock = match.stockQuantity;
          if (row.salePrice == 0) row.salePrice = match.price1;
        }
      }

      if (!mounted) return;
      setState(() {
        _rows = consolidated;
        _step = _Step.review;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Sütunlar işlenemedi: $e';
      });
    }
  }

  Future<void> _save() async {
    setState(() {
      _step = _Step.saving;
      _created = 0;
      _updated = 0;
      _errors = 0;
    });

    final repo = ref.read(productRepositoryProvider);
    // Önizleme adımından bu yana kullanıcı barkodları elle değiştirmiş
    // olabilir — kaydetmeden hemen önce güncel barkod listesiyle tekrar
    // sorgulanır (§ "Mükerrer barkod birleştirme" notundaki canlılık
    // gereksinimi burada tek sorguyla karşılanır).
    final barcodes = _rows.map((r) => r.barcode).where((b) => b.isNotEmpty).toSet().toList();
    final existingByBarcode = await repo.fetchByBarcodes(barcodes);

    for (final row in _rows) {
      try {
        final existing = row.barcode.isEmpty ? null : existingByBarcode[row.barcode];
        if (existing != null) {
          final merged = existing.copyWith(
            stockQuantity: existing.stockQuantity + row.quantity,
            purchasePrice: row.purchasePrice,
            price1: row.salePrice,
          );
          await repo.update(existing.id, merged);
          _updated++;
        } else {
          await repo.create(Product(
            barcode: row.barcode.isEmpty ? null : row.barcode,
            name: row.name.isEmpty ? '(İsimsiz Ürün)' : row.name,
            stockQuantity: row.quantity,
            purchasePrice: row.purchasePrice,
            price1: row.salePrice,
          ));
          _created++;
        }
      } catch (_) {
        _errors++;
      }
    }

    if (!mounted) return;
    setState(() => _step = _Step.done);
  }

  void _reset() {
    setState(() {
      _step = _Step.upload;
      _fileName = null;
      _pdfHandle = null;
      _page1 = null;
      _bands.clear();
      _rows = [];
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: switch (_step) {
        _Step.upload => _buildUploadStep(),
        _Step.columnSelect => ListeGirColumnSelectStep(
            page1: _page1!,
            numPages: _pdfHandle?.numPages ?? 1,
            onLoadPreviewPage: _loadPreviewPage,
            bands: _bands,
            onBandsChanged: () => setState(() {}),
            onConfirm: _busy ? () {} : _confirmColumns,
            onBack: _reset,
          ),
        _Step.review => _buildReviewStep(),
        _Step.saving => const Center(child: CircularProgressIndicator()),
        _Step.done => _buildDoneStep(),
      },
    );
  }

  Widget _buildUploadStep() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.upload_file_outlined, size: 48, color: AppColors.textMuted),
          const SizedBox(height: 12),
          const Text(
            'Tedarikçi ürün listesini yükleyin (PDF veya JPEG/PNG)',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          if (_busy) const CircularProgressIndicator() else
            ElevatedButton.icon(
              onPressed: _pickAndProcess,
              icon: const Icon(Icons.file_open_outlined),
              label: const Text('Dosya Seç'),
            ),
          if (_fileName != null && !_busy) ...[
            const SizedBox(height: 8),
            Text(_fileName!, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(fontSize: 12, color: AppColors.danger)),
          ],
        ],
      ),
    );
  }

  Widget _buildReviewStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${_rows.length} satır çıkarıldı — kaydetmeden önce gözden geçirip düzeltin.',
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        Expanded(child: ListeGirReviewGrid(rows: _rows, onRowsChanged: () {})),
        const SizedBox(height: 12),
        Row(
          children: [
            TextButton(onPressed: () => setState(() => _step = _Step.columnSelect), child: const Text('Geri')),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: _rows.isEmpty ? null : _save,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Kaydet'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDoneStep() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_outline, size: 48, color: AppColors.success),
          const SizedBox(height: 12),
          Row(mainAxisSize: MainAxisSize.min, children: [
            _summaryChip('Yeni Eklenen', _created, AppColors.success),
            const SizedBox(width: 10),
            _summaryChip('Güncellenen', _updated, AppColors.primary),
            if (_errors > 0) ...[
              const SizedBox(width: 10),
              _summaryChip('Hata', _errors, AppColors.danger),
            ],
          ]),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _reset,
            icon: const Icon(Icons.upload_file_outlined),
            label: const Text('Yeni Liste Yükle'),
          ),
        ],
      ),
    );
  }

  Widget _summaryChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(children: [
        Text('$count', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
      ]),
    );
  }
}
