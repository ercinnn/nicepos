import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../reports/application/reports_provider.dart';
import '../../../reports/data/models/product_analysis_record.dart';

/// Durağan Ürünler sekmesi (Ürünler 5. sekme). Katalogdaki tüm ürünleri
/// tarar, seçili gün eşiği kadar (varsayılan 60) süredir hiç satılmayanları
/// listeler — satır dokunuşu doğrudan ürün düzenleme formuna götürür.
///
/// Veri kaynağı Raporlar'ın `productAnalysisProvider`'ı ile PAYLAŞILIR (aynı
/// `product_analysis` RPC'si) — burada dönemsel ciro/adet KULLANILMAZ, yalnız
/// `lastSaleDate`/`stockQuantity`/`stockValue` alanları okunur; bu yüzden RPC
/// sabit geniş bir aralıkla (2000'den bugüne) BİR KEZ çağrılır.
class StagnantProductsTab extends ConsumerStatefulWidget {
  const StagnantProductsTab({super.key});

  @override
  ConsumerState<StagnantProductsTab> createState() => _StagnantProductsTabState();
}

class _StagnantProductsTabState extends ConsumerState<StagnantProductsTab> {
  static final DateTime _rangeStart = DateTime(2000, 1, 1);
  // `DateTime.now()` build() içinde tekrar çağrılırsa her seferinde farklı
  // bir DateRangeParam üretip provider'ı sürekli yeniden tetikler — BİR KEZ
  // initState'te sabitlenir.
  late final DateTime _rangeEnd;

  final _stagnantDaysCtrl = TextEditingController(text: '60');
  int _stagnantDays = 60;

  @override
  void initState() {
    super.initState();
    _rangeEnd = DateTime.now();
  }

  @override
  void dispose() {
    _stagnantDaysCtrl.dispose();
    super.dispose();
  }

  void _onStagnantDaysChanged(String v) {
    final parsed = int.tryParse(v);
    final next = (parsed != null && parsed >= 0) ? parsed : 60;
    if (next != _stagnantDays) setState(() => _stagnantDays = next);
  }

  List<ProductAnalysisRecord> _filterAndSort(List<ProductAnalysisRecord> records) {
    final list = records.where((r) => r.isStagnant(_stagnantDays)).toList();
    // Hiç satılmayan (null gün = sonsuz durağan) en üstte; eşitlikte stok
    // değeri azalan.
    list.sort((a, b) {
      final da = a.daysSinceLastSale;
      final db = b.daysSinceLastSale;
      if (da == null && db == null) return b.stockValue.compareTo(a.stockValue);
      if (da == null) return -1;
      if (db == null) return 1;
      final cmp = db.compareTo(da);
      return cmp != 0 ? cmp : b.stockValue.compareTo(a.stockValue);
    });
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = context.isMobile;
    final recordsAsync =
        ref.watch(productAnalysisProvider(DateRangeParam(_rangeStart, _rangeEnd)));

    return Padding(
      padding: const EdgeInsets.all(AppSizes.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isMobile) _buildMobileHeader() else _buildDesktopHeader(),
          const SizedBox(height: AppSizes.space16),
          Expanded(
            child: recordsAsync.when(
              loading: () => const SkeletonList(itemCount: 8),
              error: (e, _) => Center(child: Text('Hata: $e')),
              data: (records) {
                final filtered = _filterAndSort(records);
                if (filtered.isEmpty) {
                  return const EmptyState(
                    icon: Icons.hourglass_bottom_outlined,
                    title: 'Durağan ürün bulunamadı',
                    message: 'Seçili eşikte hiç satılmayan ürün yok.',
                  );
                }
                return isMobile
                    ? _StagnantMobileList(records: filtered)
                    : _StagnantTable(records: filtered);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopHeader() {
    return Row(
      children: [
        Text('Durağan Ürünler', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(width: AppSizes.space16),
        Text(
          'Ürünler listesindeki, seçili gün eşiği kadar süredir hiç satılmayan ürünler.',
          style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
        const Spacer(),
        SizedBox(width: 170, child: _buildStagnantDaysField()),
      ],
    );
  }

  Widget _buildMobileHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Durağan Ürünler', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSizes.space4),
        const Text(
          'Seçili gün eşiği kadar süredir hiç satılmayan ürünler.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
        const SizedBox(height: AppSizes.space8),
        _buildStagnantDaysField(),
      ],
    );
  }

  Widget _buildStagnantDaysField() {
    return TextField(
      controller: _stagnantDaysCtrl,
      onChanged: _onStagnantDaysChanged,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: const TextStyle(
        fontSize: 13,
        fontFeatures: [FontFeature.tabularFigures()],
      ),
      decoration: InputDecoration(
        labelText: 'Durağan Eşiği',
        suffixText: 'gün',
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSizes.space12,
          vertical: AppSizes.space8,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusSm),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusSm),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusSm),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }
}

String _lastSaleLabel(ProductAnalysisRecord r) {
  if (r.lastSaleDate == null) return 'Hiç satılmadı';
  return '${formatDate(r.lastSaleDate!)} (${r.daysSinceLastSale} gün önce)';
}

// ── Masaüstü tablo ─────────────────────────────────────────────────────────

class _StagnantTable extends StatelessWidget {
  final List<ProductAnalysisRecord> records;
  const _StagnantTable({required this.records});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: AppSizes.cardDecoration(),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(AppColors.goldBg),
            headingTextStyle: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              letterSpacing: 0.2,
            ),
            columns: const [
              DataColumn(label: Text('#')),
              DataColumn(label: Text('Ürün')),
              DataColumn(label: Text('Son Satış')),
              DataColumn(label: Text('Stok'), numeric: true),
              DataColumn(label: Text('Stok Değeri'), numeric: true),
            ],
            rows: List.generate(records.length, (i) {
              final r = records[i];
              final hasBarcode = r.barcode != null && r.barcode!.isNotEmpty;
              return DataRow(
                onSelectChanged: (_) => context.go('/products/${r.productId}'),
                cells: [
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
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              r.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (r.memberCount > 1) ...[
                            const SizedBox(width: AppSizes.space6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSizes.space6,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(AppSizes.radiusPill),
                              ),
                              child: Text(
                                '${r.memberCount} barkod',
                                style: const TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ],
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
                    _lastSaleLabel(r),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.warning,
                    ),
                  )),
                  DataCell(Text(
                    formatNumber(r.stockQuantity),
                    style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
                  )),
                  DataCell(Text(
                    formatCurrency(r.stockValue),
                    style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
                  )),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }
}

// ── Mobil kart listesi ─────────────────────────────────────────────────────

class _StagnantMobileList extends StatelessWidget {
  final List<ProductAnalysisRecord> records;
  const _StagnantMobileList({required this.records});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: records.length,
      separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.divider),
      itemBuilder: (context, i) {
        final r = records[i];
        final hasBarcode = r.barcode != null && r.barcode!.isNotEmpty;
        return InkWell(
          onTap: () => context.go('/products/${r.productId}'),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.space12,
              vertical: AppSizes.space12,
            ),
            child: Row(
              children: [
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
                          _lastSaleLabel(r),
                        ].join('  ·  '),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.warning,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSizes.space8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      formatCurrency(r.stockValue),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    Text(
                      'Stok: ${formatNumber(r.stockQuantity)}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
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
