import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../application/customers_provider.dart';
import '../../data/models/customer.dart';
import '../widgets/customer_form_dialog.dart';

/// Tablo/satır para ve sayı hücreleri için tabular figür (hizalı rakam) stili.
const TextStyle _tabular = TextStyle(
  fontFeatures: [FontFeature.tabularFigures()],
);

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
              style: Theme.of(context).textTheme.titleLarge,
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
        const SizedBox(height: AppSizes.space16),
        // ── İmza HERO: Toplam Kalan Borç (ekranın TEK kahramanı) ──────────────
        // İri tabular tutar + altında semantik ray: borç (>0) ise danger,
        // alacak fazlası / sıfır ise positive (§4 müşteri istisnası — altın değil).
        _TotalDebtHero(total: totalDebtAsync.value ?? 0, isMobile: isMobile),
        const SizedBox(height: AppSizes.space16),
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
                : Container(
                    decoration: AppSizes.cardDecoration(),
                    clipBehavior: Clip.antiAlias,
                    child: _CustomersTable(customers: customers),
                  ),
            loading: () => const SkeletonList(itemCount: 8),
            error: (e, _) => Center(child: Text('Hata: $e')),
          ),
        ),
      ],
    );
  }
}

// ── İmza HERO: Toplam Kalan Borç ─────────────────────────────────────────────
// Ekranın tek kahramanı: agregat kalan borç. İri tabular tutar + altında
// semantik ray (borç>0 → danger, alacak/sıfır → positive). Altın DEĞİL (§4 istisna).
class _TotalDebtHero extends StatelessWidget {
  final num total;
  final bool isMobile;
  const _TotalDebtHero({required this.total, required this.isMobile});

  @override
  Widget build(BuildContext context) {
    final hasDebt = total > 0;
    final semantic = hasDebt ? AppColors.danger : AppColors.success;
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
          const Text(
            'TOPLAM KALAN BORÇ',
            style: TextStyle(
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
                  formatCurrency(total),
                  style: TextStyle(
                    fontSize: isMobile ? 30 : 38,
                    fontWeight: FontWeight.w800,
                    height: 1.05,
                    letterSpacing: -0.5,
                    color: semantic,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: AppSizes.space6),
                // Altın değil — tutara göre semantik ray (~%40 genişlik).
                FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: 0.4,
                  child: Container(
                    height: 3,
                    decoration: BoxDecoration(
                      color: semantic,
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

class _CustomersTable extends ConsumerWidget {
  final List<Customer> customers;

  const _CustomersTable({required this.customers});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (customers.isEmpty) {
      return const EmptyState(
        icon: Icons.people_outline,
        title: 'Müşteri bulunamadı',
        message: 'Aramanızı değiştirin veya yeni müşteri ekleyin',
      );
    }

    final headingStyle = Theme.of(context).textTheme.labelMedium;

    return SingleChildScrollView(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: const WidgetStatePropertyAll(AppColors.goldBg),
          headingTextStyle: headingStyle,
          columns: const [
            DataColumn(label: Text('Müşteri')),
            DataColumn(label: Text('Alışveriş Sayısı'), numeric: true),
            DataColumn(label: Text('Açık Hesap'), numeric: true),
            DataColumn(label: Text('Ödeme'), numeric: true),
            DataColumn(label: Text('Kalan Borç'), numeric: true),
            DataColumn(label: Text('Son Ödeme Tarihi')),
            DataColumn(label: Text('Detay')),
          ],
          rows: customers.map((c) {
            return DataRow(cells: [
              // Müşteri adı + adın yanında silme butonu
              DataCell(Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(c.name),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        size: 18, color: AppColors.danger),
                    tooltip: 'Müşteriyi sil',
                    visualDensity: VisualDensity.compact,
                    onPressed: () =>
                        _confirmAndDeleteCustomer(context, ref, c),
                  ),
                ],
              )),
              DataCell(Text('${c.purchaseCount}', style: _tabular)),
              DataCell(Text(formatCurrency(c.openAccountTotal), style: _tabular)),
              DataCell(Text(formatCurrency(c.paidTotal), style: _tabular)),
              DataCell(Text(
                formatCurrency(c.remainingDebt),
                style: _tabular.copyWith(
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
      return const EmptyState(
        icon: Icons.people_outline,
        title: 'Müşteri bulunamadı',
        message: 'Aramanızı değiştirin veya yeni müşteri ekleyin',
      );
    }
    return Container(
      decoration: AppSizes.cardDecoration(),
      clipBehavior: Clip.antiAlias,
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

class _CustomerMobileCard extends ConsumerWidget {
  final Customer customer;
  const _CustomerMobileCard({required this.customer});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = customer;
    return InkWell(
      onTap: () => context.go('/customers/${c.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.space12, vertical: AppSizes.space12),
        child: Row(
          children: [
            // Sol: müşteri adı + bilgi
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Müşteri adı + adın yanında silme butonu
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          c.name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Dokunma hedefi mobilde min 48×48 (token §3); ikon 18px
                      // görünür ama dokunma alanı yanlış-dokunmaya karşı 48'e çıkar.
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 48,
                          minHeight: 48,
                        ),
                        icon: const Icon(Icons.delete_outline,
                            size: 18, color: AppColors.danger),
                        tooltip: 'Müşteriyi sil',
                        onPressed: () =>
                            _confirmAndDeleteCustomer(context, ref, c),
                      ),
                    ],
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
            // Sağ: bakiye tutarı + semantik etiket
            // Borç (>0) danger; alacak (<0) / kapalı (0) positive. Etiket de
            // duruma göre değişir ki yeşil tutar "Borç" diye yanlış okunmasın.
            Builder(
              builder: (context) {
                final hasDebt = c.remainingDebt > 0;
                final semantic =
                    hasDebt ? AppColors.danger : AppColors.success;
                final label = hasDebt
                    ? 'Borç'
                    : (c.remainingDebt < 0 ? 'Alacak' : 'Bakiye kapalı');
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      formatCurrency(c.remainingDebt),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: semantic,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    Text(
                      label,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textMuted),
                    ),
                  ],
                );
              },
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

// ── Müşteri silme — onay dialog'u + repository çağrısı ────────────────────────
//
// İlişkili kayıtlar (satış, ödeme, borç hareketi) nedeniyle foreign key kısıtı
// silmeyi engelleyebilir. Bu durumda çökme olmaması için hata yakalanır ve
// kullanıcıya anlaşılır bir SnackBar gösterilir.
Future<void> _confirmAndDeleteCustomer(
  BuildContext context,
  WidgetRef ref,
  Customer customer,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Müşteriyi Sil'),
      content: Text(
        '${customer.name} müşterisini silmek istediğinize emin misiniz?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('İptal'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Sil'),
        ),
      ],
    ),
  );

  if (confirmed != true) return;

  try {
    await ref.read(customerRepositoryProvider).delete(customer.id);
    ref.invalidate(customersProvider);
    ref.invalidate(totalCustomerDebtProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${customer.name} silindi.')),
      );
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.danger,
          content: Text(
            'Müşteri silinemedi. İlişkili satış/ödeme kayıtları olabilir.',
          ),
        ),
      );
    }
  }
}
