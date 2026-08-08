import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../widgets/store_app_bar.dart';
import 'checkout_screen.dart' show OrderSummary;

class OrderSuccessScreen extends StatelessWidget {
  final String orderCode;
  final OrderSummary? summary;

  const OrderSuccessScreen({
    super.key,
    required this.orderCode,
    this.summary,
  });

  void _copyCode(BuildContext context) {
    Clipboard.setData(ClipboardData(text: orderCode));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sipariş kodu panoya kopyalandı')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const StoreAppBar(),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20), // space.xl
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Küçük ikon zenginleştirmesi — halka + iç ikon (Lottie/Rive
                // YOK, salt CustomPaint/Container kompozisyonu).
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: StoreColors.success.withValues(alpha: 0.08),
                  ),
                  alignment: Alignment.center,
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: StoreColors.success,
                    ),
                    child: const Icon(
                      Icons.check,
                      size: 34,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 20), // space.xl
                const Text(
                  'Siparişiniz alındı!',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8), // space.sm
                Text(
                  'Siparişiniz alındı, ekibimiz sizinle iletişime geçecek.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: StoreColors.textMuted,
                  ),
                ),
                const SizedBox(height: 20), // space.xl
                InkWell(
                  onTap: () => _copyCode(context),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          orderCode,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontSize: 20, color: StoreColors.navy),
                        ),
                        const SizedBox(width: 8), // space.sm
                        const Icon(
                          Icons.copy_outlined,
                          size: 18,
                          color: StoreColors.textMuted,
                        ),
                      ],
                    ),
                  ),
                ),
                if (summary != null) ...[
                  const SizedBox(height: 24), // space.xxl
                  _OrderSummaryCard(summary: summary!),
                ],
                const SizedBox(height: 24), // space.xxl
                ElevatedButton(
                  onPressed: () => context.go('/'),
                  child: const Text('Alışverişe Devam Et'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Sipariş özeti kartı — design-tokens.md §10 ile aynı görsel dil (cart_screen
/// alt bar örüntüsünün genellenmesi). Altın ray TAŞIMAZ, bu bir hero değil.
class _OrderSummaryCard extends StatelessWidget {
  final OrderSummary summary;

  const _OrderSummaryCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20), // space.xl
      decoration: BoxDecoration(
        color: StoreColors.cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: StoreColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final item in summary.items) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${item.product.name}  ×${item.quantity}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: StoreColors.textMuted,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 8), // space.sm
                Text(
                  formatCurrency(item.subtotal),
                  style: const TextStyle(
                    color: StoreColors.textPrimary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4), // space.xs
          ],
          const SizedBox(height: 4), // space.xs
          const Divider(height: 1, color: StoreColors.border),
          const SizedBox(height: 8), // space.sm
          Row(
            children: [
              const Text(
                'Toplam',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Text(
                formatCurrency(summary.total),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: StoreColors.navy,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
