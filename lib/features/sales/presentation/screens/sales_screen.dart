import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../features/products/application/products_provider.dart';
import '../../application/sales_cart_notifier.dart';
import '../widgets/barcode_scanner_modal.dart';
import '../widgets/cart_table.dart';
import '../widgets/customer_tabs.dart';
import '../widgets/payment_panel.dart';
import '../widgets/product_search_dialog.dart';
import '../widgets/quick_products_panel.dart';

class SalesScreen extends ConsumerStatefulWidget {
  const SalesScreen({super.key});

  @override
  ConsumerState<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends ConsumerState<SalesScreen> {
  final _barcodeController = TextEditingController();
  final _barcodeFocusNode = FocusNode();

  @override
  void dispose() {
    _barcodeController.dispose();
    _barcodeFocusNode.dispose();
    super.dispose();
  }

  Future<void> _onBarcodeSubmitted(String value) async {
    final query = value.trim();
    if (query.isEmpty) return;

    final product = await ref.read(productRepositoryProvider).fetchByBarcode(query);
    if (product != null) {
      ref.read(salesCartProvider.notifier).addProduct(product);
      _barcodeController.clear();
      _barcodeFocusNode.requestFocus();
      return;
    }

    final matches = await ref.read(productRepositoryProvider).fetchAll(query: query);
    if (matches.length == 1) {
      ref.read(salesCartProvider.notifier).addProduct(matches.first);
      _barcodeController.clear();
      _barcodeFocusNode.requestFocus();
      return;
    }

    if (mounted) {
      await showDialog(context: context, builder: (_) => ProductSearchDialog(initialQuery: query));
    }
    _barcodeController.clear();
    _barcodeFocusNode.requestFocus();
  }

  void _showMobilePaymentSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _MobilePaymentSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (context.isMobile) return _buildMobile();
    return _buildDesktop();
  }

  // ─── Desktop layout ───────────────────────────────────────────────────────

