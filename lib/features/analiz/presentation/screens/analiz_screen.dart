import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/responsive.dart';
import '../../../products/application/products_provider.dart';
import '../../../products/data/models/product.dart';
import '../../../products/presentation/widgets/live_product_search_field.dart';
import '../../../reports/application/reports_provider.dart';
import '../../../reports/data/models/discount_recommendation.dart';
import '../../../reports/data/models/product_sale_record.dart';
import '../../../sales/data/models/sale.dart';
import '../../../sales/data/repositories/sales_repository.dart';
import '../../../sales/presentation/screens/sale_edit_screen.dart';
import '../../../sales/presentation/widgets/barcode_scanner_modal.dart';

/// Analiz sayfası: bir barkod okutup (mobilde kamera, web'de barkod
/// okuyucu/elle yazım + Enter) o ürünün seçili tarih aralığındaki günlük
/// satış adedini grafik olarak gösterir. `productSalesHistoryProvider`
/// (Ürün Raporları sekmesiyle PAYLAŞILAN provider, ürünün TÜM satış
/// geçmişini bir kerede getirir) istemci tarafında tarih aralığına göre
/// süzülüp güne/haftaya/aya gruplanır — aralık değişince yeniden fetch
/// TETİKLENMEZ.
class AnalizScreen extends ConsumerStatefulWidget {
  const AnalizScreen({super.key});

  @override
  ConsumerState<AnalizScreen> createState() => _AnalizScreenState();
}

