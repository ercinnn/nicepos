import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/responsive.dart';
import '../../../customers/data/models/customer_payment.dart';
import '../../../sales/data/models/sale.dart';
import '../../../sales/data/repositories/sales_repository.dart';
import '../../../sales/presentation/screens/sale_edit_screen.dart';
import '../../application/reports_provider.dart';
import 'daily_report_screen.dart';

class HistoricalReportTab extends ConsumerStatefulWidget {
  const HistoricalReportTab({super.key});

  @override
  ConsumerState<HistoricalReportTab> createState() => _HistoricalReportTabState();
}

class _HistoricalReportTabState extends ConsumerState<HistoricalReportTab> {
  DateTime _start = DateTime.now().subtract(const Duration(days: 29));
  DateTime _end = DateTime.now();
  DateRangeParam? _activeParam;

  Future<void> _openSaleEdit(Sale s) async {
    final items = await SalesRepository().fetchItems(s.id);
    if (!mounted) return;
    final updated = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => SaleEditScreen(sale: s, initialItems: items),
    );
    if (updated == true && _activeParam != null) {
      ref.invalidate(dateRangeReportProvider(_activeParam!));
    }
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
        // ── Başlık + Tarih Seçiciler ────────────────────────────────────────
        if (isMobile)
          // Mobil: başlık ve butonlar dikey sıralanır, taşma olmaz
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tarihsel Rapor',
                style: Theme.of(context).textTheme.titleLarge,
              ),
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
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: const Icon(Icons.bar_chart, size: 16),
                  label: const Text('Rapor Getir'),
                  onPressed: () {
                    final start = _start.isBefore(_end) ? _start : _end;
                    final end = _start.isBefore(_end) ? _end : _start;
                    setState(() => _activeParam = DateRangeParam(start, end));
                  },
                ),
              ),
            ],
          )
        else
          // Masaüstü: yan yana tek satır
          Row(
            children: [
              Text(
                'Tarihsel Rapor',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Spacer(),
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today, size: 16),
                label: Text('Başlangıç: ${formatDate(_start)}'),
                onPressed: _pickStart,
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward, size: 16, color: AppColors.textMuted),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today, size: 16),
                label: Text('Bitiş: ${formatDate(_end)}'),
                onPressed: _pickEnd,
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                icon: const Icon(Icons.bar_chart, size: 16),
                label: const Text('Rapor Getir'),
                onPressed: () {
                  final start = _start.isBefore(_end) ? _start : _end;
                  final end = _start.isBefore(_end) ? _end : _start;
                  setState(() => _activeParam = DateRangeParam(start, end));
                },
              ),
            ],
          ),
        const SizedBox(height: AppSizes.space16),
        if (_activeParam == null)
          const Expanded(
            child: Center(
              child: Text(
                'Tarih aralığı seçip "Rapor Getir" butonuna tıklayın.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 15),
              ),
            ),
          )
        else
          Expanded(
            child: _DateRangeContent(
              param: _activeParam!,
              onSaleTap: _openSaleEdit,
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _DateRangeContent extends ConsumerWidget {
  final DateRangeParam param;
  final Future<void> Function(Sale) onSaleTap;
  const _DateRangeContent({required this.param, required this.onSaleTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportAsync = ref.watch(dateRangeReportProvider(param));
    return reportAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Hata: $e')),
      data: (report) => SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // İmza: aralığın TEK kahramanı — Toplam Ciro.
            ReportHero(amount: report.grandTotal),
            const SizedBox(height: AppSizes.space16),
            ReportSummaryRow(report: report),
            const SizedBox(height: AppSizes.space24),
            ReportSectionHeader(
              title: 'Satışlar',
              badge: '${report.sales.length}',
            ),
            const SizedBox(height: AppSizes.space8),
            report.sales.isEmpty
                ? const ReportEmptyCard('Bu tarih aralığında satış bulunamadı.')
                : ReportTableCard(
                    child: _HistoricalSalesTable(
                        sales: report.sales, onRowTap: onSaleTap)),
            const SizedBox(height: AppSizes.space24),
            ReportSectionHeader(
              title: 'Alınan Ödemeler',
              badge: '${report.receivedPayments.length}',
              color: AppColors.success,
            ),
            const SizedBox(height: AppSizes.space8),
            report.receivedPayments.isEmpty
                ? const ReportEmptyCard('Bu tarih aralığında ödeme bulunamadı.')
                : ReportTableCard(
                    child: _HistoricalPaymentsTable(
                        payments: report.receivedPayments)),
            const SizedBox(height: AppSizes.space24),
          ],
        ),
      ),
    );
  }
}

