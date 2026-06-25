import 'dart:typed_data';

import 'package:excel/excel.dart' hide Border;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/models/product.dart';
import '../../application/products_provider.dart';

/// Şablon (her satır bir ürün, başlık satırı yok):
/// A: Barkod, B: Ürün Adı, C: Stok, D: Birim, E: Fiyat 1, F: KDV, G: Alış Fiyatı,
/// H: Üst Ürün Grubu, I: Ürün Grubu, J: Fiyat 2, K: Stok Kodu, L: Ürün Detayı,
/// O: Kritik Stok, P: Menşe
/// (M, N, Q, R, S sütunları bu sürümde kullanılmaz.)
class ExcelImportDialog extends ConsumerStatefulWidget {
  const ExcelImportDialog({super.key});

  @override
  ConsumerState<ExcelImportDialog> createState() => _ExcelImportDialogState();
}

class _ExcelImportDialogState extends ConsumerState<ExcelImportDialog> {
  bool _processing = false;
  int _total = 0;
  int _done = 0;
  int _created = 0;
  int _updated = 0;
  final List<String> _errors = [];
  Uint8List? _selectedBytes;
  String? _selectedFileName;

  Future<void> _pickFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final bytes = result.files.single.bytes;
    if (bytes == null) return;

    setState(() {
      _selectedBytes = bytes;
      _selectedFileName = result.files.single.name;
      _total = 0;
      _done = 0;
      _created = 0;
      _updated = 0;
      _errors.clear();
    });
  }

  Future<void> _runImport() async {
    final bytes = _selectedBytes;
    if (bytes == null) return;

    setState(() {
      _processing = true;
      _total = 0;
      _done = 0;
      _created = 0;
      _updated = 0;
      _errors.clear();
    });

    try {
      final excel = Excel.decodeBytes(bytes);
      final sheetName = excel.getDefaultSheet() ?? excel.tables.keys.first;
      final sheet = excel.tables[sheetName]!;

      final rows = sheet.rows.where((row) {
        final barcode = _cellText(row, 0);
        final name = _cellText(row, 1);
        return (barcode != null && barcode.isNotEmpty) || (name != null && name.isNotEmpty);
      }).toList();

      setState(() => _total = rows.length);

      final productRepo = ref.read(productRepositoryProvider);
      final groupRepo = ref.read(productGroupRepositoryProvider);

      for (final row in rows) {
        try {
          final barcode = _cellText(row, 0);
          final name = _cellText(row, 1) ?? '';
          if (name.isEmpty) {
            _errors.add('İsimsiz satır atlandı');
            continue;
          }

          final groupName = _cellText(row, 8);
          final parentGroupName = _cellText(row, 7);
          String? groupId;
          if (groupName != null && groupName.isNotEmpty) {
            groupId = await groupRepo.findOrCreateByName(groupName, parentName: parentGroupName);
          }

          final existing = (barcode != null && barcode.isNotEmpty)
              ? await productRepo.fetchByBarcode(barcode)
              : null;

          final product = Product(
            id: existing?.id ?? '',
            barcode: barcode,
            name: name,
            stockCode: _cellText(row, 10) ?? existing?.stockCode,
            groupId: groupId ?? existing?.groupId,
            unit: _cellText(row, 3) ?? existing?.unit ?? 'Adet',
            originCountry: _cellText(row, 15) ?? existing?.originCountry,
            stockQuantity: _cellNum(row, 2) ?? existing?.stockQuantity ?? 0,
            criticalStock: _cellNum(row, 14) ?? existing?.criticalStock ?? 0,
            purchasePrice: _cellNum(row, 6) ?? existing?.purchasePrice ?? 0,
            price1: _cellNum(row, 4) ?? existing?.price1 ?? 0,
            price2: _cellNum(row, 9) ?? existing?.price2 ?? 0,
            vatRate: _cellNum(row, 5) ?? existing?.vatRate ?? 20,
            description: _cellText(row, 11) ?? existing?.description,
            imageUrl: existing?.imageUrl,
          );

          if (existing != null) {
            await productRepo.update(existing.id, product);
            _updated++;
          } else {
            await productRepo.create(product);
            _created++;
          }
        } catch (e) {
          _errors.add('Satır hatası: $e');
        } finally {
          setState(() => _done++);
        }
      }
    } catch (e) {
      _errors.add('Dosya okunamadı: $e');
    } finally {
      setState(() => _processing = false);
    }
  }

  String? _cellText(List<Data?> row, int index) {
    if (index >= row.length) return null;
    final value = row[index]?.value;
    if (value == null) return null;
    if (value is TextCellValue) {
      final text = value.value.toString().trim();
      return text.isEmpty ? null : text;
    }
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  num? _cellNum(List<Data?> row, int index) {
    if (index >= row.length) return null;
    final value = row[index]?.value;
    if (value == null) return null;
    if (value is IntCellValue) return value.value;
    if (value is DoubleCellValue) return value.value;
    if (value is TextCellValue) return num.tryParse(value.value.toString().trim());
    return num.tryParse(value.toString());
  }

  // Import bitmiş mi?
  bool get _finished => !_processing && (_created + _updated + _errors.length) > 0;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Excel İçe Aktar'),
      content: SizedBox(
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Şablon açıklaması (her zaman görünür) ───────────────────
            const Text(
              'Şablon: A-Barkod, B-Ürün Adı, C-Stok, D-Birim, E-Fiyat 1, F-KDV, '
              'G-Alış Fiyatı, H-Üst Ürün Grubu, I-Ürün Grubu, J-Fiyat 2, K-Stok Kodu, '
              'L-Ürün Detayı, O-Kritik Stok, P-Menşe.\n'
              'İlk satır başlık olmamalı. Barkodu mevcut ürünler güncellenir, '
              'olmayanlar yeni eklenir.',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            const SizedBox(height: 16),

            // ── Dosya seçimi (işlem yokken) ──────────────────────────────
            if (!_processing)
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _pickFile,
                    icon: const Icon(Icons.file_open_outlined),
                    label: const Text('Dosya Seç'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _selectedFileName ?? 'Dosya seçilmedi',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _selectedFileName != null
                            ? AppColors.textPrimary
                            : AppColors.textMuted,
                        fontWeight: _selectedFileName != null
                            ? FontWeight.w500
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                ],
              ),

            // ── İlerleme göstergesi ──────────────────────────────────────
            if (_processing) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'İşleniyor...',
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textSecondary),
                  ),
                  const Spacer(),
                  Text(
                    '$_done / $_total',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _total == 0 ? null : _done / _total,
                  minHeight: 8,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                  valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _total == 0
                    ? 'Hazırlanıyor...'
                    : '%${((_done / _total) * 100).round()} tamamlandı',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textMuted),
              ),
            ],

            // ── Tamamlanma özeti ─────────────────────────────────────────
            if (_finished) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  _SummaryChip(
                    icon: Icons.add_circle_outline,
                    label: 'Yeni Eklenen',
                    count: _created,
                    color: AppColors.success,
                  ),
                  const SizedBox(width: 10),
                  _SummaryChip(
                    icon: Icons.update,
                    label: 'Güncellenen',
                    count: _updated,
                    color: AppColors.primary,
                  ),
                  if (_errors.isNotEmpty) ...[
                    const SizedBox(width: 10),
                    _SummaryChip(
                      icon: Icons.error_outline,
                      label: 'Hata',
                      count: _errors.length,
                      color: AppColors.danger,
                    ),
                  ],
                ],
              ),
              if (_errors.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  constraints: const BoxConstraints(maxHeight: 100),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: AppColors.danger.withValues(alpha: 0.2)),
                  ),
                  child: ListView(
                    padding: const EdgeInsets.all(8),
                    shrinkWrap: true,
                    children: _errors
                        .map((e) => Text('• $e',
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.danger)))
                        .toList(),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _processing ? null : () => Navigator.pop(context),
          child: const Text('Kapat'),
        ),
        if (!_processing)
          ElevatedButton.icon(
            onPressed: _selectedBytes == null ? null : _runImport,
            icon: const Icon(Icons.upload_outlined),
            label: Text(_finished ? 'Tekrar Aktar' : 'İçe Aktar'),
          ),
      ],
    );
  }
}

// ── Özet chip ─────────────────────────────────────────────────────────────────

class _SummaryChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final Color color;

  const _SummaryChip({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(
              count.toString(),
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
