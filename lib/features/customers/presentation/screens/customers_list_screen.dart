import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/responsive.dart';
import '../../application/customers_provider.dart';
import '../../data/models/customer.dart';
import '../widgets/customer_form_dialog.dart';

class CustomersListScreen extends ConsumerStatefulWidget {
  const CustomersListScreen({super.key});

  @override
  ConsumerState<CustomersListScreen> createState() => _CustomersListScreenState();
}

class _CustomersListScreenState extends ConsumerState<CustomersListScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  bool _onlyWithDebt = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(customersProvider(CustomersQuery(query: _query, onlyWithDebt: _onlyWithDebt)));
    final totalDebtAsync = ref.watch(totalCustomerDebtProvider);
    final isMobile = context.isMobile;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Başlık + Yeni Müşteri butonu ──────────────────────────────────────
        Row(
          children: [
            Text(
              'Müşteriler',
              style: TextStyle(
                fontSize: isMobile ? 18 : 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: () async {
                final result = await showDialog<bool>(
                  context: context,
                  builder: (_) => const CustomerFormDialog(),
                );
                if (result == true) {
                  ref.invalidate(customersProvider);
                  ref.invalidate(totalCustomerDebtProvider);
                }
              },
              icon: const Icon(Icons.person_add_alt_outlined, size: 18),
              // Mobilde kısa etiket — uzun metin taşmasın
              label: Text(isMobile ? 'Yeni' : 'Yeni Müşteri Oluştur'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // ── Toplam borç özet kartı ────────────────────────────────────────────
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Toplam Kalan Borç',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
                const SizedBox(height: 4),
                Text(
                  formatCurrency(totalDebtAsync.value ?? 0),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.danger,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        // ── Arama + Filtre ────────────────────────────────────────────────────
        // Mobil: arama tam genişlik, filtre bir alt satıra geçer
        // Masaüstü: yan yana tek satır
        if (isMobile) ...[
          TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              hintText: 'Müşteri adı ile ara...',
              prefixIcon: Icon(Icons.search, size: 18),
              isDense: true,
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
          const SizedBox(height: 8),
          FilterChip(
            label: const Text('Sadece borçluları göster'),
            selected: _onlyWithDebt,
            onSelected: (v) => setState(() => _onlyWithDebt = v),
          ),
        ] else
          Row(
            children: [
              SizedBox(
                width: 320,
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'Müşteri adı ile ara...',
                    prefixIcon: Icon(Icons.search, size: 18),
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              const SizedBox(width: 16),
              FilterChip(
                label: const Text('Sadece borcu olanları göster'),
                selected: _onlyWithDebt,
                onSelected: (v) => setState(() => _onlyWithDebt = v),
              ),
            ],
          ),
        const SizedBox(height: 12),
        // ── Müşteri listesi ───────────────────────────────────────────────────
        // Mobil: kart listesi (DataTable dar ekrana sığmaz)
        // Masaüstü: DataTable
        Expanded(
          child: customersAsync.when(
            data: (customers) => isMobile
                ? _CustomersMobileList(customers: customers)
                : Card(child: _CustomersTable(customers: customers)),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Hata: $e')),
          ),
        ),
      ],
    );
  }
}

class _CustomersTable extends StatelessWidget {
  final List<Customer> customers;

  const _CustomersTable({required this.customers});

  @override
  Widget build(BuildContext context) {
    if (customers.isEmpty) {
      return const Center(child: Text('Müşteri bulunamadı.'));
    }

    return SingleChildScrollView(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Müşteri')),
            DataColumn(label: Text('Alışveriş Sayısı')),
            DataColumn(label: Text('Açık Hesap')),
            DataColumn(label: Text('Ödeme')),
            DataColumn(label: Text('Kalan Borç')),
            DataColumn(label: Text('Son Ödeme Tarihi')),
            DataColumn(label: Text('Detay')),
          ],
          rows: customers.map((c) {
            return DataRow(cells: [
              DataCell(Text(c.name)),
              DataCell(Text('${c.purchaseCount}')),
              DataCell(Text(formatCurrency(c.openAccountTotal))),
              DataCell(Text(formatCurrency(c.paidTotal))),
              DataCell(Text(
                formatCurrency(c.remainingDebt),
                style: TextStyle(
                  color: c.remainingDebt > 0 ? AppColors.danger : AppColors.success,
                  fontWeight: FontWeight.w600,
                ),
              )),
              DataCell(Text(c.lastPaymentDate == null ? '-' : formatDate(c.lastPaymentDate!))),
              DataCell(
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => context.go('/customers/${c.id}'),
                ),
              ),
            ]);
          }).toList(),
        ),
      ),
    );
  }
}

// ── Mobil müşteri kartları ────────────────────────────────────────────────────
//
// Masaüstü DataTable yerine mobilde kompakt kart listesi kullanılır.
// Her kart: sol = ad + alışveriş sayısı, sağ = kalan borç + chevron.

class _CustomersMobileList extends StatelessWidget {
  final List<Customer> customers;
  const _CustomersMobileList({required this.customers});

  @override
  Widget build(BuildContext context) {
    if (customers.isEmpty) {
      return const Center(child: Text('Müşteri bulunamadı.'));
    }
    return Card(
      child: ListView.separated(
        itemCount: customers.length,
        separatorBuilder: (_, _) =>
            const Divider(height: 1, color: AppColors.divider),
        itemBuilder: (context, i) =>
            _CustomerMobileCard(customer: customers[i]),
      ),
    );
  }
}

class _CustomerMobileCard extends StatelessWidget {
  final Customer customer;
  const _CustomerMobileCard({required this.customer});

  @override
  Widget build(BuildContext context) {
    final c = customer;
    return InkWell(
      onTap: () => context.go('/customers/${c.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            // Sol: müşteri adı + bilgi
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    c.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    c.lastPaymentDate != null
                        ? 'Son ödeme: ${formatDate(c.lastPaymentDate!)}'
                        : '${c.purchaseCount} alışveriş',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Sağ: kalan borç tutarı
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  formatCurrency(c.remainingDebt),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: c.remainingDebt > 0
                        ? AppColors.danger
                        : AppColors.success,
                  ),
                ),
                const Text(
                  'Borç',
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
              ],
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.chevron_right,
              size: 18,
              color: AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}
