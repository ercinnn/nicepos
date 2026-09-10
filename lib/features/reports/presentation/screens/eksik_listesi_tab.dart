import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/responsive.dart';
import '../../application/eksik_listesi_provider.dart';
import '../../data/models/ciro_analiz_record.dart';
import 'daily_report_screen.dart' show ReportTableCard, ReportEmptyCard;
import 'eksik_listesi_print_screen.dart';

/// Eksik Listesi sekmesi (Analiz sayfası 4. sekme) — Ciro Analiz'de
/// filtrelenip firma bazlı seçilen ürünlerin toplandığı çalışma listesi
/// (`eksikListesiControllerProvider`). Kullanıcı burada ürün bazında tik
/// kutusuyla seçim yapar; "Seçilenlerle Liste Oluştur" seçili ürünleri
/// (firma, sonra ada göre sıralanmış) ayrı bir önizleme/yazdırma sayfasına
/// (`EksikListesiPrintScreen`) gönderir.
///
/// Seçim UI'ı `customer_detail_screen.dart`'ın toplu-yazdırma tablosuyla
/// BİREBİR aynı desen: masaüstünde manuel checkbox `DataColumn`
/// (`showCheckboxColumn: false` — DataTable'ın kendi otomatik checkbox
/// sütunuyla çakışmasın), mobilde satırın solunda kendi hit-target'ına sahip
/// bir `Checkbox`.
class EksikListesiTab extends ConsumerStatefulWidget {
  const EksikListesiTab({super.key});

  @override
  ConsumerState<EksikListesiTab> createState() => _EksikListesiTabState();
}

class _EksikListesiTabState extends ConsumerState<EksikListesiTab> {
  final Set<String> _selectedProductIds = {};

  void _toggleSelect(String productId, bool selected) {
    setState(() {
      if (selected) {
        _selectedProductIds.add(productId);
      } else {
        _selectedProductIds.remove(productId);
      }
    });
  }

  void _toggleSelectAll(List<CiroAnalizRecord> records, bool allSelected) {
    setState(() {
      if (allSelected) {
        _selectedProductIds.removeAll(records.map((r) => r.productId));
      } else {
        _selectedProductIds.addAll(records.map((r) => r.productId));
      }
    });
  }

  void _removeItem(String productId) {
    ref.read(eksikListesiControllerProvider.notifier).remove(productId);
    setState(() => _selectedProductIds.remove(productId));
  }

  void _clearAll() {
    ref.read(eksikListesiControllerProvider.notifier).clear();
    setState(() => _selectedProductIds.clear());
  }

