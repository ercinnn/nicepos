import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/responsive.dart';
import '../../application/customers_provider.dart';
import '../../data/models/customer_payment.dart';
import '../../../sales/data/models/sale.dart';
import '../widgets/customer_form_dialog.dart';

class CustomerDetailScreen extends ConsumerStatefulWidget {
  final String customerId;

  const CustomerDetailScreen({super.key, required this.customerId});

  @override
  ConsumerState<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends ConsumerState<CustomerDetailScreen> {
  DateTime? _from;
  DateTime? _to;

  @override
  Widget build(BuildContext context) {
    final customerAsync = ref.watch(customerByIdProvider(widget.customerId));
    final salesAsync = ref.watch(customerSalesProvider(
      CustomerSalesQuery(customerId: widget.customerId, from: _from, to: _to),
    ));
    final paymentsAsync = ref.watch(customerPaymentsProvider(widget.customerId));

    return customerAsync.when(
      data: (customer) {
        if (customer == null) {
          return const Center(child: Text('Müşteri bulunamadı.'));
        }

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Başlık satırı: geri · ad · düzenle · Ödeme/Borç butonları ──────
              // Mobil: butonlar ikinci satıra taşınır (tek satıra sığmaz)
              if (context.isMobile) ...[
                Row(
                  children: [
                    IconButton(
                      onPressed: () => context.go('/customers'),
                      icon: const Icon(Icons.arrow_back),
                    ),
                    Expanded(
                      child: Text(
                        customer.name,
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      onPressed: () async {
                        final result = await showDialog<bool>(
                          context: context,
                          builder: (_) => CustomerFormDialog(customer: customer),
                        );
                        if (result == true) {
                          ref.invalidate(customerByIdProvider(widget.customerId));
                          ref.invalidate(customersProvider);
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            _showPaymentDialog(context, CustomerPaymentType.odeme),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Ödeme Ekle'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            _showPaymentDialog(context, CustomerPaymentType.borc),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Borç Ekle'),
                      ),
                    ),
                  ],
                ),
              ] else
                // Masaüstü: tek satır
                Row(
                  children: [
                    IconButton(
                      onPressed: () => context.go('/customers'),
                      icon: const Icon(Icons.arrow_back),
                    ),
                    Text(customer.name,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      onPressed: () async {
                        final result = await showDialog<bool>(
                          context: context,
                          builder: (_) => CustomerFormDialog(customer: customer),
                        );
                        if (result == true) {
                          ref.invalidate(customerByIdProvider(widget.customerId));
                          ref.invalidate(customersProvider);
                        }
                      },
                    ),
                    const Spacer(),
                    OutlinedButton.icon(
                      onPressed: () =>
                          _showPaymentDialog(context, CustomerPaymentType.odeme),
                      icon: const Icon(Icons.add),
                      label: const Text('Ödeme Ekle'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () =>
                          _showPaymentDialog(context, CustomerPaymentType.borc),
                      icon: const Icon(Icons.add),
                      label: const Text('Borç Ekle'),
                    ),
                  ],
                ),
              const SizedBox(height: 16),
              // ── Özet kartlar ──────────────────────────────────────────────────
              // Mobil: 2×2 ızgara — her kart yarı genişlik
              // Masaüstü: 4'lü tek satır (Expanded ile eşit dağılım)
              if (context.isMobile)
                LayoutBuilder(
                  builder: (_, constraints) {
                    final cardWidth = (constraints.maxWidth - 12) / 2;
                    final totalSales = formatCurrency(
                      (salesAsync.value ?? [])
                          .fold<num>(0, (s, sale) => s + sale.totalAmount),
                    );
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        SizedBox(
                          width: cardWidth,
                          child: _SummaryCard(
                              title: 'Toplam Satış',
                              value: totalSales,
                              color: AppColors.info),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: _SummaryCard(
                              title: 'Toplam Borç',
                              value: formatCurrency(customer.openAccountTotal),
                              color: AppColors.warning),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: _SummaryCard(
                              title: 'Ödeme',
                              value: formatCurrency(customer.paidTotal),
                              color: AppColors.success),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: _SummaryCard(
                              title: 'Kalan Borç',
                              value: formatCurrency(customer.remainingDebt),
                              color: AppColors.danger),
                        ),
                      ],
                    );
                  },
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: _SummaryCard(
                        title: 'Toplam Satış',
                        value: formatCurrency((salesAsync.value ?? [])
                            .fold<num>(0, (s, sale) => s + sale.totalAmount)),
                        color: AppColors.info,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SummaryCard(
                          title: 'Toplam Borç',
                          value: formatCurrency(customer.openAccountTotal),
                          color: AppColors.warning),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SummaryCard(
                          title: 'Ödeme',
                          value: formatCurrency(customer.paidTotal),
                          color: AppColors.success),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SummaryCard(
                          title: 'Kalan Borç',
                          value: formatCurrency(customer.remainingDebt),
                          color: AppColors.danger),
                    ),
                  ],
                ),
              const SizedBox(height: 16),
              if (customer.phone != null || customer.address != null || customer.note != null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Wrap(
                      spacing: 24,
                      runSpacing: 8,
                      children: [
                        if (customer.phone != null) Text('Telefon: ${customer.phone}'),
                        if (customer.paymentTermDays != null) Text('Vade Süresi: ${customer.paymentTermDays} gün'),
                        if (customer.creditLimit > 0) Text('Açık Hesap Limiti: ${formatCurrency(customer.creditLimit)}'),
                        if (customer.address != null) Text('Adres: ${customer.address}'),
                        if (customer.note != null) Text('Not: ${customer.note}'),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              // ── Alışverişler başlığı + tarih filtreleri ───────────────────
              // Mobil: başlık üstte, tarih seçiciler altta (tek satıra sığmaz)
              // Masaüstü: tek satır
              if (context.isMobile) ...[
                const Text('Alışverişler',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _DateField(
                        label: 'Başlangıç',
                        value: _from,
                        onChanged: (d) => setState(() => _from = d),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _DateField(
                        label: 'Bitiş',
                        value: _to,
                        onChanged: (d) => setState(() => _to = d),
                      ),
                    ),
                    if (_from != null || _to != null)
                      TextButton(
                        onPressed: () => setState(() {
                          _from = null;
                          _to = null;
                        }),
                        child: const Text('Temizle'),
                      ),
                  ],
                ),
              ] else
                Row(
                  children: [
                    const Text('Alışverişler',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    SizedBox(
                      width: 160,
                      child: _DateField(
                        label: 'Başlangıç',
                        value: _from,
                        onChanged: (d) => setState(() => _from = d),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 160,
                      child: _DateField(
                        label: 'Bitiş',
                        value: _to,
                        onChanged: (d) => setState(() => _to = d),
                      ),
                    ),
                    if (_from != null || _to != null)
                      TextButton(
                        onPressed: () => setState(() {
                          _from = null;
                          _to = null;
                        }),
                        child: const Text('Temizle'),
                      ),
                  ],
                ),
              const SizedBox(height: 8),
              Card(
                child: salesAsync.when(
                  data: (sales) => _SalesTable(sales: sales),
                  loading: () => const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
                  error: (e, _) => Padding(padding: const EdgeInsets.all(24), child: Text('Hata: $e')),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Ödeme / Borç Hareketleri', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Card(
                child: paymentsAsync.when(
                  data: (payments) => _PaymentsTable(payments: payments),
                  loading: () => const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
                  error: (e, _) => Padding(padding: const EdgeInsets.all(24), child: Text('Hata: $e')),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Hata: $e')),
    );
  }

  Future<void> _showPaymentDialog(BuildContext context, CustomerPaymentType type) async {
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(type == CustomerPaymentType.odeme ? 'Ödeme Ekle' : 'Borç Ekle'),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountCtrl,
                decoration: const InputDecoration(labelText: 'Tutar'),
                keyboardType: TextInputType.number,
                autofocus: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteCtrl,
                decoration: const InputDecoration(labelText: 'Not'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Vazgeç')),
          ElevatedButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Kaydet')),
        ],
      ),
    );

    if (confirmed != true) return;
    final amount = num.tryParse(amountCtrl.text.replaceAll(',', '.')) ?? 0;
    if (amount <= 0) return;

    await ref.read(customerRepositoryProvider).addPayment(CustomerPayment(
          customerId: widget.customerId,
          type: type,
          amount: amount,
          note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
          paymentDate: DateTime.now(),
        ));

    ref.invalidate(customerByIdProvider(widget.customerId));
    ref.invalidate(customerPaymentsProvider(widget.customerId));
    ref.invalidate(customersProvider);
    ref.invalidate(totalCustomerDebtProvider);
  }
}

// _SummaryCard: boyutu üst widget belirler (masaüstü: Expanded, mobil: SizedBox)
class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;

  const _SummaryCard({required this.title, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// _DateField: sabit genişlik yok — masaüstü SizedBox(160), mobil Expanded ile sarmalanır
class _DateField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;

  const _DateField({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2100),
        );
        if (picked != null) onChanged(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.calendar_today, size: 16),
          isDense: true,
        ),
        child: Text(value == null ? '-' : formatDate(value!)),
      ),
    );
  }
}

// ── Alışverişler Tablosu / Kart Listesi ──────────────────────────────────────
// Masaüstü: DataTable (yatay kaydırmalı)
// Mobil: kompakt kart satırları

class _SalesTable extends StatelessWidget {
  final List<Sale> sales;
  const _SalesTable({required this.sales});

  @override
  Widget build(BuildContext context) {
    if (sales.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: Text('Alışveriş bulunamadı.')),
      );
    }

    if (context.isMobile) {
      return ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: sales.length,
        separatorBuilder: (_, _) =>
            const Divider(height: 1, color: AppColors.divider),
        itemBuilder: (context, i) {
          final s = sales[i];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                // Sol: satış kodu + tarih
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        s.saleCode,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        formatDateTime(s.saleDate),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Orta: ödeme tipi rozeti
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    s.paymentType.label,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Sağ: tutar
                Text(
                  formatCurrency(s.totalAmount),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          );
        },
      );
    }

    // Masaüstü: DataTable yatay kaydırmalı
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Satış Kodu')),
          DataColumn(label: Text('Tarih')),
          DataColumn(label: Text('Tutar')),
          DataColumn(label: Text('İskonto')),
          DataColumn(label: Text('Ödenen')),
          DataColumn(label: Text('Kalan Borç')),
          DataColumn(label: Text('Ödeme Tipi')),
        ],
        rows: sales.map((s) {
          return DataRow(cells: [
            DataCell(Text(s.saleCode)),
            DataCell(Text(formatDateTime(s.saleDate))),
            DataCell(Text(formatCurrency(s.totalAmount))),
            DataCell(Text('%${s.discountPercent}')),
            DataCell(Text(formatCurrency(s.paidAmount))),
            DataCell(Text(formatCurrency(s.remainingDebt))),
            DataCell(Text(s.paymentType.label)),
          ]);
        }).toList(),
      ),
    );
  }
}

