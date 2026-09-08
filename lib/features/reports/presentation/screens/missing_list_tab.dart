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
/// tarafında, `records` zaten tek seferde tam çekildiğinden sunucu tarafı
/// sıralama yok — `products_list_screen.dart`'ın server-side sort'undan
/// FARKLI, basit yerel `List.sort`). Firma sütunu da alfabetik sıralanır;
/// `.toLowerCase().compareTo()` Unicode kod noktası sırasına göre çalıştığından
/// rakamlar (0-9) harflerden ÖNCE gelir — kullanıcının istediği "numaralar
/// başta" davranışı ekstra kod GEREKTİRMEDEN sağlanır.
///
/// **Sayfalama:** `_pageSize` (100) — tüm liste tek seferde çekilir
/// (`records`), sayfalama yalnız GÖRÜNTÜLEME amaçlı istemci tarafı dilimleme
/// (`List.sublist`). Sıra numarası (#) sayfalar arasında SÜREKLİ (101, 102...
/// gibi), her sayfada 1'den başlamaz.
///
/// **%80 ciro vurgusu (Pareto/ABC):** `_computeTop80ProductIds` TÜM listeyi
/// (mevcut sıralama/sayfadan BAĞIMSIZ) `totalRevenue` azalana göre sıralayıp
/// kümülatif toplamı aralığın toplam cirosunun %80'ine ulaşana kadar
/// işaretler (eşiği aşan son ürün DAHİL — klasik ABC "A sınıfı" tanımı).
/// İşaretli satırlar `AppColors.success` @0.12 alfa ile açık yeşil boyanır.
/// Filtre: tarih aralığı (default 2026-01-01 → bugün) — `best_sellers_tab.dart`
/// ile aynı desen, yalnız min-fiyat filtresi yok.
class MissingListTab extends ConsumerStatefulWidget {
  const MissingListTab({super.key});

  @override
  ConsumerState<MissingListTab> createState() => _MissingListTabState();
}

class _MissingListTabState extends ConsumerState<MissingListTab> {
  static const _pageSize = 100;

  DateTime _start = DateTime(2026, 1, 1);
  DateTime _end = DateTime.now();

  // Masaüstü tablo sütun sıralaması — yerel (client-side), `records` zaten
  // tam çekildiği için sunucuya gitmez. Varsayılan: adet azalan (repository
  // ile aynı).
  String _sortColumn = 'quantitySold';
  bool _sortAscending = false;

  int _page = 0;

  void _onSort(String column, bool ascending) {
    setState(() {
      _sortColumn = column;
      _sortAscending = ascending;
      _page = 0;
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

  // Seçili aralıktaki TÜM ürünlerin toplam cirosunun %80'ine kümülatif
  // olarak ulaşan (eşiği aşan son ürün DAHİL) ürün id'lerini döner —
  // mevcut sıralama/sayfadan bağımsız, her zaman `totalRevenue` azalana
  // göre hesaplanır (klasik ABC/Pareto "A sınıfı" tanımı).
  Set<String> _computeTop80ProductIds(List<MissingListRecord> records) {
    final byRevenue = List<MissingListRecord>.from(records)
      ..sort((a, b) => b.totalRevenue.compareTo(a.totalRevenue));
    final grandTotal = byRevenue.fold<num>(0, (sum, r) => sum + r.totalRevenue);
    if (grandTotal <= 0) return {};
    num cumulative = 0;
    final ids = <String>{};
    for (final r in byRevenue) {
      final beforePercent = cumulative / grandTotal * 100;
      cumulative += r.totalRevenue;
      if (beforePercent < 80) {
        ids.add(r.productId);
      }
    }
    return ids;
  }

  Future<void> _pickStart() async {
    final p = await showDatePicker(
      context: context,
      initialDate: _start,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (p != null) setState(() { _start = p; _page = 0; });
  }

  Future<void> _pickEnd() async {
    final p = await showDatePicker(
      context: context,
      initialDate: _end,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (p != null) setState(() { _end = p; _page = 0; });
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
              final topProductIds = _computeTop80ProductIds(records);

              final pageCount = (sorted.length / _pageSize).ceil();
              final safePage = _page.clamp(0, pageCount - 1);
              final startIdx = safePage * _pageSize;
              final endIdx = (startIdx + _pageSize).clamp(0, sorted.length);
              final pageRecords = sorted.sublist(startIdx, endIdx);

              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSizes.space8),
                      child: Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: AppColors.success.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(width: AppSizes.space8),
                          const Text(
                            'Açık yeşil: cironun %80\'ini oluşturan ürünler',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ReportTableCard(
                      child: isMobile
                          ? _MissingListMobileList(
                              records: pageRecords,
                              startIndex: startIdx,
                              topProductIds: topProductIds,
                            )
                          : _MissingListTable(
                              records: pageRecords,
                              startIndex: startIdx,
                              topProductIds: topProductIds,
                              sortColumn: _sortColumn,
                              sortAscending: _sortAscending,
                              onSort: _onSort,
                            ),
                    ),
                    const SizedBox(height: AppSizes.space12),
                    _buildPagination(
                      page: safePage,
                      pageCount: pageCount,
                      totalCount: sorted.length,
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

  // ── Sayfalama kontrolü ─────────────────────────────────────────────────────
  Widget _buildPagination({
    required int page,
    required int pageCount,
    required int totalCount,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TextButton.icon(
          onPressed:
              page > 0 ? () => setState(() => _page = page - 1) : null,
          icon: const Icon(Icons.chevron_left),
          label: const Text('Önceki'),
        ),
        const SizedBox(width: AppSizes.space16),
        Text(
          'Sayfa ${page + 1} / $pageCount  ·  toplam ${formatNumber(totalCount)} ürün',
          style: const TextStyle(
            fontSize: 13,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(width: AppSizes.space16),
        TextButton.icon(
          onPressed: page < pageCount - 1
              ? () => setState(() => _page = page + 1)
              : null,
          icon: const Icon(Icons.chevron_right),
          label: const Text('Sonraki'),
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
  final int startIndex;
  final Set<String> topProductIds;
  final String sortColumn;
  final bool sortAscending;
  final void Function(String column, bool ascending) onSort;

  const _MissingListTable({
    required this.records,
    required this.startIndex,
    required this.topProductIds,
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
          final isTop80 = topProductIds.contains(r.productId);
          return DataRow(
            color: isTop80
                ? WidgetStateProperty.all(
                    AppColors.success.withValues(alpha: 0.12))
                : null,
            cells: [
            DataCell(Text(
              '${startIndex + i + 1}',
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
  final int startIndex;
  final Set<String> topProductIds;
  const _MissingListMobileList({
    required this.records,
    required this.startIndex,
    required this.topProductIds,
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
        final lowStock = r.stockQuantity <= 0;
        final isTop80 = topProductIds.contains(r.productId);
        return Container(
          color: isTop80
              ? AppColors.success.withValues(alpha: 0.12)
              : null,
          child: Padding(
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
                  '${startIndex + i + 1}',
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
          ),
        );
      },
    );
  }
}

// Ciro Payı hücresi biçimi: nokta sonrası daima 2 hane, boşluksuz (%2.50).
String _formatRevenueShare(num value) => '%${value.toStringAsFixed(2)}';
