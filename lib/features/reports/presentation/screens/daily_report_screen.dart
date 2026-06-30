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
                        Text(
                          'Günlük Rapor',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(
                          formatDate(_date),
                          style: Theme.of(context).textTheme.bodySmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Text(
                          'Günlük Rapor',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(width: AppSizes.space12),
                        Text(
                          formatDate(_date),
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppColors.textMuted),
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
          // İmza: ekranın TEK kahramanı — Toplam Ciro.
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
              ? const ReportEmptyCard('Bu tarihte satış bulunamadı.')
              : ReportTableCard(
                  child: _SalesTable(sales: report.sales, onRowTap: onSaleTap),
                ),
          const SizedBox(height: AppSizes.space24),
          ReportSectionHeader(
            title: 'Alınan Ödemeler',
            badge: '${report.receivedPayments.length}',
            color: AppColors.success,
          ),
          const SizedBox(height: AppSizes.space8),
          report.receivedPayments.isEmpty
              ? const ReportEmptyCard('Bu tarihte ödeme bulunamadı.')
              : ReportTableCard(
                  child: _PaymentsTable(payments: report.receivedPayments),
                ),
          const SizedBox(height: AppSizes.space24),
        ],
      ),
    );
  }
}

// ── Hero Tutar (public — imza öğesi, §4) ──────────────────────────────────────
// Ekranın TEK kahramanı: Toplam Ciro. İri tabular tutar + ince altın ray.
// Kenarlıksız yüzey (§5 hero istisnası): yalnız zemin + yumuşak gölge + ray.

class ReportHero extends StatelessWidget {
  final num amount;
  final String label;
  const ReportHero({
    super.key,
    required this.amount,
    this.label = 'TOPLAM CİRO',
  });

  @override
  Widget build(BuildContext context) {
    final mobil = context.isMobile;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.space20,
        vertical: AppSizes.space20,
      ),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        boxShadow: AppSizes.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: AppSizes.space8),
          IntrinsicWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatCurrency(amount),
                  style: TextStyle(
                    fontSize: mobil ? 30 : 38,
                    fontWeight: FontWeight.w800,
                    height: 1.05,
                    letterSpacing: -0.5,
                    color: AppColors.primary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: AppSizes.space6),
                // Altın aksan rayı — yalnızca hero tutarın altında (~%40).
                FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: 0.4,
                  child: Container(
                    height: 3,
                    decoration: BoxDecoration(
                      color: AppColors.gold,
                      borderRadius: BorderRadius.circular(AppSizes.radiusPill),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tablo Kartı (public) — token kart kabuğu, içerik kırpılır ─────────────────

class ReportTableCard extends StatelessWidget {
  final Widget child;
  const ReportTableCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: AppSizes.cardDecoration(),
      child: child,
    );
  }
}

// ── Özet Satırı (public — tarihsel rapor da kullanır) ─────────────────────────
// Hero (Toplam Ciro) artık ızgaranın üyesi DEĞİL → burada tekrar edilmez.
// Kalan kartlar sakin destek; yalnız semantik renkler (nakit/POS/kâr) konuşur.

class ReportSummaryRow extends StatelessWidget {
  final DailyReportSummary report;
  const ReportSummaryRow({super.key, required this.report});

