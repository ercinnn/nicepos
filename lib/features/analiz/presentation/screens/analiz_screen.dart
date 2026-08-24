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
import '../../../reports/application/reports_provider.dart';
import '../../../reports/data/models/product_sale_record.dart';
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

class _AnalizScreenState extends ConsumerState<AnalizScreen> {
  final _barcodeCtrl = TextEditingController();
  final _barcodeFocus = FocusNode();

  Product? _product;
  bool _looking = false;
  String? _error;

  DateTime _start = DateTime.now().subtract(const Duration(days: 29));
  DateTime _end = DateTime.now();

  @override
  void dispose() {
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
        _BarcodeRow(
          controller: _barcodeCtrl,
          focusNode: _barcodeFocus,
          looking: _looking,
          isMobile: isMobile,
          onSubmit: () => _lookup(),
          onScan: kIsWeb ? null : _scanCamera,
        ),
        if (_error != null) ...[
          const SizedBox(height: AppSizes.space12),
          _ErrorBanner(_error!),
        ],
        const SizedBox(height: AppSizes.space16),
        Expanded(
          child: _product == null
              ? const Center(
                  child: Text(
                    'Bir ürün barkodu okutun veya yazın — satış adedi grafiği burada görünür.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textMuted, fontSize: 14),
                  ),
                )
              : _AnalizContent(
                  key: ValueKey(_product!.id),
                  product: _product!,
                  start: _start,
                  end: _end,
                  isMobile: isMobile,
                  onPickStart: _pickStart,
                  onPickEnd: _pickEnd,
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

  const _BarcodeRow({
    required this.controller,
    required this.focusNode,
    required this.looking,
    required this.isMobile,
    required this.onSubmit,
    required this.onScan,
  });

  @override
  Widget build(BuildContext context) {
    final field = TextField(
      controller: controller,
      focusNode: focusNode,
      autofocus: !isMobile,
      onSubmitted: (_) => onSubmit(),
      decoration: InputDecoration(
        hintText: 'Barkod okutun veya yazın...',
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
            data: (records) => _ChartCard(records: records, start: start, end: end),
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
  final List<ProductSaleRecord> records;
  final DateTime start;
  final DateTime end;

  const _ChartCard({required this.records, required this.start, required this.end});

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
                : _QuantityBarChart(points: points, bucket: bucket),
          ),
        ],
      ),
    );
  }
}

class _QuantityBarChart extends StatelessWidget {
  final List<_ChartPoint> points;
  final _Bucket bucket;

  const _QuantityBarChart({required this.points, required this.bucket});

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