class _AnalizScreenState extends ConsumerState<AnalizScreen>
    with SingleTickerProviderStateMixin {
  late final _tabController = TabController(length: 2, vsync: this);

  final _barcodeCtrl = TextEditingController();
  final _barcodeFocus = FocusNode();

  Product? _product;
  bool _looking = false;
  String? _error;

  DateTime _start = DateTime.now().subtract(const Duration(days: 29));
  DateTime _end = DateTime.now();

  @override
  void dispose() {
    _tabController.dispose();
    _barcodeCtrl.dispose();
    _barcodeFocus.dispose();
    super.dispose();
  }

  Future<void> _lookup([String? code]) async {
    final barcode = (code ?? _barcodeCtrl.text).trim();
    if (barcode.isEmpty) return;
    setState(() {
      _looking = true;
      _error = null;
    });
    try {
      final product =
          await ref.read(productRepositoryProvider).fetchByBarcode(barcode);
      if (!mounted) return;
      setState(() {
        _looking = false;
        _product = product;
        _error = product == null ? 'Bu barkodla eşleşen ürün bulunamadı.' : null;
      });
      if (product != null) {
        ref.invalidate(productSalesHistoryProvider(product.id));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _looking = false;
        _error = 'Hata: $e';
      });
    } finally {
      _barcodeCtrl.clear();
      _barcodeFocus.requestFocus();
    }
  }

  // Canlı arama açılır listesinden bir ürüne dokununca çağrılır — barkod
  // ile aynı sonucu (ürünü seçip grafiği yükle) ağ turu beklemeden verir,
  // çünkü ürün nesnesi zaten arama sonucundan elde.
  void _selectProduct(Product product) {
    setState(() {
      _looking = false;
      _product = product;
      _error = null;
    });
    ref.invalidate(productSalesHistoryProvider(product.id));
    _barcodeCtrl.clear();
    _barcodeFocus.requestFocus();
  }

  // İndirim Önerileri sekmesinde bir karta dokununca 1. sekmeye geçip o
  // ürünün grafiğini yükler (barkod üzerinden — öneri satırı zaten Product
  // nesnesini değil yalnız özet alanları taşıyor).
  void _openFromRecommendation(DiscountRecommendation rec) {
    _tabController.animateTo(0);
    if (rec.barcode != null && rec.barcode!.isNotEmpty) {
      _lookup(rec.barcode);
    }
  }

  Future<void> _scanCamera() async {
    await openBarcodeScanner(context, (value) {
      _lookup(value);
    });
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Analiz', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSizes.space12),
        TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textMuted,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: 'Ürün Analizi'),
            Tab(text: 'İndirim Önerileri'),
          ],
        ),
        const SizedBox(height: AppSizes.space12),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _ProductAnalysisTab(
                barcodeCtrl: _barcodeCtrl,
                barcodeFocus: _barcodeFocus,
                looking: _looking,
                error: _error,
                product: _product,
                start: _start,
                end: _end,
                isMobile: isMobile,
                onSubmit: () => _lookup(),
                onScan: kIsWeb ? null : _scanCamera,
                onProductSelected: _selectProduct,
                onPickStart: _pickStart,
                onPickEnd: _pickEnd,
              ),
              _DiscountRecommendationsTab(
                onOpenProduct: _openFromRecommendation,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── 1. sekme: mevcut barkod ara + ürün grafiği akışı (davranış DEĞİŞMEDİ) ───

class _ProductAnalysisTab extends StatelessWidget {
  final TextEditingController barcodeCtrl;
  final FocusNode barcodeFocus;
  final bool looking;
  final String? error;
  final Product? product;
  final DateTime start;
  final DateTime end;
  final bool isMobile;
  final VoidCallback onSubmit;
  final VoidCallback? onScan;
  final void Function(Product) onProductSelected;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;

  const _ProductAnalysisTab({
    required this.barcodeCtrl,
    required this.barcodeFocus,
    required this.looking,
    required this.error,
    required this.product,
    required this.start,
    required this.end,
    required this.isMobile,
    required this.onSubmit,
    required this.onScan,
    required this.onProductSelected,
    required this.onPickStart,
    required this.onPickEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _BarcodeRow(
          controller: barcodeCtrl,
          focusNode: barcodeFocus,
          looking: looking,
          isMobile: isMobile,
          onSubmit: onSubmit,
          onScan: onScan,
          onProductSelected: onProductSelected,
        ),
        if (error != null) ...[
          const SizedBox(height: AppSizes.space12),
          _ErrorBanner(error!),
        ],
        const SizedBox(height: AppSizes.space16),
        Expanded(
          child: product == null
              ? const Center(
                  child: Text(
                    'Bir ürün barkodu okutun veya yazın — satış adedi grafiği burada görünür.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textMuted, fontSize: 14),
                  ),
                )
              : _AnalizContent(
                  key: ValueKey(product!.id),
                  product: product!,
                  start: start,
                  end: end,
                  isMobile: isMobile,
                  onPickStart: onPickStart,
                  onPickEnd: onPickEnd,
                ),
        ),
      ],
    );
  }
}

// ── Barkod satırı (masaüstü/web: yaz+Enter · mobil: + Kamera ile Tara) ──────

