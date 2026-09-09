import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/responsive.dart';
import '../../application/reports_provider.dart';
import '../../data/models/product_analysis_record.dart';
import 'daily_report_screen.dart' show ReportTableCard, ReportEmptyCard;

/// Ürün Analizi sekmesi (Raporlar 5. sekme). Tarama/analiz ekranı → HERO YOK
/// (design-tokens KARAR v1.3/v1.6, "En Çok Satanlar" ile aynı dil).
///
/// Tek bir sunucu çağrısı (seçili tarih aralığı için) tüm ürünleri getirir;
/// "Durağan Eşiği" alanı ve görünüm seçimi TAMAMEN istemci tarafındadır —
/// değiştirilince yeniden fetch TETİKLENMEZ, yalnız anında yeniden
/// filtrele/sırala (bkz. `productAnalysisProvider`).
enum _AnalysisView { revenue, stagnant, candidates }

class ProductAnalysisTab extends ConsumerStatefulWidget {
  const ProductAnalysisTab({super.key});

  @override
  ConsumerState<ProductAnalysisTab> createState() => _ProductAnalysisTabState();
}

class _ProductAnalysisTabState extends ConsumerState<ProductAnalysisTab> {
  DateTime _start = DateTime(2026, 1, 1);
  DateTime _end = DateTime.now();
  final _stagnantDaysCtrl = TextEditingController(text: '60');
  int _stagnantDays = 60;
  _AnalysisView _view = _AnalysisView.revenue;

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

  List<ProductAnalysisRecord> _applyView(List<ProductAnalysisRecord> records) {
    switch (_view) {
      case _AnalysisView.revenue:
        final list = records.where((r) => r.revenueInPeriod > 0).toList();
        list.sort((a, b) => b.revenueInPeriod.compareTo(a.revenueInPeriod));
        return list;
      case _AnalysisView.stagnant:
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
      case _AnalysisView.candidates:
        final list = records
            .where((r) => r.isStagnant(_stagnantDays) && r.stockQuantity > 0)
            .toList();
        list.sort((a, b) => b.stockValue.compareTo(a.stockValue));
        return list;
    }
  }

  String get _emptyMessage {
    switch (_view) {
      case _AnalysisView.revenue:
        return 'Seçili aralıkta ciro getiren ürün bulunamadı.';
      case _AnalysisView.stagnant:
        return 'Durağan ürün bulunamadı.';
      case _AnalysisView.candidates:
        return 'Satmaktan vazgeçilmesi önerilen ürün yok.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = context.isMobile;
    // Aralık normalize edilir (başlangıç ≤ bitiş).
    final start = _start.isBefore(_end) ? _start : _end;
    final end = _start.isBefore(_end) ? _end : _start;
    // Ciro/gün · Adet/gün paydası — seçili aralığın gün sayısı (dahil), en az 1
    // (aynı gün seçilirse 0'a bölüm olmasın).
    final periodDays = end.difference(start).inDays + 1;

    final recordsAsync = ref.watch(productAnalysisProvider(DateRangeParam(start, end)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isMobile) _buildMobileControls() else _buildDesktopControls(),
        const SizedBox(height: AppSizes.space12),
        _buildViewSelector(),
        const SizedBox(height: AppSizes.space16),
        Expanded(
          child: recordsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Hata: $e')),
            data: (records) {
              final filtered = _applyView(records);
              if (filtered.isEmpty) {
                return ReportEmptyCard(_emptyMessage);
              }
              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ReportTableCard(
                      child: isMobile
                          ? _ProductAnalysisMobileList(
                              records: filtered,
                              stagnantDays: _stagnantDays,
                              periodDays: periodDays)
                          : _ProductAnalysisTable(
                              records: filtered,
                              stagnantDays: _stagnantDays,
                              periodDays: periodDays),
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
        Text('Ürün Analizi', style: Theme.of(context).textTheme.titleLarge),
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
        const SizedBox(width: AppSizes.space12),
        SizedBox(width: 170, child: _buildStagnantDaysField()),
      ],
    );
  }

  // ── Mobil kontrol satırı ───────────────────────────────────────────────────
  Widget _buildMobileControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Ürün Analizi', style: Theme.of(context).textTheme.titleLarge),
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
              child: Icon(Icons.arrow_forward, size: 14, color: AppColors.textMuted),
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
        const SizedBox(height: AppSizes.space8),
        _buildStagnantDaysField(),
      ],
    );
  }

  // ── Durağan eşiği alanı ─────────────────────────────────────────────────────
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

  // ── Görünüm seçici (aynı veri, istemci tarafı filtre/sıralama) ────────────
  Widget _buildViewSelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SegmentedButton<_AnalysisView>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(
            value: _AnalysisView.revenue,
            icon: Icon(Icons.trending_up_outlined, size: 16),
            label: Text('Ciro Sıralaması', maxLines: 1, softWrap: false),
          ),
          ButtonSegment(
            value: _AnalysisView.stagnant,
            icon: Icon(Icons.hourglass_bottom_outlined, size: 16),
            label: Text('Durağan Ürünler', maxLines: 1, softWrap: false),
          ),
          ButtonSegment(
            value: _AnalysisView.candidates,
            icon: Icon(Icons.warning_amber_outlined, size: 16),
            label: Text('Vazgeçilmesi Önerilen', maxLines: 1, softWrap: false),
          ),
        ],
        selected: {_view},
        onSelectionChanged: (s) => setState(() => _view = s.first),
      ),
    );
  }
}