// ── Tarihsel Satışlar Tablosu (Tarih sütunu olan versiyon) ───────────────────

class _HistoricalSalesTable extends StatelessWidget {
  final List<Sale> sales;
  final Future<void> Function(Sale) onRowTap;
  const _HistoricalSalesTable({required this.sales, required this.onRowTap});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(AppColors.tableHeader),
        columns: const [
          DataColumn(label: Text('#')),
          DataColumn(label: Text('Tarih')),
          DataColumn(label: Text('Satış Kodu')),
          DataColumn(label: Text('Müşteri')),
          DataColumn(label: Text('Ürün')),
          DataColumn(label: Text('İskonto')),
          DataColumn(label: Text('Ödeme')),
          DataColumn(label: Text('Toplam'), numeric: true),
          DataColumn(label: Text('Not')),
        ],
        rows: [
          ...List.generate(sales.length, (i) {
            final s = sales[i];
            return DataRow(
              onSelectChanged: (_) => onRowTap(s),
              cells: [
                DataCell(Text(
                  '${i + 1}',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                )),
                DataCell(Text(
                  formatDateTime(s.saleDate),
                  style: const TextStyle(
                    fontSize: 12,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                )),
                DataCell(Text(
                  s.saleCode,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: AppColors.primary,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                )),
                DataCell(Text(
                  s.customerName ?? 'Perakende',
                  style: TextStyle(
                    color: s.customerName != null ? AppColors.textPrimary : AppColors.textMuted,
                    fontStyle: s.customerName == null ? FontStyle.italic : null,
                  ),
                )),
                DataCell(Text(
                  '${s.totalProducts} adet',
                  style: const TextStyle(
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                )),
                DataCell(Text(
                  s.discountPercent > 0 ? '%${s.discountPercent}' : '-',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                )),
                DataCell(ReportPaymentBadge(type: s.paymentType)),
                DataCell(Text(
                  formatCurrency(s.totalAmount),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                )),
                DataCell(SizedBox(
                  width: 120,
                  child: Text(
                    s.note ?? '-',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                )),
              ],
            );
          }),
          DataRow(
            color: WidgetStateProperty.all(AppColors.tableHeader),
            cells: [
              const DataCell(Text('')),
              const DataCell(Text('')),
              const DataCell(Text('')),
              DataCell(Text(
                'TOPLAM (${sales.length} satış)',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              )),
              DataCell(Text(
                '${sales.fold<int>(0, (s, e) => s + e.totalProducts)} adet',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              )),
              const DataCell(Text('')),
              const DataCell(Text('')),
              DataCell(Text(
                formatCurrency(sales.fold<num>(0, (s, e) => s + e.totalAmount)),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              )),
              const DataCell(Text('')),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Tarihsel Ödemeler Tablosu ─────────────────────────────────────────────────

class _HistoricalPaymentsTable extends StatelessWidget {
  final List<CustomerPayment> payments;
  const _HistoricalPaymentsTable({required this.payments});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(AppColors.tableHeader),
        columns: const [
          DataColumn(label: Text('#')),
          DataColumn(label: Text('Tarih')),
          DataColumn(label: Text('Müşteri')),
          DataColumn(label: Text('Tutar'), numeric: true),
          DataColumn(label: Text('Not')),
        ],
        rows: [
          ...List.generate(payments.length, (i) {
            final p = payments[i];
            return DataRow(cells: [
              DataCell(Text('${i + 1}',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ))),
              DataCell(Text(
                formatDateTime(p.paymentDate),
                style: const TextStyle(
                  fontSize: 12,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              )),
              DataCell(Text(p.customerName ?? '-')),
              DataCell(Text(
                formatCurrency(p.amount),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.success,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              )),
              DataCell(SizedBox(
                width: 200,
                child: Text(
                  p.note ?? '-',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              )),
            ]);
          }),
          DataRow(
            color: WidgetStateProperty.all(AppColors.tableHeader),
            cells: [
              const DataCell(Text('')),
              const DataCell(Text('')),
              DataCell(Text(
                'TOPLAM (${payments.length} ödeme)',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              )),
              DataCell(Text(
                formatCurrency(payments.fold<num>(0, (s, p) => s + p.amount)),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.success,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              )),
              const DataCell(Text('')),
            ],
          ),
        ],
      ),
    );
  }
}