class _BarcodeRow extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool looking;
  final bool isMobile;
  final VoidCallback onSubmit;
  final VoidCallback? onScan;
  final void Function(Product) onProductSelected;

  const _BarcodeRow({
    required this.controller,
    required this.focusNode,
    required this.looking,
    required this.isMobile,
    required this.onSubmit,
    required this.onScan,
    required this.onProductSelected,
  });

  @override
  Widget build(BuildContext context) {
    final field = LiveProductSearchField(
      controller: controller,
      focusNode: focusNode,
      autofocus: !isMobile,
      onSubmitted: (_) async => onSubmit(),
      onProductSelected: onProductSelected,
      decoration: InputDecoration(
        hintText: 'Barkod okutun veya ürün adı yazın...',
        prefixIcon: looking
            ? const Padding(
                padding: EdgeInsets.all(14),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : const Icon(Icons.qr_code_scanner, size: 18, color: AppColors.textMuted),
        filled: true,
        fillColor: AppColors.pageBg,
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
        isDense: true,
      ),
    );

    final araButton = FilledButton.icon(
      icon: const Icon(Icons.search, size: 16),
      label: const Text('Ara'),
      onPressed: onSubmit,
    );

    final kameraButton = onScan == null
        ? null
        : OutlinedButton.icon(
            icon: const Icon(Icons.camera_alt_outlined, size: 16),
            label: const Text('Kamera ile Tara'),
            onPressed: onScan,
          );

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: field),
              const SizedBox(width: AppSizes.space8),
              araButton,
            ],
          ),
          if (kameraButton != null) ...[
            const SizedBox(height: AppSizes.space8),
            SizedBox(width: double.infinity, child: kameraButton),
          ],
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: field,
          ),
        ),
        const SizedBox(width: AppSizes.space8),
        araButton,
        if (kameraButton != null) ...[
          const SizedBox(width: AppSizes.space8),
          kameraButton,
        ],
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner(this.message);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.space12,
        vertical: AppSizes.space8,
      ),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 16, color: AppColors.danger),
          const SizedBox(width: AppSizes.space8),
          Expanded(
            child: Text(message, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

// ── Ürün bulununca: bilgi kartı + tarih aralığı + grafik ────────────────────

class _AnalizContent extends ConsumerWidget {
  final Product product;
  final DateTime start;
  final DateTime end;
  final bool isMobile;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;

  const _AnalizContent({
    super.key,
    required this.product,
    required this.start,
    required this.end,
    required this.isMobile,
    required this.onPickStart,
    required this.onPickEnd,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(productSalesHistoryProvider(product.id));

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ProductCard(product: product),
          const SizedBox(height: AppSizes.space16),
          _DateRangeRow(
            start: start,
            end: end,
            isMobile: isMobile,
            onPickStart: onPickStart,
            onPickEnd: onPickEnd,
          ),
          const SizedBox(height: AppSizes.space16),
          historyAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSizes.space32),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSizes.space32),
              child: Center(child: Text('Hata: $e')),
            ),
            data: (records) => _ChartCard(
              productId: product.id,
              records: records,
              start: start,
              end: end,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Product product;
  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppSizes.cardDecoration(),
      padding: const EdgeInsets.all(AppSizes.space12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppSizes.radiusSm),
            ),
            child: const Icon(Icons.inventory_2_outlined, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: AppSizes.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  [
                    if (product.barcode != null) 'Barkod: ${product.barcode}',
                    if (product.groupName != null) product.groupName!,
                    'Stok: ${formatNumber(product.stockQuantity)}',
                  ].join('  ·  '),
                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSizes.space12),
          Text(
            formatCurrency(product.price1),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _DateRangeRow extends StatelessWidget {
  final DateTime start;
  final DateTime end;
  final bool isMobile;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;

  const _DateRangeRow({
    required this.start,
    required this.end,
    required this.isMobile,
    required this.onPickStart,
    required this.onPickEnd,
  });

  @override
  Widget build(BuildContext context) {
    final startBtn = OutlinedButton.icon(
      icon: const Icon(Icons.calendar_today, size: 14),
      label: Text(formatDate(start), style: const TextStyle(fontSize: 12)),
      onPressed: onPickStart,
    );
    final endBtn = OutlinedButton.icon(
      icon: const Icon(Icons.calendar_today, size: 14),
      label: Text(formatDate(end), style: const TextStyle(fontSize: 12)),
      onPressed: onPickEnd,
    );
    final arrow = const Padding(
      padding: EdgeInsets.symmetric(horizontal: 8),
      child: Icon(Icons.arrow_forward, size: 14, color: AppColors.textMuted),
    );

    if (isMobile) {
      return Row(
        children: [
          Expanded(child: startBtn),
          arrow,
          Expanded(child: endBtn),
        ],
      );
    }
    return Row(
      children: [startBtn, arrow, endBtn],
    );
  }
}

// ── Grafik: tarih aralığına göre gün/hafta/ay bazında toplam adet ──────────

enum _Bucket { day, week, month }

_Bucket _pickBucket(int periodDays) {
  if (periodDays <= 45) return _Bucket.day;
  if (periodDays <= 180) return _Bucket.week;
  return _Bucket.month;
}

DateTime _bucketKey(DateTime d, _Bucket b) {
  switch (b) {
    case _Bucket.day:
      return DateTime(d.year, d.month, d.day);
    case _Bucket.week:
      final monday = d.subtract(Duration(days: d.weekday - 1));
      return DateTime(monday.year, monday.month, monday.day);
    case _Bucket.month:
      return DateTime(d.year, d.month, 1);
  }
}

DateTime _bucketNext(DateTime key, _Bucket b) {
  switch (b) {
    case _Bucket.day:
      return key.add(const Duration(days: 1));
    case _Bucket.week:
      return key.add(const Duration(days: 7));
    case _Bucket.month:
      return DateTime(key.year, key.month + 1, 1);
  }
}

String _bucketLabel(DateTime key, _Bucket b) {
  switch (b) {
    case _Bucket.day:
    case _Bucket.week:
      return DateFormat('dd.MM', 'tr_TR').format(key);
    case _Bucket.month:
      return DateFormat('MMM yy', 'tr_TR').format(key);
  }
}

class _ChartPoint {
  final DateTime date;
  final num quantity;
  const _ChartPoint(this.date, this.quantity);
}

class _ChartCard extends StatelessWidget {
  final String productId;
  final List<ProductSaleRecord> records;
  final DateTime start;
  final DateTime end;

  const _ChartCard({
    required this.productId,
    required this.records,
    required this.start,
    required this.end,
  });

  @override
  Widget build(BuildContext context) {
    final startDay = DateTime(start.year, start.month, start.day);
    final endDay = DateTime(end.year, end.month, end.day);
    final normalizedStart = startDay.isBefore(endDay) ? startDay : endDay;
    final normalizedEnd = startDay.isBefore(endDay) ? endDay : startDay;
    final periodDays = normalizedEnd.difference(normalizedStart).inDays + 1;
    final bucket = _pickBucket(periodDays);

    final inRange = records.where((r) {
      final d = DateTime(r.saleDate.year, r.saleDate.month, r.saleDate.day);
      return !d.isBefore(normalizedStart) && !d.isAfter(normalizedEnd);
    }).toList();

    final totalsByBucket = <DateTime, num>{};
    for (final r in inRange) {
      final key = _bucketKey(r.saleDate, bucket);
      totalsByBucket[key] = (totalsByBucket[key] ?? 0) + r.quantity;
    }

    final points = <_ChartPoint>[];
    var cursor = _bucketKey(normalizedStart, bucket);
    final limit = _bucketKey(normalizedEnd, bucket);
    while (!cursor.isAfter(limit)) {
      points.add(_ChartPoint(cursor, totalsByBucket[cursor] ?? 0));
      cursor = _bucketNext(cursor, bucket);
    }

    final totalQty = inRange.fold<num>(0, (a, r) => a + r.quantity);
    final totalAmount = inRange.fold<num>(0, (a, r) => a + r.total);

    // Bir çubuğa dokununca o çubuğun temsil ettiği dönemdeki (gün/hafta/ay)
    // satışları listeleyen diyaloğu açar — bkz. `_BucketSalesDialog`.
    void onBarTap(int index) {
      if (index < 0 || index >= points.length) return;
      final bucketStart = points[index].date;
      final bucketRecords = inRange
          .where((r) => _bucketKey(r.saleDate, bucket) == bucketStart)
          .toList()
        ..sort((a, b) => a.saleDate.compareTo(b.saleDate));
      if (bucketRecords.isEmpty) return;
      showDialog<void>(
        context: context,
        builder: (_) => _BucketSalesDialog(
          productId: productId,
          records: bucketRecords,
          bucketStart: bucketStart,
          bucket: bucket,
        ),
      );
    }

    return Container(
      decoration: AppSizes.cardDecoration(),
      padding: const EdgeInsets.all(AppSizes.space12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSizes.space8,
            runSpacing: AppSizes.space8,
            children: [
              _StatChip('Satılan Adet', formatNumber(totalQty), AppColors.primary),
              _StatChip('Ciro', formatCurrency(totalAmount), AppColors.success),
              _StatChip('İşlem Sayısı', '${inRange.length}', AppColors.textSecondary),
            ],
          ),
          const SizedBox(height: AppSizes.space16),
          SizedBox(
            height: 260,
            child: totalQty == 0
                ? const Center(
                    child: Text(
                      'Seçili aralıkta satış yok',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  )
                : _QuantityBarChart(points: points, bucket: bucket, onBarTap: onBarTap),
          ),
        ],
      ),
    );
  }
}

class _QuantityBarChart extends StatelessWidget {
  final List<_ChartPoint> points;
  final _Bucket bucket;
  final void Function(int index) onBarTap;

  const _QuantityBarChart({
    required this.points,
    required this.bucket,
    required this.onBarTap,
  });

  @override
  Widget build(BuildContext context) {
    final maxY = points.map((p) => p.quantity.toDouble()).fold(0.0, (a, b) => a > b ? a : b);
    final yMax = maxY == 0 ? 5.0 : maxY * 1.25;
    final step = (points.length / 8).ceil().clamp(1, points.length);
    final barWidth = points.length > 40 ? 4.0 : (points.length > 20 ? 8.0 : 16.0);

    return BarChart(
      BarChartData(
        maxY: yMax,
        alignment: BarChartAlignment.spaceAround,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: yMax / 4,
          getDrawingHorizontalLine: (_) => FlLine(
            color: AppColors.border,
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: const Border(
            bottom: BorderSide(color: AppColors.border),
            left: BorderSide(color: AppColors.border),
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              interval: yMax / 4,
              getTitlesWidget: (val, meta) {
                if (val == 0) return const SizedBox.shrink();
                return Text(
                  val.toStringAsFixed(0),
                  style: const TextStyle(fontSize: 9, color: AppColors.textMuted),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 26,
              interval: step.toDouble(),
              getTitlesWidget: (val, meta) {
                final idx = val.round();
                if (idx < 0 || idx >= points.length || idx % step != 0) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    _bucketLabel(points[idx].date, bucket),
                    style: const TextStyle(fontSize: 9, color: AppColors.textMuted),
                  ),
                );
              },
            ),
          ),
        ),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => AppColors.primary,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final p = points[group.x.toInt()];
              return BarTooltipItem(
                '${_bucketLabel(p.date, bucket)}\n${formatNumber(p.quantity)} adet',
                const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              );
            },
          ),
          // Bir çubuğa dokununca (parmak/tık kalkışında) o dönemin satışlarını
          // listeleyen diyaloğu açar — bkz. `_ChartCard.onBarTap`.
          touchCallback: (event, response) {
            if (event is! FlTapUpEvent) return;
            final spot = response?.spot;
            if (spot == null) return;
            onBarTap(spot.touchedBarGroupIndex);
          },
        ),
        barGroups: [
          for (var i = 0; i < points.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: points[i].quantity.toDouble(),
                  color: AppColors.primary,
                  width: barWidth,
                  borderRadius: BorderRadius.circular(3),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

// ── Bir çubuğa (gün/hafta/ay) ait satışları listeleyen diyalog ─────────────
// Saat/Satış Kodu/Müşteri/Ürün/İskonto/Ödeme/Toplam/Not sütunları — İskonto/
// Ödeme/Not SATIŞ seviyesi alanlardır (bkz. `ProductSaleRecord` genişletmesi,
// `report_repository.dart` `fetchProductSalesHistory`). Satış Kodu'na
// dokunmak `SaleEditScreen`'i AYRI bir `showDialog` olarak açar — bu
// diyaloğun ÜSTÜNE biner, kapatılınca alttaki liste ekranda KALIR (kullanıcı
// isteği: "ilk diyalog penceresindeki diğer satışlar ekranda kalsın").
// Değişiklik yapılırsa (silme/düzenleme) liste bayat kalmasın diye sunucudan
// taze veriyle güncellenir — diyalog KAPANMADAN.
class _BucketSalesDialog extends ConsumerStatefulWidget {
  final String productId;
  final List<ProductSaleRecord> records;
  final DateTime bucketStart;
  final _Bucket bucket;

  const _BucketSalesDialog({
    required this.productId,
    required this.records,
    required this.bucketStart,
    required this.bucket,
  });

  @override
  ConsumerState<_BucketSalesDialog> createState() =>
      _BucketSalesDialogState();
}

class _BucketSalesDialogState extends ConsumerState<_BucketSalesDialog> {
  late List<ProductSaleRecord> _records;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _records = widget.records;
  }

  String get _title {
    switch (widget.bucket) {
      case _Bucket.day:
        return DateFormat('d MMMM yyyy', 'tr_TR').format(widget.bucketStart);
      case _Bucket.week:
        final end = widget.bucketStart.add(const Duration(days: 6));
        return '${DateFormat('d MMM', 'tr_TR').format(widget.bucketStart)} – '
            '${DateFormat('d MMM yyyy', 'tr_TR').format(end)}';
      case _Bucket.month:
        return DateFormat('MMMM yyyy', 'tr_TR').format(widget.bucketStart);
    }
  }

  String _discountLabel(ProductSaleRecord r) {
    if (r.discountType == 'percent') {
      if (r.discountPercent <= 0) return '—';
      return '%${formatNumber(r.discountPercent)}';
    }
    if (r.discountAmount <= 0) return '—';
    return formatCurrency(r.discountAmount);
  }

  Future<void> _openSaleEdit(ProductSaleRecord r) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final repo = SalesRepository();
      final sale = await repo.fetchSaleById(r.saleId);
      final items = await repo.fetchItems(r.saleId);
      if (!mounted) return;
      final result = await showDialog<SaleEditResult>(
        context: context,
        barrierDismissible: false,
        builder: (_) => SaleEditScreen(sale: sale, initialItems: items),
      );
      if (!mounted) return;
      if (result?.changed == true) {
        ref.invalidate(productSalesHistoryProvider(widget.productId));
        final fresh = await ref
            .read(productSalesHistoryProvider(widget.productId).future);
        if (!mounted) return;
        setState(() {
          _records = fresh
              .where((x) =>
                  _bucketKey(x.saleDate, widget.bucket) == widget.bucketStart)
              .toList()
            ..sort((a, b) => a.saleDate.compareTo(b.saleDate));
        });
      }
      if (result?.message != null && mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(result!.message!)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Satış açılamadı: $e'),
              backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760, maxHeight: 560),
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.space16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _title,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (_busy)
                    const Padding(
                      padding: EdgeInsets.all(8),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  else
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                ],
              ),
              Text(
                '${_records.length} satış',
                style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
              const SizedBox(height: AppSizes.space12),
              Flexible(
                child: _records.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: AppSizes.space24),
                        child: Center(
                          child: Text('Bu dönemde satış kalmadı.',
                              style: TextStyle(color: AppColors.textMuted)),
                        ),
                      )
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowColor:
                              WidgetStateProperty.all(AppColors.tableHeader),
                          columns: const [
                            DataColumn(label: Text('Saat')),
                            DataColumn(label: Text('Satış Kodu')),
                            DataColumn(label: Text('Müşteri')),
                            DataColumn(label: Text('Ürün')),
                            DataColumn(label: Text('İskonto')),
                            DataColumn(label: Text('Ödeme')),
                            DataColumn(label: Text('Toplam'), numeric: true),
                            DataColumn(label: Text('Not')),
                          ],
                          rows: [
                            for (final r in _records)
                              DataRow(cells: [
                                DataCell(
                                    Text(DateFormat('HH:mm').format(r.saleDate))),
                                DataCell(
                                  InkWell(
                                    onTap: () => _openSaleEdit(r),
                                    child: Text(
                                      r.saleCode,
                                      style: const TextStyle(
                                        color: AppColors.primary,
                                        decoration: TextDecoration.underline,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                                DataCell(Text(r.customerName ?? 'Perakende')),
                                DataCell(Text(
                                    '${formatNumber(r.quantity)} × ${formatCurrency(r.unitPrice)}')),
                                DataCell(Text(_discountLabel(r))),
                                DataCell(Text(r.paymentType.label)),
                                DataCell(Text(formatCurrency(r.saleTotalAmount))),
                                DataCell(
                                  ConstrainedBox(
                                    constraints:
                                        const BoxConstraints(maxWidth: 160),
                                    child: Text(
                                      r.note?.isNotEmpty == true ? r.note! : '—',
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                ),
                              ]),
                          ],
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

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatChip(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.space12,
        vertical: AppSizes.space8,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
          const SizedBox(height: AppSizes.space4),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

// ── 2. sekme: İndirim Önerileri ─────────────────────────────────────────────
// `discount_recommendations` RPC'sinin (0051 migration) döndürdüğü, veri-
// temelli (fiyat esnekliği regresyonu) ciro-artırıcı öneri listesi — bkz.
// migration dosyasındaki metodoloji notu. v1'in (0050) aksine eşiği geçemeyen
// ürünler ELENMEZ — `status` ile etiketlenip "Diğer Ürünler" bölümünde
// gerekçesiyle görünür, hiçbir ürün sessizce kaybolmaz.
class _DiscountRecommendationsTab extends ConsumerWidget {
  final void Function(DiscountRecommendation) onOpenProduct;

  const _DiscountRecommendationsTab({required this.onOpenProduct});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(discountRecommendationsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Geçmiş satışlardaki fiyat-adet ilişkisinden hesaplanan, '
                'ciroyu artırması beklenen indirim önerileri. Tahminler '
                'istatistikseldir, kesin sonuç garanti etmez.',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ),
            const SizedBox(width: AppSizes.space8),
            IconButton(
              tooltip: 'Yenile',
              icon: const Icon(Icons.refresh, size: 20),
              onPressed: () => ref.invalidate(discountRecommendationsProvider),
            ),
          ],
        ),
        const SizedBox(height: AppSizes.space12),
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSizes.space24),
                child: Text('Hata: $e', textAlign: TextAlign.center),
              ),
            ),
            data: (recs) {
              if (recs.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(AppSizes.space24),
                    child: Text(
                      'Henüz analiz edilebilir bir satış geçmişi yok.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                    ),
                  ),
                );
              }
              final recommended = recs.where((r) => r.isRecommended).toList();
              final others = recs.where((r) => !r.isRecommended).toList();
              return ListView(
                children: [
                  if (recommended.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSizes.space24),
                      child: Center(
                        child: Text(
                          'Şu an için ciro artırması beklenen bir indirim önerisi yok.\n'
                          'Aşağıdaki "Diğer Ürünler" bölümünde nedenini görebilirsiniz.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                        ),
                      ),
                    )
                  else
                    for (final r in recommended) ...[
                      _DiscountRecommendationCard(rec: r, onTap: () => onOpenProduct(r)),
                      const SizedBox(height: AppSizes.space8),
                    ],
                  if (others.isNotEmpty) ...[
                    const SizedBox(height: AppSizes.space8),
                    _OtherProductsSection(others: others, onOpenProduct: onOpenProduct),
                  ],
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _DiscountRecommendationCard extends StatelessWidget {
  final DiscountRecommendation rec;
  final VoidCallback onTap;

  const _DiscountRecommendationCard({required this.rec, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      child: Container(
        decoration: AppSizes.cardDecoration(),
        padding: const EdgeInsets.all(AppSizes.space12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rec.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (rec.barcode != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Barkod: ${rec.barcode}',
                          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                        ),
                      ],
                    ],
                  ),
                ),
                _ConfidenceBadge(confidence: rec.confidence, source: rec.source),
              ],
            ),
            const SizedBox(height: AppSizes.space12),
            Wrap(
              spacing: AppSizes.space8,
              runSpacing: AppSizes.space8,
              children: [
                _StatChip('Önerilen İndirim', '%${rec.recommendedDiscountPercent}', AppColors.danger),
                _StatChip(
                  'Fiyat',
                  '${formatCurrency(rec.price1)} → ${formatCurrency(rec.recommendedPrice ?? 0)}',
                  AppColors.primary,
                ),
                _StatChip(
                  'Tahmini Ciro Artışı',
                  '+%${formatNumber(rec.revenueIncreasePercent ?? 0)}',
                  AppColors.success,
                ),
              ],
            ),
            const SizedBox(height: AppSizes.space8),
            Text(
              'Günlük ~${formatCurrency(rec.currentEstDailyRevenue ?? 0)} → '
              '~${formatCurrency(rec.recommendedEstDailyRevenue ?? 0)} '
              '(${rec.sampleCount} satış, R²=${(rec.rSquared ?? 0).toStringAsFixed(2)}, '
              'gözlenen fiyat aralığı ${formatCurrency(rec.historicalMinPrice)}–'
              '${formatCurrency(rec.historicalMaxPrice)})',
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Eşiği geçemeyen ürünler — elenmez, gerekçesiyle katlanır bir bölümde ───
class _OtherProductsSection extends StatelessWidget {
  final List<DiscountRecommendation> others;
  final void Function(DiscountRecommendation) onOpenProduct;

  const _OtherProductsSection({required this.others, required this.onOpenProduct});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppSizes.cardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          title: Text(
            'Diğer Ürünler (${others.length})',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          subtitle: const Text(
            'Öneri üretilemedi — gerekçesiyle',
            style: TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
          childrenPadding: const EdgeInsets.only(bottom: AppSizes.space8),
          children: [
            for (final r in others)
              _OtherProductRow(rec: r, onTap: () => onOpenProduct(r)),
          ],
        ),
      ),
    );
  }
}

class _OtherProductRow extends StatelessWidget {
  final DiscountRecommendation rec;
  final VoidCallback onTap;

  const _OtherProductRow({required this.rec, required this.onTap});

  Color get _statusColor {
    switch (rec.status) {
      case DiscountRecommendationStatus.noSafeDiscount:
        return AppColors.textSecondary;
      case DiscountRecommendationStatus.notBeneficial:
        return AppColors.danger;
      case DiscountRecommendationStatus.insufficientData:
      case DiscountRecommendationStatus.recommended:
        return AppColors.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.space16,
          vertical: AppSizes.space8,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rec.name,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    rec.reasonLabel,
                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSizes.space8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                border: Border.all(color: _statusColor.withValues(alpha: 0.3)),
              ),
              child: Text(
                switch (rec.status) {
                  DiscountRecommendationStatus.noSafeDiscount => 'Güvenli aralık yok',
                  DiscountRecommendationStatus.notBeneficial => 'Fayda yok',
                  DiscountRecommendationStatus.insufficientData => 'Yetersiz veri',
                  DiscountRecommendationStatus.recommended => '',
                },
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _statusColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfidenceBadge extends StatelessWidget {
  final String? confidence;
  final DiscountRecommendationSource source;
  const _ConfidenceBadge({required this.confidence, required this.source});

  @override
  Widget build(BuildContext context) {
    final color = switch (confidence) {
      'yuksek' => AppColors.success,
      'orta' => AppColors.primary,
      _ => AppColors.textSecondary,
    };
    final confidenceLabel = switch (confidence) {
      'yuksek' => 'Yüksek güven',
      'orta' => 'Orta güven',
      _ => 'Düşük güven',
    };
    final sourceLabel =
        source == DiscountRecommendationSource.group ? 'Kategori ortalaması' : 'Kendi verisi';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            confidenceLabel,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
          ),
          Text(
            sourceLabel,
            style: TextStyle(fontSize: 9, color: color.withValues(alpha: 0.8)),
          ),
        ],
      ),
    );
  }
}
