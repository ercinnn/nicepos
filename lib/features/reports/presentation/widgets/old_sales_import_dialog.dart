import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../data/models/imported_sale_row.dart';
import '../../data/repositories/sales_import_repository.dart';

/// Eski POS (BenimPOS) "Satış Raporu" xlsx dosyasını yeni sistemdeki `sales`
/// kayıtlarına aktaran diyalog (ürün kalemi yazılmaz; ödeme nakit/pos; iadeler
/// negatif).
///
/// Akış: Dosya Seç → Parse + mükerrer kontrolü (önizleme) → İçe Aktar → Özet.
class OldSalesImportDialog extends StatefulWidget {
  const OldSalesImportDialog({super.key});

  @override
  State<OldSalesImportDialog> createState() => _OldSalesImportDialogState();
}

class _OldSalesImportDialogState extends State<OldSalesImportDialog> {
  final _repo = SalesImportRepository();

  bool _analyzing = false; // dosya parse/mükerrer kontrolü sürüyor
  bool _processing = false; // içe aktarma sürüyor

  String? _fileName;
  ImportParseResult? _parsed;
  Set<String> _existingCodes = {};
  List<ImportedSaleRow> _toImport = []; // mükerrer olmayan, aktarılacaklar

  int _total = 0;
  int _done = 0;
  int _created = 0;
  final List<String> _errors = [];