  @override
  Widget build(BuildContext context) {
    final cards = [
      ReportStatCard(icon: Icons.payments_outlined, label: 'Nakit Tahsilat', value: formatCurrency(report.cashTotal), color: AppColors.cash),
      ReportStatCard(icon: Icons.credit_card_outlined, label: 'POS Tahsilat', value: formatCurrency(report.posTotal), color: AppColors.pos),
      ReportStatCard(icon: Icons.account_balance_wallet_outlined, label: 'Açık Hesap', value: formatCurrency(report.openAccountTotal), color: AppColors.openAccount),
      ReportStatCard(icon: Icons.shopping_cart_outlined, label: 'Satış Adedi', value: '${report.sales.length}', color: AppColors.textSecondary),
      ReportStatCard(icon: Icons.inventory_2_outlined, label: 'Ürün Maliyeti', value: formatCurrency(report.productCost), color: AppColors.textMuted),
      // Kâr: highlight YOK (R7) — yalnız success/danger metin semantiği taşır.
      ReportStatCard(icon: Icons.trending_up_outlined, label: 'Kâr', value: formatCurrency(report.profit), color: report.profit >= 0 ? AppColors.success : AppColors.danger),
      ReportStatCard(icon: Icons.arrow_circle_down_outlined, label: 'Alınan Ödemeler', value: formatCurrency(report.receivedPaymentsTotal), color: AppColors.success),
    ];

    if (context.isMobile) {
      // İki sütun — token boşluklu Wrap (yüzde-genişlik düzeni kaldırıldı).
      return LayoutBuilder(
        builder: (_, constraints) {
          final cardWidth =
              (constraints.maxWidth - AppSizes.space12) / 2;
          return Wrap(
            spacing: AppSizes.space12,
            runSpacing: AppSizes.space12,
            children: cards
                .map((c) => SizedBox(width: cardWidth, child: c))
                .toList(),
          );
        },
      );
    }

    return Wrap(
      spacing: AppSizes.space12,
      runSpacing: AppSizes.space12,
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

  const ReportStatCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppSizes.cardDecoration(),
      padding: const EdgeInsets.all(AppSizes.cardPadding),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppSizes.radiusSm),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: AppSizes.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
                const SizedBox(height: AppSizes.space4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: color,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ],
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
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(width: AppSizes.space8),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.space8,
            vertical: AppSizes.space2,
          ),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppSizes.radiusPill),
          ),
          child: Text(
            badge,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
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
    return Container(
      width: double.infinity,
      decoration: AppSizes.cardDecoration(),
      padding: const EdgeInsets.symmetric(vertical: AppSizes.space32),
      child: Center(
        child: Text(message, style: const TextStyle(color: AppColors.textMuted)),
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
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.space8,
        vertical: AppSizes.space2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSizes.radiusPill),
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
          separatorBuilder: (_, _) =>
              const Divider(height: 1, color: AppColors.divider),
          itemBuilder: (context, i) {
            final s = sales[i];
            return InkWell(
              onTap: () => onRowTap(s),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.space12,
                  vertical: AppSizes.space12,
                ),
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
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                              ),
                              const SizedBox(width: AppSizes.space6),
                              Text(
                                _timeOnly(s.saleDate),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textMuted,
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSizes.space4),
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
                    const SizedBox(width: AppSizes.space8),
                    // Orta: ödeme rozeti
                    ReportPaymentBadge(type: s.paymentType),
                    const SizedBox(width: AppSizes.space8),
                    // Sağ: toplam tutar
                    Text(
                      formatCurrency(s.totalAmount),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(width: AppSizes.space4),
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
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.space12,
            vertical: AppSizes.space12,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'TOPLAM — ${sales.length} satış · $totalProducts adet',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              Text(
                formatCurrency(totalAmount),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: AppColors.primary,
                  fontFeatures: [FontFeature.tabularFigures()],
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
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                )),
                DataCell(Text(
                  _timeOnly(s.saleDate),
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
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
                    color: s.customerName != null
                        ? AppColors.textPrimary
                        : AppColors.textMuted,
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
          separatorBuilder: (_, _) =>
              const Divider(height: 1, color: AppColors.divider),
          itemBuilder: (_, i) {
            final p = payments[i];
            return Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.space12,
                vertical: AppSizes.space12,
              ),
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
                          const SizedBox(height: AppSizes.space4),
                          Text(
                            p.note!,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textMuted,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: AppSizes.space4),
                        Text(
                          _timeOnly(p.paymentDate),
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSizes.space12),
                  // Sağ: tutar
                  Text(
                    formatCurrency(p.amount),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppColors.success,
                      fontFeatures: [FontFeature.tabularFigures()],
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
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.space12,
            vertical: AppSizes.space12,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'TOPLAM — ${payments.length} ödeme',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              Text(
                formatCurrency(totalAmount),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: AppColors.success,
                  fontFeatures: [FontFeature.tabularFigures()],
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
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              )),
              DataCell(Text(
                _timeOnly(p.paymentDate),
                style: const TextStyle(
                  fontSize: 13,
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

  String _timeOnly(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
