import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/responsive.dart';
import '../../application/reports_provider.dart';
import '../../data/models/missing_list_record.dart';
import 'daily_report_screen.dart' show ReportTableCard, ReportEmptyCard;

/// Eksik Listesi sekmesi (Raporlar 6. sekme).
///
/// Tarama/analiz ekranı → HERO YOK. Kolonlar: Sıra · Ürün (+ barkod) · Adet
/// (aralıkta satılan) · Stok (güncel) · Toplam Ciro (gerçek/indirim-sonrası) ·
/// Ciro Payı (seçili aralıktaki TÜM ürünlerin toplam cirosuna oranı, %) ·
/// Firma. Varsayılan sıralama adet azalan; masaüstünde her sütun başlığına
/// dokununca `DataTable` yerleşik `sortColumnIndex`/`onSort` mekanizmasıyla
/// azdan çoğa/çoktan aza değiştirilebilir (sıralama tamamen istemci
/// tarafında, `records` zaten tek seferde tam çekildiğinden sayfalama yok —
/// `products_list_screen.dart`'ın server-side sort'undan FARKLI, basit yerel
/// `List.sort`). Filtre: tarih aralığı (default 2026-01-01 → bugün) —
/// `best_sellers_tab.dart` ile aynı desen, yalnız min-fiyat filtresi yok.
class MissingListTab extends ConsumerStatefulWidget {
  const MissingListTab({super.key});

  @override
  ConsumerState<MissingListTab> createState() => _MissingListTabState();
}

class _MissingListTabState extends ConsumerState<MissingListTab> {
  DateTime _start = DateTime(2026, 1, 1);
  DateTime _end = DateTime.now();

  // Masaüstü tablo sütun sıralaması — yerel (client-side), `records` zaten
  // tam çekildiği için sunucuya gitmez. Varsayılan: adet azalan (repository
  // ile aynı).
  String _sortColumn = 'quantitySold';
  bool _sortAscending = false;

  void _onSort(String column, bool ascending) {
    setState(() {
      _sortColumn = column;
      _sortAscending = ascending;
    });
  }

  List<MissingListRecord> _sortRecords(List<MissingListRecord> records) {
    final sorted = List<MissingListRecord>.from(records);
    int compare(MissingListRecord a, MissingListRecord b) {
      switch (_sortColumn) {
        case 'name':
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        case 'companyName':
          return a.companyName
              .toLowerCase()
              .compareTo(b.companyName.toLowerCase());
        case 'stockQuantity':
          return a.stockQuantity.compareTo(b.stockQuantity);
        case 'totalRevenue':
          return a.totalRevenue.compareTo(b.totalRevenue);
        case 'revenueSharePercent':
          return a.revenueSharePercent.compareTo(b.revenueSharePercent);
        case 'quantitySold':
        default:
          return a.quantitySold.compareTo(b.quantitySold);
      }
    }

    sorted.sort((a, b) => _sortAscending ? compare(a, b) : compare(b, a));
    return sorted;
  }

