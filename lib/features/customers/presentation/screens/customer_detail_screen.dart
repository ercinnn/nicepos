import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/responsive.dart';
import '../../application/customers_provider.dart';
import '../../data/models/customer_payment.dart';
import '../../../sales/data/models/sale.dart';
import '../../../sales/data/repositories/sales_repository.dart';
import '../../../sales/presentation/screens/sale_edit_screen.dart';
import '../widgets/customer_form_dialog.dart';

/// Tablo para/sayı hücreleri için tabular figür (hizalı rakam) stili.
const TextStyle _tabular = TextStyle(
  fontFeatures: [FontFeature.tabularFigures()],
);

class CustomerDetailScreen extends ConsumerStatefulWidget {
  final String customerId;

  const CustomerDetailScreen({super.key, required this.customerId});

  @override
  ConsumerState<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends ConsumerState<CustomerDetailScreen> {
  DateTime? _from;
  DateTime? _to;
  bool _busy = false; // toplu/tekil silme sırasında çift-tıklamayı engeller

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
                        style: Theme.of(context).textTheme.titleLarge,
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
                    IconButton(
                      icon: const Icon(Icons.delete_outline,
                          size: 18, color: AppColors.danger),
                      tooltip: 'Müşteriyi sil',
                      constraints: const BoxConstraints(
                          minWidth: 48, minHeight: 48),
                      onPressed: () => _confirmAndDelete(context, customer.name),
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
                        style: Theme.of(context).textTheme.titleLarge),
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
                    IconButton(
                      icon: const Icon(Icons.delete_outline,
                          size: 18, color: AppColors.danger),
                      tooltip: 'Müşteriyi sil',
                      onPressed: () => _confirmAndDelete(context, customer.name),
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
              const SizedBox(height: AppSizes.space16),
              // ── İmza HERO: Kalan Borç (müşteri bakiyesi) ─────────────────────
              // Ekranın tek kahramanı. İri tabular tutar + altında semantik ray:
              // borç (>0) → danger, alacak/sıfır → positive (§4 istisna, altın değil).
              _BalanceHero(
                balance: customer.remainingDebt,
                isMobile: context.isMobile,
              ),
              const SizedBox(height: AppSizes.space12),
              // ── Sakin destek kartları (hero ile yarışmaz) ────────────────────
              // Toplam Satış nötr; Toplam Borç danger; Ödeme success semantik.
              Builder(
                builder: (context) {
                  final totalSales = formatCurrency((salesAsync.value ?? [])
                      .fold<num>(0, (s, sale) => s + sale.totalAmount));
                  final cards = [
                    _SummaryCard(
                      title: 'Toplam Satış',
                      value: totalSales,
                      color: AppColors.textPrimary,
                    ),
                    _SummaryCard(
                      title: 'Toplam Borç',
                      value: formatCurrency(customer.openAccountTotal),
                      color: AppColors.danger,
                    ),
                    _SummaryCard(
                      title: 'Ödeme',
                      value: formatCurrency(customer.paidTotal),
                      color: AppColors.success,
                    ),
                  ];
                  if (context.isMobile) {
                    return LayoutBuilder(
                      builder: (_, constraints) {
                        final cardWidth =
                            (constraints.maxWidth - AppSizes.space12) / 2;
                        return Wrap(
                          spacing: AppSizes.space12,
                          runSpacing: AppSizes.space12,
                          children: [
                            for (final card in cards)
                              SizedBox(width: cardWidth, child: card),
                          ],
                        );
                      },
                    );
                  }
                  return Row(
                    children: [
                      for (var i = 0; i < cards.length; i++) ...[
                        if (i > 0) const SizedBox(width: AppSizes.space12),
                        Expanded(child: cards[i]),
                      ],
                    ],
                  );
                },
              ),
              const SizedBox(height: AppSizes.space16),
              // ── İletişim & hesap bilgileri (salt-okunur künye) ────────────
              // Inline metin yerine etiket/değer çiftleri: künye taranabilir.
              Builder(
                builder: (context) {
                  final pairs = <_InfoPair>[
                    if (customer.phone != null)
                      _InfoPair('Telefon', customer.phone!),
                    if (customer.paymentTermDays != null)
                      _InfoPair('Vade Süresi', '${customer.paymentTermDays} gün'),
                    if (customer.creditLimit > 0)
                      _InfoPair('Açık Hesap Limiti',
                          formatCurrency(customer.creditLimit)),
                    if (customer.address != null)
                      _InfoPair('Adres', customer.address!),
                    if (customer.note != null)
                      _InfoPair('Not', customer.note!),
                  ];
                  if (pairs.isEmpty) return const SizedBox.shrink();
                  return Container(
                    width: double.infinity,
                    decoration: AppSizes.cardDecoration(),
                    padding: const EdgeInsets.all(AppSizes.cardPadding),
                    child: Wrap(
                      spacing: AppSizes.space32,
                      runSpacing: AppSizes.space12,
                      children: pairs,
                    ),
                  );
                },
              ),
              const SizedBox(height: AppSizes.space16),
              // ── Alışverişler başlığı + tarih filtreleri ───────────────────
              // Mobil: başlık üstte, tarih seçiciler altta (tek satıra sığmaz)
              // Masaüstü: tek satır
              if (context.isMobile) ...[
                Row(
                  children: [
                    Text('Alışverişler',
                        style: Theme.of(context).textTheme.titleMedium),
                    const Spacer(),
                    if ((salesAsync.value ?? const []).isNotEmpty)
                      _deleteAllButton(
                          () => _deleteAllSales(salesAsync.value ?? const [])),
                  ],
                ),
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
                    Text('Alışverişler',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(width: 12),
                    if ((salesAsync.value ?? const []).isNotEmpty)
                      _deleteAllButton(
                          () => _deleteAllSales(salesAsync.value ?? const [])),
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
              Container(
                decoration: AppSizes.cardDecoration(),
                clipBehavior: Clip.antiAlias,
                child: salesAsync.when(
                  data: (sales) => _SalesTable(
                    sales: sales,
                    onTap: _openSaleEdit,
                    onDelete: _deleteSale,
                  ),
                  loading: () => const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
                  error: (e, _) => Padding(padding: const EdgeInsets.all(24), child: Text('Hata: $e')),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text('Ödeme / Borç Hareketleri',
                      style: Theme.of(context).textTheme.titleMedium),
                  const Spacer(),
                  if ((paymentsAsync.value ?? const []).isNotEmpty)
                    _deleteAllButton(
                        () => _deleteAllPayments(paymentsAsync.value ?? const [])),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                decoration: AppSizes.cardDecoration(),
                clipBehavior: Clip.antiAlias,
                child: paymentsAsync.when(
                  data: (payments) => _PaymentsTable(
                    payments: payments,
                    onDelete: _deletePayment,
                  ),
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

  // ── Müşteri silme — onay dialog'u + repository çağrısı ──────────────────────
  // İlişkili kayıtlar (satış/ödeme/borç) foreign key kısıtı nedeniyle silmeyi
  // engelleyebilir; bu durumda çökme olmaması için hata yakalanır.
  Future<void> _confirmAndDelete(BuildContext context, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Müşteriyi Sil'),
        content: Text('$name müşterisini silmek istediğinize emin misiniz?'),
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
      await ref.read(customerRepositoryProvider).delete(widget.customerId);
      ref.invalidate(customersProvider);
      ref.invalidate(totalCustomerDebtProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$name silindi.')),
        );
        context.go('/customers');
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

  Future<void> _showPaymentDialog(BuildContext context, CustomerPaymentType type) async {
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    // Geçmişe dönük giriş için tarih seçilebilir; varsayılan: bugün.
    var selectedDate = DateTime.now();

    final isOdeme = type == CustomerPaymentType.odeme;
    // Semantik renk: ödeme borcu azaltır (success), borç artırır (danger).
    final semantic = isOdeme ? AppColors.success : AppColors.danger;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Icon(
                isOdeme ? Icons.arrow_downward : Icons.arrow_upward,
                size: 20,
                color: semantic,
              ),
              const SizedBox(width: AppSizes.space8),
              Text(isOdeme ? 'Ödeme Ekle' : 'Borç Ekle'),
            ],
          ),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: amountCtrl,
                  decoration: InputDecoration(
                    labelText: 'Tutar',
                    prefixText: '₺ ',
                    helperText:
                        isOdeme ? 'Bakiyeden düşülür' : 'Bakiyeye eklenir',
                    helperStyle: TextStyle(color: semantic),
                  ),
                  keyboardType: TextInputType.number,
                  autofocus: true,
                ),
                const SizedBox(height: AppSizes.space16),
                TextField(
                  controller: noteCtrl,
                  decoration: const InputDecoration(labelText: 'Not (opsiyonel)'),
                ),
                const SizedBox(height: AppSizes.space16),
                // ── Tarih seçici (geçmişe dönük giriş) ───────────────────────
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: dialogContext,
                      initialDate: selectedDate,
                      firstDate: DateTime(2015),
                      lastDate: DateTime.now(),
                      helpText: 'İşlem tarihini seçin',
                    );
                    if (picked != null) {
                      // Saat kısmını şimdiki saatle koru (sıralama tutarlı olsun).
                      final now = DateTime.now();
                      setDialogState(() => selectedDate = DateTime(
                            picked.year,
                            picked.month,
                            picked.day,
                            now.hour,
                            now.minute,
                            now.second,
                          ));
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Tarih',
                      suffixIcon: Icon(Icons.calendar_today, size: 16),
                      isDense: true,
                    ),
                    child: Text(formatDate(selectedDate)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Vazgeç')),
            ElevatedButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Kaydet')),
          ],
        ),
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
          paymentDate: selectedDate,
        ));

    ref.invalidate(customerByIdProvider(widget.customerId));
    ref.invalidate(customerPaymentsProvider(widget.customerId));
    ref.invalidate(customersProvider);
    ref.invalidate(totalCustomerDebtProvider);
  }

  // ── Geçmiş işlemler: düzenle / sil / toplu sil ─────────────────────────────

  void _invalidateHistory() {
    ref.invalidate(customerSalesProvider);
    ref.invalidate(customerPaymentsProvider(widget.customerId));
    ref.invalidate(customerByIdProvider(widget.customerId));
    ref.invalidate(customersProvider);
    ref.invalidate(totalCustomerDebtProvider);
  }

  Widget _deleteAllButton(VoidCallback onPressed) {
    return TextButton.icon(
      onPressed: _busy ? null : onPressed,
      icon: const Icon(Icons.delete_sweep_outlined, size: 18),
      label: const Text('Tümünü Sil'),
      style: TextButton.styleFrom(foregroundColor: AppColors.danger),
    );
  }

  /// Geçmiş satışa tıklayınca — günlük rapordaki gibi düzenleme ekranı açılır.
  Future<void> _openSaleEdit(Sale s) async {
    if (_busy) return;
    final items = await SalesRepository().fetchItems(s.id);
    if (!mounted) return;
    final updated = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => SaleEditScreen(sale: s, initialItems: items),
    );
    if (updated == true) _invalidateHistory();
  }