  Widget _buildDesktop() {
    final isReturnMode = ref.watch(salesCartProvider).isReturnMode;

    return Focus(
      autofocus: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _barcodeController,
                  focusNode: _barcodeFocusNode,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'Ürün barkodunu okutunuz veya ürün adı yazıp Enter\'a basınız...',
                    prefixIcon: Icon(Icons.qr_code_scanner, size: 18),
                  ),
                  onSubmitted: _onBarcodeSubmitted,
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => showDialog(
                    context: context, builder: (_) => const ProductSearchDialog()),
                icon: const Icon(Icons.search),
                label: const Text('Ara'),
              ),
              const SizedBox(width: 8),
              _ReturnModeButton(isActive: isReturnMode),
            ],
          ),
          const SizedBox(height: 12),
          const CustomerTabs(),
          const SizedBox(height: 12),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 3,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: const CartTable(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 580,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 320, child: PaymentPanel()),
                      const SizedBox(height: 12),
                      const Expanded(child: Card(child: QuickProductsPanel())),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Mobile layout ───────────────────────────────────────────────────────

  Widget _buildMobile() {
    final salesState = ref.watch(salesCartProvider);
    final tab = salesState.active;
    final hasItems = tab.items.isNotEmpty;
    final isReturnMode = salesState.isReturnMode;

    return Column(
      children: [
        // Barkod satırı (kompakt)
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _barcodeController,
                focusNode: _barcodeFocusNode,
                decoration: InputDecoration(
                  hintText: isReturnMode ? 'İade ürünü barkod veya adı...' : 'Barkod veya ürün adı...',
                  prefixIcon: const Icon(Icons.qr_code_scanner, size: 18),
                  isDense: true,
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.search, size: 18),
                    onPressed: () => showDialog(
                        context: context, builder: (_) => const ProductSearchDialog()),
                  ),
                ),
                onSubmitted: _onBarcodeSubmitted,
              ),
            ),
            const SizedBox(width: 8),
            _ReturnModeButton(isActive: isReturnMode, compact: true),
            if (!kIsWeb) ...[
              const SizedBox(width: 8),
              SizedBox(
                height: 48,
                width: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => openBarcodeScanner(context, _onBarcodeSubmitted),
                  child: const Icon(Icons.camera_alt_outlined, size: 22),
                ),
              ),
            ],
          ],
        ),
        // İade modu banner (mobil)
        if (isReturnMode) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
            decoration: BoxDecoration(
              color: AppColors.danger.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.danger.withValues(alpha: 0.4)),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.undo_rounded, color: AppColors.danger, size: 14),
                SizedBox(width: 4),
                Text(
                  'İADE MODU AKTİF — Sepete eklediğiniz ürünler iade edilecek',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.danger),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 8),
        const CustomerTabs(),
        const SizedBox(height: 8),
        // Sepet tablosu — tam genişlik
        Expanded(
          child: Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: const CartTable(),
            ),
          ),
        ),
        // Hızlı ürünler — sabit yükseklik
        const SizedBox(height: 8),
        SizedBox(
          height: 200,
          child: Card(
            margin: EdgeInsets.zero,
            child: const QuickProductsPanel(),
          ),
        ),
        const SizedBox(height: 8),
        // Ödeme çubuğu
        _MobilePaymentBar(
          total: tab.total,
          hasItems: hasItems,
          isReturnMode: isReturnMode,
          onPay: _showMobilePaymentSheet,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// İade Modu Toggle Butonu
// ---------------------------------------------------------------------------

class _ReturnModeButton extends ConsumerWidget {
  final bool isActive;
  final bool compact;

  const _ReturnModeButton({required this.isActive, this.compact = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 48,
      child: compact
          ? IconButton(
              style: IconButton.styleFrom(
                backgroundColor: isActive
                    ? AppColors.danger.withValues(alpha: 0.12)
                    : Colors.transparent,
                foregroundColor: isActive ? AppColors.danger : AppColors.textMuted,
                side: BorderSide(
                  color: isActive ? AppColors.danger : AppColors.border,
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              tooltip: isActive ? 'İade Modunu Kapat' : 'İade Modu',
              icon: const Icon(Icons.undo_rounded, size: 20),
              onPressed: () => ref.read(salesCartProvider.notifier).toggleReturnMode(),
            )
          : OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: isActive ? AppColors.danger : AppColors.textMuted,
                side: BorderSide(
                  color: isActive ? AppColors.danger : AppColors.border,
                ),
                backgroundColor: isActive ? AppColors.danger.withValues(alpha: 0.08) : null,
              ),
              onPressed: () => ref.read(salesCartProvider.notifier).toggleReturnMode(),
              icon: Icon(
                isActive ? Icons.undo_rounded : Icons.undo_rounded,
                size: 18,
              ),
              label: Text(isActive ? 'İade Modu: Açık' : 'İade Modu'),
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Mobile: sticky payment bar at the bottom
// ---------------------------------------------------------------------------

class _MobilePaymentBar extends ConsumerWidget {
  final num total;
  final bool hasItems;
  final bool isReturnMode;
  final VoidCallback onPay;

  const _MobilePaymentBar({
    required this.total,
    required this.hasItems,
    required this.isReturnMode,
    required this.onPay,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final barColor = isReturnMode ? AppColors.danger.withValues(alpha: 0.08) : AppColors.cardBg;
    final borderColor = isReturnMode ? AppColors.danger.withValues(alpha: 0.5) : AppColors.border;
    final amountColor = isReturnMode ? AppColors.danger : AppColors.primary;
    final buttonColor = isReturnMode ? AppColors.danger : AppColors.primary;
    final buttonLabel = isReturnMode ? 'İade Al' : 'Ödeme Al';
    final buttonIcon = isReturnMode ? Icons.undo_rounded : Icons.payments_outlined;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: barColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isReturnMode ? 'İade Tutarı' : 'Toplam',
                style: TextStyle(
                  fontSize: 11,
                  color: isReturnMode ? AppColors.danger : AppColors.textMuted,
                ),
              ),
              Text(
                formatCurrency(total),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: amountColor,
                ),
              ),
            ],
          ),
          const Spacer(),
          SizedBox(
            height: 44,
            child: ElevatedButton.icon(
              onPressed: hasItems ? onPay : null,
              icon: Icon(buttonIcon, size: 18),
              label: Text(buttonLabel, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: buttonColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Mobile: payment bottom sheet
// ---------------------------------------------------------------------------

class _MobilePaymentSheet extends StatelessWidget {
  const _MobilePaymentSheet();

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (_, controller) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              // Handle
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 4),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Row(
                  children: [
                    const Text(
                      'Ödeme',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: SingleChildScrollView(
                  controller: controller,
                  padding: const EdgeInsets.all(16),
                  child: const PaymentPanel(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