  Future<void> _pickStart() async {
    final p = await showDatePicker(
      context: context,
      initialDate: _start,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (p != null) setState(() => _start = p);
  }

  Future<void> _pickEnd() async {
    final p = await showDatePicker(
      context: context,
      initialDate: _end,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (p != null) setState(() => _end = p);
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = context.isMobile;
    // Aralık normalize edilir (başlangıç ≤ bitiş).
    final start = _start.isBefore(_end) ? _start : _end;
    final end = _start.isBefore(_end) ? _end : _start;

    final recordsAsync = ref.watch(
      missingListProvider(start: start, end: end),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isMobile)
          _buildMobileControls()
        else
          _buildDesktopControls(),
        const SizedBox(height: AppSizes.space16),
        Expanded(
          child: recordsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Hata: $e')),
            data: (records) {
              if (records.isEmpty) {
                return const ReportEmptyCard(
                  'Seçili aralıkta satılan ürün bulunamadı.',
                );
              }
              final sorted = _sortRecords(records);
              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ReportTableCard(
                      child: isMobile
                          ? _MissingListMobileList(records: sorted)
                          : _MissingListTable(
                              records: sorted,
                              sortColumn: _sortColumn,
                              sortAscending: _sortAscending,
                              onSort: _onSort,
                            ),
                    ),
                    const SizedBox(height: AppSizes.space24),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ── Masaüstü kontrol satırı ────────────────────────────────────────────────
  Widget _buildDesktopControls() {
    return Row(
      children: [
        Text('Eksik Listesi', style: Theme.of(context).textTheme.titleLarge),
        const Spacer(),
        OutlinedButton.icon(
          icon: const Icon(Icons.calendar_today, size: 16),
          label: Text('Başlangıç: ${formatDate(_start)}'),
          onPressed: _pickStart,
        ),
        const SizedBox(width: AppSizes.space8),
        const Icon(Icons.arrow_forward, size: 16, color: AppColors.textMuted),
        const SizedBox(width: AppSizes.space8),
        OutlinedButton.icon(
          icon: const Icon(Icons.calendar_today, size: 16),
          label: Text('Bitiş: ${formatDate(_end)}'),
          onPressed: _pickEnd,
        ),
      ],
    );
  }

  // ── Mobil kontrol satırı ───────────────────────────────────────────────────
  Widget _buildMobileControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Eksik Listesi', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSizes.space12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today, size: 14),
                label: Text(
                  formatDate(_start),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
                onPressed: _pickStart,
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Icon(Icons.arrow_forward,
                  size: 14, color: AppColors.textMuted),
            ),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today, size: 14),
                label: Text(
                  formatDate(_end),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
                onPressed: _pickEnd,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Masaüstü tablo ─────────────────────────────────────────────────────────

class _MissingListTable extends StatelessWidget {
  final List<MissingListRecord> records;
  final String sortColumn;
  final bool sortAscending;
  final void Function(String column, bool ascending) onSort;

  const _MissingListTable({
    required this.records,
    required this.sortColumn,
    required this.sortAscending,
    required this.onSort,
  });

  // Sütun sırası: #(0, sıralanamaz) · Ürün(1) · Adet(2) · Stok(3, öne alındı
  // — kullanıcı geniş Toplam Ciro/Ciro Payı sütunları arkasında kaldığından
  // "görünmüyor" şikayeti etti) · Toplam Ciro(4) · Ciro Payı(5) · Firma(6).
  static const _columnKeys = [
    null,
    'name',
    'quantitySold',
    'stockQuantity',
    'totalRevenue',
    'revenueSharePercent',
    'companyName',
  ];

  int? get _sortColumnIndex {
    final idx = _columnKeys.indexOf(sortColumn);
    return idx == -1 ? null : idx;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(AppColors.tableHeader),
        sortColumnIndex: _sortColumnIndex,
        sortAscending: sortAscending,
        columns: [
          const DataColumn(label: Text('#')),
          DataColumn(
            label: const Text('Ürün'),
            onSort: (_, ascending) => onSort('name', ascending),
          ),
          DataColumn(
            label: const Text('Adet'),
            numeric: true,
            onSort: (_, ascending) => onSort('quantitySold', ascending),
          ),
          DataColumn(
            label: const Text('Stok'),
            numeric: true,
            onSort: (_, ascending) => onSort('stockQuantity', ascending),
          ),
          DataColumn(
            label: const Text('Toplam Ciro'),
            numeric: true,
            onSort: (_, ascending) => onSort('totalRevenue', ascending),
          ),
          DataColumn(
            label: const Text('Ciro Payı'),
            numeric: true,
            onSort: (_, ascending) => onSort('revenueSharePercent', ascending),
          ),
          DataColumn(
            label: const Text('Firma'),
            onSort: (_, ascending) => onSort('companyName', ascending),
          ),
        ],
        rows: List.generate(records.length, (i) {
          final r = records[i];
          final hasBarcode = r.barcode != null && r.barcode!.isNotEmpty;
          final lowStock = r.stockQuantity <= 0;
          return DataRow(cells: [
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
            DataCell(Text(
              formatNumber(r.quantitySold),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            )),
            DataCell(Text(
              formatNumber(r.stockQuantity),
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: lowStock ? AppColors.danger : AppColors.textPrimary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            )),
            DataCell(Text(
              formatCurrency(r.totalRevenue),
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            )),
            DataCell(Text(
              _formatRevenueShare(r.revenueSharePercent),
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            )),
            DataCell(Text(
              r.companyName,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            )),
          ]);
        }),
      ),
    );
  }
}

// ── Mobil kart listesi ─────────────────────────────────────────────────────

class _MissingListMobileList extends StatelessWidget {
  final List<MissingListRecord> records;
  const _MissingListMobileList({required this.records});

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
        final lowStock = r.stockQuantity <= 0;
        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.space12,
            vertical: AppSizes.space12,
          ),
          child: Row(
            children: [
              // Sıra numarası
              SizedBox(
                width: 28,
                child: Text(
                  '${i + 1}',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              // Ürün adı + barkod + firma
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
                      ].join('  ·  '),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSizes.space8),
              // Sağ: adet + stok
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${formatNumber(r.quantitySold)} adet',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: AppSizes.space4),
                  Text(
                    'Stok: ${formatNumber(r.stockQuantity)}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color:
                          lowStock ? AppColors.danger : AppColors.textSecondary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: AppSizes.space4),
                  Text(
                    formatCurrency(r.totalRevenue),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: AppSizes.space4),
                  Text(
                    _formatRevenueShare(r.revenueSharePercent),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// Ciro Payı hücresi biçimi: nokta sonrası daima 2 hane, boşluksuz (%2.50).
String _formatRevenueShare(num value) => '%${value.toStringAsFixed(2)}';
