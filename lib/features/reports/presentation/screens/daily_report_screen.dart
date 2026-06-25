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
import '../../data/models/daily_report_summary.dart';

class DailyReportScreen extends ConsumerStatefulWidget {
  const DailyReportScreen({super.key});

  @override
  ConsumerState<DailyReportScreen> createState() => _DailyReportScreenState();
}

class _DailyReportScreenState extends ConsumerState<DailyReportScreen> {
  DateTime _date = DateTime.now();

  Future<void> _openSaleEdit(BuildContext context, Sale s) async {
    final items = await SalesRepository().fetchItems(s.id);
    if (!context.mounted) return;
    final updated = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => SaleEditScreen(sale: s, initialItems: items),
    );
    if (updated == true) {
      ref.invalidate(dailyReportProvider(DateTime(_date.year, _date.month, _date.day)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final reportAsync =
        ref.watch(dailyReportProvider(DateTime(_date.year, _date.month, _date.day)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Başlık + Tarih Seç butonu
        // Mobil: başlık ve tarih dikey, buton sağda
        // Masaüstü: tek satır yatay
        Row(
          children: [
            Expanded(
              child: context.isMobile
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Günlük Rapor',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          formatDate(_date),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        const Text(
                          'Günlük Rapor',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          formatDate(_date),
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.calendar_today, size: 16),
              label: const Text('Tarih Seç'),
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (picked != null) setState(() => _date = picked);
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: reportAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Hata: $e')),
            data: (report) => _ReportContent(
              report: report,
              onSaleTap: (s) => _openSaleEdit(context, s),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _ReportContent extends StatelessWidget {
  final DailyReportSummary report;
  final void Function(Sale) onSaleTap;
  const _ReportContent({required this.report, required this.onSaleTap});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ReportSummaryRow(report: report),
          const SizedBox(height: 24),
          ReportSectionHeader(
            title: 'Satışlar',
            badge: '${report.sales.length}',
          ),
          const SizedBox(height: 8),
          report.sales.isEmpty
              ? const ReportEmptyCard('Bu tarihte satış bulunamadı.')
              : Card(
                  child: _SalesTable(sales: report.sales, onRowTap: onSaleTap),
                ),
          const SizedBox(height: 24),
          ReportSectionHeader(
            title: 'Alınan Ödemeler',
            badge: '${report.receivedPayments.length}',
            color: AppColors.success,
          ),
          const SizedBox(height: 8),
          report.receivedPayments.isEmpty
              ? const ReportEmptyCard('Bu tarihte ödeme bulunamadı.')
              : Card(
                  child: _PaymentsTable(payments: report.receivedPayments),
                ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ── Özet Satırı (public — tarihsel rapor da kullanır) ─────────────────────────

class ReportSummaryRow extends StatelessWidget {
  final DailyReportSummary report;
  const ReportSummaryRow({super.key, required this.report});

  @override
  Widget build(BuildContext context) {
    final cards = [
      ReportStatCard(icon: Icons.payments_outlined, label: 'Nakit Tahsilat', value: formatCurrency(report.cashTotal), color: AppColors.cash),
      ReportStatCard(icon: Icons.credit_card_outlined, label: 'POS Tahsilat', value: formatCurrency(report.posTotal), color: AppColors.pos),
      ReportStatCard(icon: Icons.account_balance_wallet_outlined, label: 'Açık Hesap', value: formatCurrency(report.openAccountTotal), color: AppColors.openAccount),
      ReportStatCard(icon: Icons.bar_chart_outlined, label: 'Toplam Ciro', value: formatCurrency(report.grandTotal), color: AppColors.primary, highlight: true),
      ReportStatCard(icon: Icons.shopping_cart_outlined, label: 'Satış Adedi', value: '${report.sales.length}', color: AppColors.textSecondary),
      ReportStatCard(icon: Icons.inventory_2_outlined, label: 'Ürün Maliyeti', value: formatCurrency(report.productCost), color: AppColors.textMuted),
      ReportStatCard(icon: Icons.trending_up_outlined, label: 'Kâr', value: formatCurrency(report.profit), color: report.profit >= 0 ? AppColors.success : AppColors.danger, highlight: true),
      ReportStatCard(icon: Icons.arrow_circle_down_outlined, label: 'Alınan Ödemeler', value: formatCurrency(report.receivedPaymentsTotal), color: AppColors.success),
    ];

    if (context.isMobile) {
      return LayoutBuilder(
        builder: (_, constraints) {
          final w = constraints.maxWidth;
          final sideGap = w * 0.03;
          final centerGap = w * 0.04;
          final cardWidth = w * 0.45;

          final rows = <Widget>[];
          for (int i = 0; i < cards.length; i += 2) {
            rows.add(Row(
              children: [
                SizedBox(width: sideGap),
                SizedBox(width: cardWidth, child: cards[i]),
                SizedBox(width: centerGap),
                SizedBox(
                  width: cardWidth,
                  child: i + 1 < cards.length ? cards[i + 1] : const SizedBox(),
                ),
                SizedBox(width: sideGap),
              ],
            ));
            if (i + 2 < cards.length) rows.add(const SizedBox(height: 10));
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: rows,
          );
        },
      );
    }

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: cards.map((c) => SizedBox(width: 200, child: c)).toList(),
    );
  }
}

// ── Stat Kartı (public) ───────────────────────────────────────────────────────

class ReportStatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool highlight;

  const ReportStatCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: highlight
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.cardRadius),
              side: BorderSide(color: color.withValues(alpha: 0.4), width: 1.5),
            )
          : null,
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.cardPadding),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Bölüm Başlığı (public) ────────────────────────────────────────────────────

class ReportSectionHeader extends StatelessWidget {
  final String title;
  final String badge;
  final Color color;

  const ReportSectionHeader({
    super.key,
    required this.title,
    required this.badge,
    this.color = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            badge,
            style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

// ── Boş Kart (public) ─────────────────────────────────────────────────────────

class ReportEmptyCard extends StatelessWidget {
  final String message;
  const ReportEmptyCard(this.message, {super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: Text(message, style: const TextStyle(color: AppColors.textMuted)),
        ),
      ),
    );
  }
}

// ── Ödeme Rozeti (public) ─────────────────────────────────────────────────────

class ReportPaymentBadge extends StatelessWidget {
  final PaymentType type;
  const ReportPaymentBadge({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (type) {
      PaymentType.nakit => ('Nakit', AppColors.cash),
      PaymentType.pos => ('POS', AppColors.pos),
      PaymentType.acikHesap => ('Açık', AppColors.openAccount),
      PaymentType.parcali => ('Parçalı', AppColors.splitPayment),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

// ── Satışlar Tablosu (private) ────────────────────────────────────────────────
// Mobil: kart listesi — DataTable dar ekranda yatay kaydırma gerektirir, UX kötü.
// Masaüstü: DataTable (yatay kaydırma ile).

class _SalesTable extends StatelessWidget {
  final List<Sale> sales;
  final void Function(Sale) onRowTap;
  const _SalesTable({required this.sales, required this.onRowTap});

  @override
  Widget build(BuildContext context) {
    return context.isMobile ? _buildMobileList() : _buildDesktopTable();
  }

  // Mobil: her satış → kart satırı
  Widget _buildMobileList() {
    final totalAmount = sales.fold<num>(0, (s, e) => s + e.totalAmount);
    final totalProducts = sales.fold<int>(0, (s, e) => s + e.totalProducts);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: sales.length,
          separatorBuilder: (_, __) =>
              const Divider(height: 1, color: AppColors.divider),
          itemBuilder: (context, i) {
            final s = sales[i];
            return InkWell(
              onTap: () => onRowTap(s),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    // Sol: satış kodu + saat + müşteri
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Text(
                                s.saleCode,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _timeOnly(s.saleDate),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textMuted,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            s.customerName ?? 'Perakende',
                            style: TextStyle(
                              fontSize: 12,
                              color: s.customerName != null
                                  ? AppColors.textSecondary
                                  : AppColors.textMuted,
                              fontStyle: s.customerName == null
                                  ? FontStyle.italic
                                  : null,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Orta: ödeme rozeti
                    ReportPaymentBadge(type: s.paymentType),
                    const SizedBox(width: 8),
                    // Sağ: toplam tutar
                    Text(
                      formatCurrency(s.totalAmount),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.chevron_right,
                      size: 16,
                      color: AppColors.textMuted,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        // Toplam satırı
        Container(
          color: AppColors.tableHeader,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'TOPLAM — ${sales.length} satış · $totalProducts adet',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                formatCurrency(totalAmount),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Masaüstü: DataTable yatay kaydırma
  Widget _buildDesktopTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(AppColors.tableHeader),
        columns: const [
          DataColumn(label: Text('#')),
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
          ...List.generate(sales.length, (i) {
            final s = sales[i];
            return DataRow(
              onSelectChanged: (_) => onRowTap(s),
              cells: [
                DataCell(Text(
                  '${i + 1}',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                )),
                DataCell(Text(
                  _timeOnly(s.saleDate),
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                )),
                DataCell(Text(
                  s.saleCode,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: AppColors.primary,
                  ),
                )),
                DataCell(Text(
                  s.customerName ?? 'Perakende',
                  style: TextStyle(
                    color: s.customerName != null
                        ? AppColors.textPrimary
                        : AppColors.textMuted,
                    fontStyle: s.customerName == null ? FontStyle.italic : null,
                  ),
                )),
                DataCell(Text('${s.totalProducts} adet')),
                DataCell(Text(
                  s.discountPercent > 0 ? '%${s.discountPercent}' : '-',
                  style: TextStyle(
                    color: s.discountPercent > 0
                        ? AppColors.warning
                        : AppColors.textMuted,
                  ),
                )),
                DataCell(ReportPaymentBadge(type: s.paymentType)),
                DataCell(Text(
                  formatCurrency(s.totalAmount),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                )),
                DataCell(
                  SizedBox(
                    width: 140,
                    child: Text(
                      s.note ?? '-',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 12),
                    ),
                  ),
                ),
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
                style: const TextStyle(fontWeight: FontWeight.bold),
              )),
              DataCell(Text(
                '${sales.fold<int>(0, (s, e) => s + e.totalProducts)} adet',
                style: const TextStyle(fontWeight: FontWeight.bold),
              )),
              const DataCell(Text('')),
              const DataCell(Text('')),
              DataCell(Text(
                formatCurrency(sales.fold<num>(0, (s, e) => s + e.totalAmount)),
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: AppColors.primary),
              )),
              const DataCell(Text('')),
            ],
          ),
        ],
      ),
    );
  }

  String _timeOnly(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

// ── Ödemeler Tablosu (private) ────────────────────────────────────────────────
// Mobil: kart listesi; Masaüstü: DataTable yatay kaydırma.

class _PaymentsTable extends StatelessWidget {
  final List<CustomerPayment> payments;
  const _PaymentsTable({required this.payments});

  @override
  Widget build(BuildContext context) {
    return context.isMobile ? _buildMobileList() : _buildDesktopTable();
  }

  // Mobil: her ödeme → satır kartı
  Widget _buildMobileList() {
    final totalAmount = payments.fold<num>(0, (s, p) => s + p.amount);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: payments.length,
          separatorBuilder: (_, __) =>
              const Divider(height: 1, color: AppColors.divider),
          itemBuilder: (_, i) {
            final p = payments[i];
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  // Sol: müşteri + not + saat
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          p.customerName ?? '-',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (p.note != null && p.note!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            p.note!,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textMuted,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 2),
                        Text(
                          _timeOnly(p.paymentDate),
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Sağ: tutar
                  Text(
                    formatCurrency(p.amount),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        // Toplam satırı
        Container(
          color: AppColors.tableHeader,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'TOPLAM — ${payments.length} ödeme',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                formatCurrency(totalAmount),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: AppColors.success,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Masaüstü: DataTable yatay kaydırma
  Widget _buildDesktopTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(AppColors.tableHeader),
        columns: const [
          DataColumn(label: Text('#')),
          DataColumn(label: Text('Saat')),
          DataColumn(label: Text('Müşteri')),
          DataColumn(label: Text('Tutar'), numeric: true),
          DataColumn(label: Text('Not')),
        ],
        rows: [
          ...List.generate(payments.length, (i) {
            final p = payments[i];
            return DataRow(cells: [
              DataCell(Text(
                '${i + 1}',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
              )),
              DataCell(Text(
                _timeOnly(p.paymentDate),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              )),
              DataCell(Text(p.customerName ?? '-')),
              DataCell(Text(
                formatCurrency(p.amount),
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: AppColors.success),
              )),
              DataCell(SizedBox(
                width: 200,
                child: Text(
                  p.note ?? '-',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 12),
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
                style: const TextStyle(fontWeight: FontWeight.bold),
              )),
              DataCell(Text(
                formatCurrency(payments.fold<num>(0, (s, p) => s + p.amount)),
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: AppColors.success),
              )),
              const DataCell(Text('')),
            ],
          ),
        ],
      ),
    );
  }

  String _timeOnly(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