  Future<bool> _confirm(String title, String message) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  /// Ortak silme yürütücüsü: meşgul bayrağı + invalidate + SnackBar + hata yakalama.
  Future<void> _runDelete(Future<void> Function() action, String successMsg) async {
    setState(() => _busy = true);
    try {
      await action();
      _invalidateHistory();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(successMsg)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppColors.danger, content: Text('Silinemedi: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteSale(Sale s) async {
    if (_busy) return;
    if (!await _confirm('Satışı Sil',
        '${s.saleCode} satışını silmek istediğinize emin misiniz? Bu işlem geri alınamaz.')) {
      return;
    }
    await _runDelete(() => SalesRepository().deleteSale(s.id), '${s.saleCode} silindi.');
  }

  Future<void> _deleteAllSales(List<Sale> sales) async {
    if (_busy || sales.isEmpty) return;
    if (!await _confirm('Tüm Satışları Sil',
        '${sales.length} satışın tamamı silinecek. Bu işlem geri alınamaz. Emin misiniz?')) {
      return;
    }
    await _runDelete(() async {
      for (final s in sales) {
        await SalesRepository().deleteSale(s.id);
      }
    }, '${sales.length} satış silindi.');
  }

  Future<void> _deletePayment(CustomerPayment p) async {
    if (_busy) return;
    if (!await _confirm('Hareketi Sil',
        '${p.type.label} (${formatCurrency(p.amount)}) hareketini silmek istediğinize emin misiniz?')) {
      return;
    }
    await _runDelete(
        () => ref.read(customerRepositoryProvider).deletePayment(p.id), 'Hareket silindi.');
  }

  Future<void> _deleteAllPayments(List<CustomerPayment> payments) async {
    if (_busy || payments.isEmpty) return;
    if (!await _confirm('Tüm Hareketleri Sil',
        '${payments.length} ödeme/borç hareketinin tamamı silinecek. Emin misiniz?')) {
      return;
    }
    await _runDelete(() async {
      for (final p in payments) {
        await ref.read(customerRepositoryProvider).deletePayment(p.id);
      }
    }, '${payments.length} hareket silindi.');
  }
}

// ── İmza HERO: Kalan Borç (müşteri bakiyesi) ─────────────────────────────────
// Ekranın tek kahramanı. İri tabular tutar + altında semantik ray:
// borç (>0) → danger, alacak/sıfır → positive (§4 müşteri istisnası, altın değil).
class _BalanceHero extends StatelessWidget {
  final num balance;
  final bool isMobile;
  const _BalanceHero({required this.balance, required this.isMobile});

  @override
  Widget build(BuildContext context) {
    final hasDebt = balance > 0;
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
          Text(
            hasDebt ? 'KALAN BORÇ' : 'BAKİYE',
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
                  formatCurrency(balance),
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

// _InfoPair: künye satırı — etiket (utility/muted) üstte, değer (body/ink) altta.
// Salt-okunur müşteri bilgilerinin taranabilirliği için.
class _InfoPair extends StatelessWidget {
  final String label;
  final String value;
  const _InfoPair(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.6,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: AppSizes.space4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
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
    return Container(
      decoration: AppSizes.cardDecoration(),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.space16, vertical: AppSizes.space12),
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
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
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
  final void Function(Sale) onTap;
  final void Function(Sale) onDelete;
  const _SalesTable({
    required this.sales,
    required this.onTap,
    required this.onDelete,
  });

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
          return InkWell(
            onTap: () => onTap(s),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: AppSizes.space12),
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSizes.space8, vertical: AppSizes.space2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius:
                          BorderRadius.circular(AppSizes.radiusPill),
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
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  // Sil butonu — dokunma hedefi min 48×48 (token §3)
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        size: 18, color: AppColors.danger),
                    tooltip: 'Satışı sil',
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    onPressed: () => onDelete(s),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

    // Masaüstü: DataTable yatay kaydırmalı
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: const WidgetStatePropertyAll(AppColors.goldBg),
        headingTextStyle: Theme.of(context).textTheme.labelMedium,
        columns: const [
          DataColumn(label: Text('Satış Kodu')),
          DataColumn(label: Text('Tarih')),
          DataColumn(label: Text('Tutar'), numeric: true),
          DataColumn(label: Text('İskonto'), numeric: true),
          DataColumn(label: Text('Ödenen'), numeric: true),
          DataColumn(label: Text('Kalan Borç'), numeric: true),
          DataColumn(label: Text('Ödeme Tipi')),
          DataColumn(label: Text('')),
        ],
        rows: sales.map((s) {
          return DataRow(
            onSelectChanged: (_) => onTap(s),
            cells: [
              DataCell(Text(s.saleCode)),
              DataCell(Text(formatDateTime(s.saleDate))),
              DataCell(Text(formatCurrency(s.totalAmount), style: _tabular)),
              // İskonto TL tipiyse kesin TL tutarı, değilse yüzde gösterilir
              // (yalnız yüzde göstermek TL iskontoda yanıltıcı olur).
              DataCell(Text(
                s.discountType == 'tl'
                    ? formatCurrency(s.discountAmount)
                    : '%${s.discountPercent}',
                style: _tabular,
              )),
              DataCell(Text(formatCurrency(s.paidAmount), style: _tabular)),
              DataCell(Text(
                formatCurrency(s.remainingDebt),
                style: _tabular.copyWith(
                  color: s.remainingDebt > 0
                      ? AppColors.danger
                      : AppColors.success,
                  fontWeight: FontWeight.w600,
                ),
              )),
              DataCell(Text(s.paymentType.label)),
              DataCell(IconButton(
                icon: const Icon(Icons.delete_outline,
                    size: 18, color: AppColors.danger),
                tooltip: 'Satışı sil',
                onPressed: () => onDelete(s),
              )),
            ],
          );
        }).toList(),
      ),
    );
  }
}

// ── Ödeme / Borç Hareketleri Tablosu / Kart Listesi ──────────────────────────

class _PaymentsTable extends StatelessWidget {
  final List<CustomerPayment> payments;
  final void Function(CustomerPayment) onDelete;
  const _PaymentsTable({required this.payments, required this.onDelete});

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
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: AppSizes.space12),
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
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                // Dokunma hedefi min 48×48 (token §3)
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      size: 18, color: AppColors.danger),
                  tooltip: 'Hareketi sil',
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  onPressed: () => onDelete(p),
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
        headingRowColor: const WidgetStatePropertyAll(AppColors.goldBg),
        headingTextStyle: Theme.of(context).textTheme.labelMedium,
        columns: const [
          DataColumn(label: Text('Tarih')),
          DataColumn(label: Text('Tür')),
          DataColumn(label: Text('Tutar'), numeric: true),
          DataColumn(label: Text('Not')),
          DataColumn(label: Text('')),
        ],
        rows: payments.map((p) {
          final isDebt = p.type == CustomerPaymentType.borc;
          return DataRow(cells: [
            DataCell(Text(formatDateTime(p.paymentDate))),
            DataCell(Text(
              p.type.label,
              style: TextStyle(
                color: isDebt ? AppColors.danger : AppColors.success,
                fontWeight: FontWeight.w600,
              ),
            )),
            DataCell(Text(
              formatCurrency(p.amount),
              style: _tabular.copyWith(
                color: isDebt ? AppColors.danger : AppColors.success,
                fontWeight: FontWeight.w600,
              ),
            )),
            DataCell(Text(p.note ?? '-')),
            DataCell(IconButton(
              icon: const Icon(Icons.delete_outline,
                  size: 18, color: AppColors.danger),
              tooltip: 'Hareketi sil',
              onPressed: () => onDelete(p),
            )),
          ]);
        }).toList(),
      ),
    );
  }
}