// ── Ödeme / Borç Hareketleri Tablosu / Kart Listesi ──────────────────────────

class _PaymentsTable extends StatelessWidget {
  final List<CustomerPayment> payments;
  const _PaymentsTable({required this.payments});

  @override
  Widget build(BuildContext context) {
    if (payments.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: Text('Hareket bulunamadı.')),
      );
    }

    if (context.isMobile) {
      return ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: payments.length,
        separatorBuilder: (_, _) =>
            const Divider(height: 1, color: AppColors.divider),
        itemBuilder: (context, i) {
          final p = payments[i];
          final isDebt = p.type == CustomerPaymentType.borc;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                // Tür ikonu
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: (isDebt ? AppColors.danger : AppColors.success)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isDebt ? Icons.arrow_upward : Icons.arrow_downward,
                    size: 16,
                    color: isDebt ? AppColors.danger : AppColors.success,
                  ),
                ),
                const SizedBox(width: 10),
                // Tür + tarih
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        p.type.label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDebt ? AppColors.danger : AppColors.success,
                        ),
                      ),
                      if (p.note != null && p.note!.isNotEmpty) ...[
                        const SizedBox(height: 1),
                        Text(
                          p.note!,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      Text(
                        formatDateTime(p.paymentDate),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  formatCurrency(p.amount),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDebt ? AppColors.danger : AppColors.success,
                  ),
                ),
              ],
            ),
          );
        },
      );
    }

    // Masaüstü: DataTable yatay kaydırmalı
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Tarih')),
          DataColumn(label: Text('Tür')),
          DataColumn(label: Text('Tutar')),
          DataColumn(label: Text('Not')),
        ],
        rows: payments.map((p) {
          return DataRow(cells: [
            DataCell(Text(formatDateTime(p.paymentDate))),
            DataCell(Text(
              p.type.label,
              style: TextStyle(
                color: p.type == CustomerPaymentType.borc
                    ? AppColors.danger
                    : AppColors.success,
                fontWeight: FontWeight.w600,
              ),
            )),
            DataCell(Text(formatCurrency(p.amount))),
            DataCell(Text(p.note ?? '-')),
          ]);
        }).toList(),
      ),
    );
  }
}