// ── Paylaşılan biçimlendirme ────────────────────────────────────────────────

String _lastSaleLabel(ProductAnalysisRecord r) {
  if (r.lastSaleDate == null) return 'Hiç satılmadı';
  return '${formatDate(r.lastSaleDate!)} (${r.daysSinceLastSale} gün önce)';
}

// ── "Durağan" rozeti (products_list_screen.dart _StatusBadge ile aynı stil,
// renk AppColors.warning — mevcut "Tükendi" rozetinin danger'ıyla çakışmasın) ─

class _StagnantBadge extends StatelessWidget {
  final bool stagnant;
  const _StagnantBadge({required this.stagnant});

  @override
  Widget build(BuildContext context) {
    if (!stagnant) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.space6,
        vertical: AppSizes.space2,
      ),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSizes.radiusPill),
      ),
      child: const Text(
        'Durağan',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: AppColors.warning,
          letterSpacing: 0.1,
        ),
      ),
    );
  }
}

// ── Masaüstü tablo ─────────────────────────────────────────────────────────

class _ProductAnalysisTable extends StatelessWidget {
  final List<ProductAnalysisRecord> records;
  final int stagnantDays;
  final int periodDays;
  const _ProductAnalysisTable({
    required this.records,
    required this.stagnantDays,
    required this.periodDays,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(AppColors.tableHeader),
        columns: const [
          DataColumn(label: Text('#')),
          DataColumn(label: Text('Ürün')),
          DataColumn(label: Text('Ciro (Aralık)'), numeric: true),
          DataColumn(label: Text('Ciro/Gün'), numeric: true),
          DataColumn(label: Text('Adet (Aralık)'), numeric: true),
          DataColumn(label: Text('Adet/Gün'), numeric: true),
          DataColumn(label: Text('Son Satış')),
          DataColumn(label: Text('Stok'), numeric: true),
          DataColumn(label: Text('Stok Değeri'), numeric: true),
          DataColumn(label: Text('Durum')),
        ],
        rows: List.generate(records.length, (i) {
          final r = records[i];
          final hasBarcode = r.barcode != null && r.barcode!.isNotEmpty;
          final stagnant = r.isStagnant(stagnantDays);
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
              formatCurrency(r.revenueInPeriod),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            )),
            DataCell(Text(
              formatCurrency(r.revenueInPeriod / periodDays),
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            )),
            DataCell(Text(
              formatNumber(r.quantitySoldInPeriod),
              style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
            )),
            DataCell(Text(
              formatNumber(r.quantitySoldInPeriod / periodDays),
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            )),
            DataCell(Text(
              _lastSaleLabel(r),
              style: TextStyle(
                fontSize: 12,
                color: stagnant ? AppColors.warning : AppColors.textSecondary,
                fontWeight: stagnant ? FontWeight.w600 : FontWeight.normal,
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
            DataCell(_StagnantBadge(stagnant: stagnant)),
          ]);
        }),
      ),
    );
  }
}

// ── Mobil kart listesi ─────────────────────────────────────────────────────

class _ProductAnalysisMobileList extends StatelessWidget {
  final List<ProductAnalysisRecord> records;
  final int stagnantDays;
  final int periodDays;
  const _ProductAnalysisMobileList({
    required this.records,
    required this.stagnantDays,
    required this.periodDays,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: records.length,
      separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.divider),
      itemBuilder: (context, i) {
        final r = records[i];
        final hasBarcode = r.barcode != null && r.barcode!.isNotEmpty;
        final stagnant = r.isStagnant(stagnantDays);
        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.space12,
            vertical: AppSizes.space12,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      r.name,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppSizes.space6),
                  _StagnantBadge(stagnant: stagnant),
                ],
              ),
              const SizedBox(height: AppSizes.space4),
              Text(
                [
                  if (hasBarcode) r.barcode!,
                  _lastSaleLabel(r),
                ].join('  ·  '),
                style: TextStyle(
                  fontSize: 11,
                  color: stagnant ? AppColors.warning : AppColors.textMuted,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: AppSizes.space8),
              Row(
                children: [
                  Expanded(
                    child: _MiniStat('Ciro', formatCurrency(r.revenueInPeriod), AppColors.primary),
                  ),
                  Expanded(
                    child: _MiniStat(
                        'Adet', formatNumber(r.quantitySoldInPeriod), AppColors.textSecondary),
                  ),
                  Expanded(
                    child: _MiniStat(
                        'Stok Değeri', formatCurrency(r.stockValue), AppColors.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.space6),
              Row(
                children: [
                  Expanded(
                    child: _MiniStat('Ciro/Gün', formatCurrency(r.revenueInPeriod / periodDays),
                        AppColors.textSecondary),
                  ),
                  Expanded(
                    child: _MiniStat('Adet/Gün',
                        formatNumber(r.quantitySoldInPeriod / periodDays), AppColors.textSecondary),
                  ),
                  const Expanded(child: SizedBox.shrink()),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MiniStat(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
        Text(
          value,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: color,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