  bool get _finished =>
      !_processing && (_created > 0 || (_errors.isNotEmpty && _done > 0));

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
      _fileName = result.files.single.name;
      _analyzing = true;
      _parsed = null;
      _toImport = [];
      _existingCodes = {};
      _created = 0;
      _done = 0;
      _total = 0;
      _errors.clear();
    });

    try {
      final parsed = OldSalesExcelParser.parse(bytes);
      // Mükerrer kontrolü: zaten içe aktarılmış satış kodlarını bul.
      final codes = parsed.rows.map((r) => r.saleCode).toList();
      final existing = await _repo.existingSaleCodes(codes);
      final toImport =
          parsed.rows.where((r) => !existing.contains(r.saleCode)).toList();

      if (!mounted) return;
      setState(() {
        _parsed = parsed;
        _existingCodes = existing;
        _toImport = toImport;
        _analyzing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _analyzing = false;
        _errors.add('Dosya okunamadı: $e');
      });
    }
  }

  Future<void> _runImport() async {
    if (_toImport.isEmpty) return;
    setState(() {
      _processing = true;
      _total = _toImport.length;
      _done = 0;
      _created = 0;
      _errors.clear();
    });

    for (final row in _toImport) {
      try {
        await _repo.importSale(row);
        _created++;
      } catch (e) {
        if (_errors.length < 50) {
          _errors.add('${row.saleCode}: $e');
        }
      } finally {
        if (mounted) setState(() => _done++);
      }
    }

    if (mounted) setState(() => _processing = false);
  }

  @override
  Widget build(BuildContext context) {
    final parsed = _parsed;
    final duplicateCount = _existingCodes.length;

    return AlertDialog(
      title: const Text('Eski Satışları İçe Aktar'),
      content: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'BenimPOS "Satış Raporu" (.xlsx) dosyasını seçin. Her satır bir '
              'satış olarak aktarılır; orijinal tarihler korunur. Aynı satış '
              'kodu zaten varsa atlanır (dosyayı tekrar yüklemek güvenlidir).',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            const SizedBox(height: 16),

            if (!_processing && !_finished)
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _analyzing ? null : _pickFile,
                    icon: const Icon(Icons.file_open_outlined),
                    label: const Text('Dosya Seç'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _fileName ?? 'Dosya seçilmedi',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _fileName != null
                            ? AppColors.textPrimary
                            : AppColors.textMuted,
                        fontWeight:
                            _fileName != null ? FontWeight.w500 : FontWeight.normal,
                      ),
                    ),
                  ),
                ],
              ),

            // ── Analiz göstergesi ──────────────────────────────────────────
            if (_analyzing) ...[
              const SizedBox(height: 16),
              Row(
                children: const [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 10),
                  Text('Dosya çözümleniyor...',
                      style: TextStyle(
                          fontSize: 13, color: AppColors.textSecondary)),
                ],
              ),
            ],

            // ── Önizleme (parse sonrası, içe aktarmadan önce) ──────────────
            if (parsed != null && !_processing && !_finished) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _StatBox(
                    icon: Icons.playlist_add_check_outlined,
                    label: 'Aktarılacak',
                    count: _toImport.length,
                    color: AppColors.success,
                  ),
                  _StatBox(
                    icon: Icons.content_copy_outlined,
                    label: 'Zaten mevcut',
                    count: duplicateCount,
                    color: AppColors.pos,
                  ),
                  _StatBox(
                    icon: Icons.block_outlined,
                    label: 'Atlanan/başlık',
                    count: parsed.skippedCount,
                    color: AppColors.textMuted,
                  ),
                ],
              ),
              if (_toImport.isNotEmpty) ...[
                const SizedBox(height: 14),
                const Text('İlk satırlar (önizleme):',
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                _PreviewTable(rows: _toImport.take(5).toList()),
              ],
              if (parsed.warnings.isNotEmpty) ...[
                const SizedBox(height: 10),
                _MessageBox(
                  messages: parsed.warnings,
                  color: AppColors.danger,
                ),
              ],
            ],

            // ── İçe aktarma ilerlemesi ─────────────────────────────────────
            if (_processing) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('İçe aktarılıyor...',
                      style: TextStyle(
                          fontSize: 13, color: AppColors.textSecondary)),
                  const Spacer(),
                  Text('$_done / $_total',
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary)),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _total == 0 ? null : _done / _total,
                  minHeight: 8,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                  valueColor:
                      const AlwaysStoppedAnimation(AppColors.primary),
                ),
              ),
            ],

            // ── Tamamlanma özeti ───────────────────────────────────────────
            if (_finished) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _StatBox(
                    icon: Icons.check_circle_outline,
                    label: 'İçe aktarılan',
                    count: _created,
                    color: AppColors.success,
                  ),
                  _StatBox(
                    icon: Icons.content_copy_outlined,
                    label: 'Zaten mevcut',
                    count: duplicateCount,
                    color: AppColors.pos,
                  ),
                  if (_errors.isNotEmpty)
                    _StatBox(
                      icon: Icons.error_outline,
                      label: 'Hata',
                      count: _errors.length,
                      color: AppColors.danger,
                    ),
                ],
              ),
              if (_errors.isNotEmpty) ...[
                const SizedBox(height: 12),
                _MessageBox(messages: _errors, color: AppColors.danger),
              ],
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: (_processing || _analyzing)
              ? null
              : () => Navigator.pop(context),
          child: const Text('Kapat'),
        ),
        if (!_processing && !_finished)
          ElevatedButton.icon(
            onPressed: (_toImport.isEmpty || _analyzing) ? null : _runImport,
            icon: const Icon(Icons.upload_outlined),
            label: Text('İçe Aktar (${_toImport.length})'),
          ),
      ],
    );
  }
}

// ── Önizleme tablosu ──────────────────────────────────────────────────────────

class _PreviewTable extends StatelessWidget {
  final List<ImportedSaleRow> rows;
  const _PreviewTable({required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        children: rows.map((r) {
          return Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              children: [
                SizedBox(
                  width: 120,
                  child: Text(r.saleCode,
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary),
                      overflow: TextOverflow.ellipsis),
                ),
                Expanded(
                  child: Text(
                    '${formatDate(r.saleDate)} · ${r.customerName ?? 'Perakende'}',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(formatCurrency(r.totalAmount),
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.bold)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Mesaj kutusu (uyarı/hata listesi) ─────────────────────────────────────────

class _MessageBox extends StatelessWidget {
  final List<String> messages;
  final Color color;
  const _MessageBox({required this.messages, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 110),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: ListView(
        padding: const EdgeInsets.all(8),
        shrinkWrap: true,
        children: messages
            .map((m) => Text('• $m',
                style: TextStyle(fontSize: 11, color: color)))
            .toList(),
      ),
    );
  }
}

// ── Özet kutusu ───────────────────────────────────────────────────────────────

class _StatBox extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final Color color;

  const _StatBox({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(count.toString(),
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: color)),
              Text(label,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textMuted)),
            ],
          ),
        ],
      ),
    );
  }
}
