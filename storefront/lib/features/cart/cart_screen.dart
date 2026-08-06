import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../state/cart_provider.dart';
import '../../widgets/store_app_bar.dart';

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(cartProvider);
    final total = items.fold<num>(0, (sum, item) => sum + item.subtotal);

    return Scaffold(
      appBar: const StoreAppBar(),
      body: items.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.shopping_cart_outlined, size: 48, color: StoreColors.textMuted),
                  const SizedBox(height: 12),
                  const Text('Sepetiniz boş', style: TextStyle(color: StoreColors.textMuted)),
                  const SizedBox(height: 16),
                  ElevatedButton(onPressed: () => context.go('/'), child: const Text('Alışverişe Başla')),
                ],
              ),
            )
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 700),
                child: Column(
                  children: [
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: items.length,
                        separatorBuilder: (context, i) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final item = items[i];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: SizedBox(
                                    width: 56,
                                    height: 56,
                                    child: item.product.imageUrl != null
                                        ? Image.network(
                                            item.product.imageUrl!,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stack) => Container(
                                              color: StoreColors.pageBg,
                                              child: const Icon(Icons.image_not_supported_outlined, color: StoreColors.textMuted),
                                            ),
                                          )
                                        : Container(
                                            color: StoreColors.pageBg,
                                            child: const Icon(Icons.image_not_supported_outlined, color: StoreColors.textMuted),
                                          ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(item.product.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                                      const SizedBox(height: 4),
                                      Text(formatCurrency(item.product.price), style: const TextStyle(color: StoreColors.textMuted, fontSize: 12.5)),
                                    ],
                                  ),
                                ),
                                _QtyControl(
                                  quantity: item.quantity,
                                  onChanged: (q) => ref.read(cartProvider.notifier).setQuantity(item.product.id, q),
                                ),
                                const SizedBox(width: 12),
                                SizedBox(
                                  width: 84,
                                  child: Text(formatCurrency(item.subtotal), textAlign: TextAlign.right,
                                      style: const TextStyle(fontWeight: FontWeight.w700, color: StoreColors.navy)),
                                ),
                                IconButton(
                                  onPressed: () => ref.read(cartProvider.notifier).remove(item.product.id),
                                  icon: const Icon(Icons.close, size: 18, color: StoreColors.textMuted),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        border: Border(top: BorderSide(color: StoreColors.border)),
                      ),
                      child: Row(
                        children: [
                          const Text('Toplam', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                          const Spacer(),
                          Text(formatCurrency(total), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: StoreColors.navy)),
                          const SizedBox(width: 20),
                          ElevatedButton(
                            onPressed: () => context.go('/odeme'),
                            child: const Text('Siparişi Tamamla'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _QtyControl extends StatelessWidget {
  final int quantity;
  final ValueChanged<int> onChanged;

  const _QtyControl({required this.quantity, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: () => onChanged(quantity - 1),
          icon: const Icon(Icons.remove_circle_outline, size: 20),
          constraints: const BoxConstraints.tightFor(width: 32, height: 32),
          padding: EdgeInsets.zero,
        ),
        SizedBox(width: 24, child: Text('$quantity', textAlign: TextAlign.center)),
        IconButton(
          onPressed: () => onChanged(quantity + 1),
          icon: const Icon(Icons.add_circle_outline, size: 20),
          constraints: const BoxConstraints.tightFor(width: 32, height: 32),
          padding: EdgeInsets.zero,
        ),
      ],
    );
  }
}