  void _openPreview(List<CiroAnalizRecord> records) {
    final selected = records
        .where((r) => _selectedProductIds.contains(r.productId))
        .toList()
      ..sort((a, b) {
        final byCompany = a.companyName
            .toLowerCase()
            .compareTo(b.companyName.toLowerCase());
        if (byCompany != 0) return byCompany;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    if (selected.isEmpty) return;
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => EksikListesiPrintScreen(records: selected),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = context.isMobile;
    final records = ref.watch(eksikListesiControllerProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Eksik Listesi', style: Theme.of(context).textTheme.titleLarge),
            const Spacer(),
            if (records.isNotEmpty)
              TextButton.icon(
                onPressed: _clearAll,
                icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                label: const Text('Listeyi Temizle'),
              ),
          ],
        ),
        const SizedBox(height: AppSizes.space12),
        if (records.isEmpty)
          const Expanded(
            child: ReportEmptyCard(
              'Ciro Analiz sekmesinden filtre uygulayıp firma seçerek buraya '
              'ürün ekleyebilirsiniz.',
            ),
          )
        else
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ReportTableCard(
                    child: isMobile
                        ? _EksikListesiMobileList(
                            records: records,
                            selectedIds: _selectedProductIds,
                            onToggleSelect: _toggleSelect,
                            onRemove: _removeItem,
                          )
                        : _EksikListesiTable(
                            records: records,
                            selectedIds: _selectedProductIds,
                            onToggleSelect: _toggleSelect,
                            onToggleSelectAll: _toggleSelectAll,
                            onRemove: _removeItem,
                          ),
                  ),
                  const SizedBox(height: AppSizes.space16),
                  FilledButton.icon(
                    onPressed: _selectedProductIds.isEmpty
                        ? null
                        : () => _openPreview(records),
                    icon: const Icon(Icons.receipt_long_outlined, size: 18),
                    label: Text(
                      'Seçilenlerle Liste Oluştur (${_selectedProductIds.length})',
                    ),
                  ),
                  const SizedBox(height: AppSizes.space24),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ── Masaüstü tablo ─────────────────────────────────────────────────────────

class _EksikListesiTable extends StatelessWidget {
  final List<CiroAnalizRecord> records;
  final Set<String> selectedIds;
  final void Function(String productId, bool selected) onToggleSelect;
  final void Function(List<CiroAnalizRecord> records, bool allSelected)
      onToggleSelectAll;
  final void Function(String productId) onRemove;

  const _EksikListesiTable({
    required this.records,
    required this.selectedIds,
    required this.onToggleSelect,
    required this.onToggleSelectAll,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final allSelected = records.isNotEmpty &&
        records.every((r) => selectedIds.contains(r.productId));
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        showCheckboxColumn: false,
        headingRowColor: WidgetStateProperty.all(AppColors.tableHeader),
        columns: [
          DataColumn(
            label: Checkbox(
              value: allSelected,
              tristate: selectedIds.isNotEmpty && !allSelected,
              onChanged: (_) => onToggleSelectAll(records, allSelected),
              activeColor: AppColors.primary,
            ),
          ),
          const DataColumn(label: Text('#')),
          const DataColumn(label: Text('Ürün')),
          const DataColumn(label: Text('Firma')),
          const DataColumn(label: Text('Stok'), numeric: true),
          const DataColumn(label: Text('Satış Adedi'), numeric: true),
          const DataColumn(label: Text('')),
        ],
        rows: List.generate(records.length, (i) {
          final r = records[i];
          final hasBarcode = r.barcode != null && r.barcode!.isNotEmpty;
          return DataRow(
            cells: [
              DataCell(Checkbox(
                value: selectedIds.contains(r.productId),
                onChanged: (v) => onToggleSelect(r.productId, v ?? false),
                activeColor: AppColors.primary,
              )),
              DataCell(Text(
                '${i + 1}',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              )),
              DataCell(Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    r.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (hasBarcode)
                    Text(
                      r.barcode!,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                ],
              )),
              DataCell(Text(r.companyName)),
              DataCell(Text(
                formatNumber(r.stockQuantity),
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: r.stockQuantity <= 0
                      ? AppColors.danger
                      : AppColors.textPrimary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              )),
              DataCell(Text(
                formatNumber(r.quantitySold),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              )),
              DataCell(IconButton(
                icon: const Icon(Icons.close, size: 18, color: AppColors.danger),
                tooltip: 'Listeden çıkar',
                onPressed: () => onRemove(r.productId),
              )),
            ],
          );
        }),
      ),
    );
  }
}

// ── Mobil kart listesi ─────────────────────────────────────────────────────

class _EksikListesiMobileList extends StatelessWidget {
  final List<CiroAnalizRecord> records;
  final Set<String> selectedIds;
  final void Function(String productId, bool selected) onToggleSelect;
  final void Function(String productId) onRemove;

  const _EksikListesiMobileList({
    required this.records,
    required this.selectedIds,
    required this.onToggleSelect,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: records.length,
      separatorBuilder: (_, _) =>
          const Divider(height: 1, color: AppColors.divider),
      itemBuilder: (context, i) {
        final r = records[i];
        final hasBarcode = r.barcode != null && r.barcode!.isNotEmpty;
        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.space12,
            vertical: AppSizes.space8,
          ),
          child: Row(
            children: [
              Checkbox(
                value: selectedIds.contains(r.productId),
                onChanged: (v) => onToggleSelect(r.productId, v ?? false),
                activeColor: AppColors.primary,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      r.name,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSizes.space4),
                    Text(
                      [
                        if (hasBarcode) r.barcode!,
                        r.companyName,
                        'Stok: ${formatNumber(r.stockQuantity)}',
                        '${formatNumber(r.quantitySold)} adet satıldı',
                      ].join('  ·  '),
                      style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18, color: AppColors.danger),
                tooltip: 'Listeden çıkar',
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                onPressed: () => onRemove(r.productId),
              ),
            ],
          ),
        );
      },
    );
  }
}
