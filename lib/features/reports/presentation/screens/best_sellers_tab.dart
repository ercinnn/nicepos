import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/responsive.dart';
import '../../application/reports_provider.dart';
import '../../data/models/best_seller_record.dart';
import 'daily_report_screen.dart' show ReportTableCard, ReportEmptyCard;

/// En Çok Satanlar sekmesi (Raporlar 4. sekme, design-tokens §5 KARAR v1.6).
///
/// Tarama/analiz ekranı → HERO YOK. Kolonlar: Sıra · Ürün (+ barkod) · Birim
/// Fiyat (güncel price1) · Adet (aralıkta satılan) · Son Satış Tarihi. Sıralama
/// adet azalan. Filtreler: tarih aralığı (default 2026-01-01 → bugün) + min.
/// fiyat (default 50, elle düzenlenebilir).
class BestSellersTab extends ConsumerStatefulWidget {
  const BestSellersTab({super.key});

  @override
  ConsumerState<BestSellersTab> createState() => _BestSellersTabState();
}

class _BestSellersTabState extends ConsumerState<BestSellersTab> {
  DateTime _start = DateTime(2026, 1, 1);
  DateTime _end = DateTime.now();
  final _minPriceCtrl = TextEditingController(text: '50');
  num _minPrice = 50;

  @override
  void dispose() {
    _minPriceCtrl.dispose();
    super.dispose();
  }

  // Min. fiyat girişi — virgül/nokta ondalık kabul; boş/geçersiz → 0 (tümü).
  void _onMinPriceChanged(String v) {
    final parsed = num.tryParse(v.replaceAll(',', '.'));
    final next = (parsed != null && parsed >= 0) ? parsed : 0;
    if (next != _minPrice) setState(() => _minPrice = next);
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
      bestSellersProvider(start: start, end: end, minPrice: _minPrice),
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
                  'Seçili aralık ve fiyat eşiğinde satılan ürün bulunamadı.',
                );
              }
              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ReportTableCard(
                      child: isMobile
                          ? _BestSellersMobileList(records: records)
                          : _BestSellersTable(records: records),
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
        Text('En Çok Satanlar',
            style: Theme.of(context).textTheme.titleLarge),
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
        SizedBox(width: 150, child: _buildMinPriceField()),
      ],
    );
  }

  // ── Mobil kontrol satırı ───────────────────────────────────────────────────
  Widget _buildMobileControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('En Çok Satanlar',
            style: Theme.of(context).textTheme.titleLarge),
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
        const SizedBox(height: AppSizes.space8),
        _buildMinPriceField(),
      ],
    );
  }

  // ── Min. fiyat alanı ───────────────────────────────────────────────────────
  Widget _buildMinPriceField() {
    return TextField(
      controller: _minPriceCtrl,
      onChanged: _onMinPriceChanged,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
      ],
      style: const TextStyle(
        fontSize: 13,
        fontFeatures: [FontFeature.tabularFigures()],
      ),
      decoration: InputDecoration(
        labelText: 'Min. Fiyat',
        prefixText: '₺ ',
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

// ── Masaüstü tablo ─────────────────────────────────────────────────────────

class _BestSellersTable extends StatelessWidget {
  final List<BestSellerRecord> records;
  const _BestSellersTable({required this.records});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(AppColors.tableHeader),
        columns: const [
          DataColumn(label: Text('#')),
          DataColumn(label: Text('Ürün')),
          DataColumn(label: Text('Birim Fiyat'), numeric: true),
          DataColumn(label: Text('Adet'), numeric: true),
          DataColumn(label: Text('Son Satış Tarihi')),
        ],
        rows: List.generate(records.length, (i) {
          final r = records[i];
          final hasBarcode = r.barcode != null && r.barcode!.isNotEmpty;
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
              formatCurrency(r.price1),
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            )),
            DataCell(Text(
              formatNumber(r.quantity),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            )),
            DataCell(Text(
              formatDate(r.lastSaleDate),
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            )),
          ]);
        }),
      ),
    );
  }
}

// ── Mobil kart listesi ─────────────────────────────────────────────────────

class _BestSellersMobileList extends StatelessWidget {
  final List<BestSellerRecord> records;
  const _BestSellersMobileList({required this.records});

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
              // Ürün adı + barkod + son satış
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
                    const SizedBox(height: AppSizes.space2),
                    Text(
                      [
                        if (hasBarcode) r.barcode!,
                        'Son: ${formatDate(r.lastSaleDate)}',
                      ].join('  ·  '),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSizes.space8),
              // Sağ: birim fiyat + adet
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${formatNumber(r.quantity)} adet',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: AppSizes.space2),
                  Text(
                    formatCurrency(r.price1),
                    style: const TextStyle(
                      fontSize: 12,
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
