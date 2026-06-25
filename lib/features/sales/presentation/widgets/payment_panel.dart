import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../application/payment_input_notifier.dart';
import '../../application/sales_cart_notifier.dart';
import '../../data/models/sale.dart';

class PaymentPanel extends ConsumerStatefulWidget {
  const PaymentPanel({super.key});

  @override
  ConsumerState<PaymentPanel> createState() => _PaymentPanelState();
}

class _PaymentPanelState extends ConsumerState<PaymentPanel> {
  bool _completing = false;
  final _cashController = TextEditingController();
  final _cardController = TextEditingController();

  @override
  void dispose() {
    _cashController.dispose();
    _cardController.dispose();
    super.dispose();
  }

  void _syncControllers(PaymentInputState payment) {
    final cashText = payment.cashSplit == 0 ? '' : payment.cashSplit.toString();
    if (_cashController.text != cashText) _cashController.text = cashText;

    final cardText = payment.cardSplit == 0 ? '' : payment.cardSplit.toString();
    if (_cardController.text != cardText) _cardController.text = cardText;
  }

  @override
  Widget build(BuildContext context) {
    final salesState = ref.watch(salesCartProvider);
    final tab = salesState.active;
    final payment = ref.watch(paymentInputProvider);
    final paymentNotifier = ref.read(paymentInputProvider.notifier);
    final isReturnMode = salesState.isReturnMode;
    _syncControllers(payment);

    final cartEmpty = tab.items.isEmpty;

    return Card(
      shape: isReturnMode
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppColors.danger, width: 2),
            )
          : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // İade modu banner
            if (isReturnMode) ...[
              Container(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.danger.withValues(alpha: 0.4)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.undo_rounded, color: AppColors.danger, size: 16),
                    SizedBox(width: 6),
                    Text(
                      'İADE MODU AKTİF',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.danger,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            // Tutar satırı
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isReturnMode ? 'İade Tutarı' : 'Tutar',
                  style: TextStyle(
                    fontSize: 14,
                    color: isReturnMode ? AppColors.danger : AppColors.textMuted,
                  ),
                ),
                Text(
                  formatCurrency(tab.total),
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: isReturnMode ? AppColors.danger : AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (isReturnMode) ...[
              // İade modu — sadece Nakit ve POS
              Row(
                children: [
                  Expanded(
                    child: _PaymentTypeButton(
                      label: 'Nakit İade',
                      sublabel: '',
                      icon: Icons.payments_outlined,
                      color: AppColors.danger,
                      selected: false,
                      onTap: (cartEmpty || _completing) ? null : () => _completeReturn(tab, PaymentType.nakit),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _PaymentTypeButton(
                      label: 'POS İadesi',
                      sublabel: '',
                      icon: Icons.credit_card_outlined,
                      color: AppColors.danger,
                      selected: false,
                      onTap: (cartEmpty || _completing) ? null : () => _completeReturn(tab, PaymentType.pos),
                    ),
                  ),
                ],
              ),
              if (_completing) ...[
                const SizedBox(height: 16),
                const Center(child: CircularProgressIndicator()),
              ],
            ] else ...[
              // Normal satış modu butonları
              Row(
                children: [
                  Expanded(
                    child: _PaymentTypeButton(
                      label: 'Nakit',
                      sublabel: '',
                      icon: Icons.payments_outlined,
                      color: AppColors.cash,
                      selected: false,
                      onTap: (cartEmpty || _completing) ? null : () => _completeSaleDirectly(tab, PaymentType.nakit),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _PaymentTypeButton(
                      label: 'POS',
                      sublabel: '',
                      icon: Icons.credit_card_outlined,
                      color: AppColors.pos,
                      selected: false,
                      onTap: (cartEmpty || _completing) ? null : () => _completeSaleDirectly(tab, PaymentType.pos),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _PaymentTypeButton(
                      label: 'Açık Hesap',
                      sublabel: '',
                      icon: Icons.account_balance_wallet_outlined,
                      color: AppColors.openAccount,
                      selected: payment.type == PaymentType.acikHesap,
                      onTap: () => paymentNotifier.selectType(PaymentType.acikHesap, tab.total),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _PaymentTypeButton(
                      label: 'Parçalı',
                      sublabel: '',
                      icon: Icons.call_split_outlined,
                      color: AppColors.splitPayment,
                      selected: payment.type == PaymentType.parcali,
                      onTap: () => paymentNotifier.selectType(PaymentType.parcali, tab.total),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (payment.type == PaymentType.parcali) ...[
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _cashController,
                        decoration: const InputDecoration(labelText: 'Nakit'),
                        keyboardType: TextInputType.number,
                        onChanged: (v) => paymentNotifier.setCashSplit(num.tryParse(v.replaceAll(',', '.')) ?? 0),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _cardController,
                        decoration: const InputDecoration(labelText: 'Kart'),
                        keyboardType: TextInputType.number,
                        onChanged: (v) => paymentNotifier.setCardSplit(num.tryParse(v.replaceAll(',', '.')) ?? 0),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Toplam Ödenen: ${formatCurrency(payment.cashSplit + payment.cardSplit)}'),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: (cartEmpty || _completing) ? null : () => _completeSale(tab, payment),
                        child: _completing
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Satışı Tamamla'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    _ParcaliSummary(
                      cashSplit: payment.cashSplit,
                      cardSplit: payment.cardSplit,
                      total: tab.total,
                    ),
                  ],
                ),
              ] else if (payment.type == PaymentType.acikHesap) ...[
                Text(
                  'Açık Hesap: ${formatCurrency(tab.total)} müşteri hesabına borç olarak işlenecek.',
                  style: const TextStyle(color: AppColors.warning),
                ),
                if (tab.customerId == null)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text('Lütfen müşteri seçin.', style: TextStyle(color: AppColors.danger)),
                  ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: (cartEmpty || _completing) ? null : () => _completeSale(tab, payment),
                  child: _completing
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Satışı Tamamla'),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _completeReturn(CustomerTabState tab, PaymentType type) async {
    if (tab.items.isEmpty) return;

    setState(() => _completing = true);
    try {
      final saleCode = await ref.read(salesRepositoryProvider).completeReturn(
            items: tab.items,
            totalAmount: tab.total,
            paymentType: type,
            customerId: tab.customerId,
          );

      ref.read(salesCartProvider.notifier).clearActiveTab();
      ref.read(paymentInputProvider.notifier).reset();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('İade tamamlandı: $saleCode'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _completing = false);
    }
  }

  Future<void> _completeSaleDirectly(CustomerTabState tab, PaymentType type) async {
    if (tab.items.isEmpty) return;

    setState(() => _completing = true);
    try {
      final num cashAmount = type == PaymentType.nakit ? tab.total : 0;
      final num cardAmount = type == PaymentType.pos ? tab.total : 0;

      final saleCode = await ref.read(salesRepositoryProvider).completeSale(
            items: tab.items,
            discountPercent: tab.discountPercent,
            totalAmount: tab.total,
            paidAmount: tab.total,
            paymentType: type,
            cashAmount: cashAmount,
            cardAmount: cardAmount,
            customerId: tab.customerId,
          );

      ref.read(salesCartProvider.notifier).clearActiveTab();
      ref.read(paymentInputProvider.notifier).reset();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Satış tamamlandı: $saleCode')),
        );
      }
    } finally {
      if (mounted) setState(() => _completing = false);
    }
  }

  Future<void> _completeSale(CustomerTabState tab, PaymentInputState payment) async {
    if (tab.items.isEmpty) return;

    if (payment.type == PaymentType.acikHesap && tab.customerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Açık hesap için lütfen müşteri seçin.')),
      );
      return;
    }

    num cashAmount = 0;
    num cardAmount = 0;
    num paidAmount = 0;

    if (payment.type == PaymentType.parcali) {
      cashAmount = payment.cashSplit;
      cardAmount = payment.cardSplit;
      paidAmount = cashAmount + cardAmount;
    }

    setState(() => _completing = true);
    try {
      final saleCode = await ref.read(salesRepositoryProvider).completeSale(
            items: tab.items,
            discountPercent: tab.discountPercent,
            totalAmount: tab.total,
            paidAmount: paidAmount,
            paymentType: payment.type,
            cashAmount: cashAmount,
            cardAmount: cardAmount,
            customerId: tab.customerId,
          );

      ref.read(salesCartProvider.notifier).clearActiveTab();
      ref.read(paymentInputProvider.notifier).reset();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Satış tamamlandı: $saleCode')),
        );
      }
    } finally {
      if (mounted) setState(() => _completing = false);
    }
  }
}

class _ParcaliSummary extends StatelessWidget {
  final num cashSplit;
  final num cardSplit;
  final num total;

  const _ParcaliSummary({
    required this.cashSplit,
    required this.cardSplit,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final paid = cashSplit + cardSplit;
    final diff = total - paid;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.tableHeader,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _SummaryLine(label: 'Nakit', amount: cashSplit, color: AppColors.cash),
          const SizedBox(height: 2),
          _SummaryLine(label: 'Kart', amount: cardSplit, color: AppColors.pos),
          if (diff != 0) ...[
            const SizedBox(height: 2),
            _SummaryLine(
              label: diff > 0 ? 'Eksik' : 'Fazla',
              amount: diff.abs(),
              color: diff > 0 ? AppColors.danger : AppColors.warning,
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  final String label;
  final num amount;
  final Color color;

  const _SummaryLine({required this.label, required this.amount, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
        ),
        Text(
          formatCurrency(amount),
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
        ),
      ],
    );
  }
}

class _PaymentTypeButton extends StatelessWidget {
  final String label;
  final String sublabel;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback? onTap;

  const _PaymentTypeButton({
    required this.label,
    required this.sublabel,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    final bg = selected
        ? color
        : disabled
            ? AppColors.goldSubtle
            : AppColors.goldBg;
    final fg = selected
        ? Colors.white
        : disabled
            ? AppColors.textMuted
            : color;
    final borderColor = selected ? color : AppColors.goldBorder;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor, width: selected ? 1.5 : 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: fg, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: fg,
              ),
              textAlign: TextAlign.center,
            ),
            if (sublabel.isNotEmpty)
              Text(
                sublabel,
                style: TextStyle(fontSize: 10, color: fg.withValues(alpha: 0.7)),
              ),
          ],
        ),
      ),
    );
  }
}
