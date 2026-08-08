import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../data/models/cart_item.dart';
import '../../state/cart_provider.dart';
import '../../widgets/skeleton_box.dart';
import '../../widgets/store_app_bar.dart';
import '../../widgets/store_empty_state.dart';

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(cartProvider);
    final total = items.fold<num>(0, (sum, item) => sum + item.subtotal);
    final totalQty = items.fold<int>(0, (sum, item) => sum + item.quantity);

    // Kaldırma işlemini swipe (Dismissible) ve X butonu paylaşır — "Geri Al"
    // aksiyonlu SnackBar ile mevcut cartProvider.add() üzerinden geri eklenir.
    void removeItem(CartItem item) {
      ref.read(cartProvider.notifier).remove(item.product.id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${item.product.name} sepetten çıkarıldı'),
          action: SnackBarAction(
            label: 'Geri Al',
            onPressed: () => ref
                .read(cartProvider.notifier)
                .add(item.product, quantity: item.quantity),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: const StoreAppBar(),
      body: items.isEmpty
          ? StoreEmptyState(
              icon: Icons.shopping_cart_outlined,
              message: 'Sepetiniz boş',
              ctaLabel: 'Alışverişe Başla',
              onCta: () => context.go('/'),
            )
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 700),
                child: Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16), // space.lg
                        itemCount: items.length,
                        itemBuilder: (context, i) {
                          final item = items[i];
                          return Dismissible(
                            key: ValueKey(item.product.id),
                            direction: DismissDirection.endToStart,
                            background: const SizedBox.shrink(),
                            secondaryBackground: Container(
                              margin: const EdgeInsets.only(
                                bottom: 12,
                              ), // space.md
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20, // space.xl
                              ),
                              decoration: BoxDecoration(
                                color: StoreColors.danger,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              alignment: Alignment.centerRight,
                              child: const Icon(
                                Icons.delete_outline,
                                color: Colors.white,
                              ),
                            ),
                            onDismissed: (_) => removeItem(item),
                            child: Container(
                              margin: const EdgeInsets.only(
                                bottom: 12,
                              ), // space.md
                              padding: const EdgeInsets.all(12), // space.md
                              decoration: BoxDecoration(
                                color: StoreColors.cardBg,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: StoreColors.border),
                                boxShadow: [
                                  BoxShadow(
                                    color: StoreColors.navy.withValues(
                                      alpha: 0.05,
                                    ),
                                    blurRadius: 10,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  // < ~420: görsel(56) + miktar(~88) +
                                  // tutar(84) + kaldır(~48) + container
                                  // padding(24) sabit öğeleri ürün adına
                                  // neredeyse yer bırakmıyordu (375px'te
                                  // ~19px) — product_detail_screen.dart'taki
                                  // 640px narrow-breakpoint deseniyle
                                  // tutarlı şekilde iki satıra bölünür.
                                  final narrow = constraints.maxWidth < 420;

                                  final image = ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: SizedBox(
                                      width: 56,
                                      height: 56,
                                      child: item.product.imageUrl != null
                                          ? CachedNetworkImage(
                                              imageUrl:
                                                  item.product.imageUrl!,
                                              fit: BoxFit.cover,
                                              placeholder: (context, url) =>
                                                  const StoreShimmer(
                                                    child: SkeletonBox(
                                                      width: 56,
                                                      height: 56,
                                                      borderRadius:
                                                          BorderRadius.all(
                                                            Radius.circular(8),
                                                          ),
                                                    ),
                                                  ),
                                              errorWidget:
                                                  (context, url, error) =>
                                                      Container(
                                                        color: StoreColors
                                                            .pageBg,
                                                        child: const Icon(
                                                          Icons
                                                              .image_not_supported_outlined,
                                                          color: StoreColors
                                                              .textMuted,
                                                        ),
                                                      ),
                                            )
                                          : Container(
                                              color: StoreColors.pageBg,
                                              child: const Icon(
                                                Icons
                                                    .image_not_supported_outlined,
                                                color: StoreColors.textMuted,
                                              ),
                                            ),
                                    ),
                                  );

                                  final nameAndPrice = Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.product.name,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13.5,
                                        ),
                                      ),
                                      const SizedBox(height: 4), // space.xs
                                      Text(
                                        formatCurrency(item.product.price),
                                        style: const TextStyle(
                                          color: StoreColors.textMuted,
                                          fontSize: 12.5,
                                        ),
                                      ),
                                    ],
                                  );

                                  final qtyControl = _QtyControl(
                                    quantity: item.quantity,
                                    onChanged: (q) => ref
                                        .read(cartProvider.notifier)
                                        .setQuantity(item.product.id, q),
                                  );

                                  Text amountText({
                                    required TextAlign align,
                                  }) => Text(
                                    formatCurrency(item.subtotal),
                                    textAlign: align,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: StoreColors.navy,
                                    ),
                                  );

                                  final removeButton = IconButton(
                                    onPressed: () => removeItem(item),
                                    icon: const Icon(Icons.close, size: 18),
                                    style: IconButton.styleFrom(
                                      foregroundColor: StoreColors.danger,
                                      overlayColor: StoreColors.danger
                                          .withValues(alpha: 0.06),
                                    ),
                                  );

                                  if (narrow) {
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            image,
                                            const SizedBox(
                                              width: 12,
                                            ), // space.md
                                            Expanded(child: nameAndPrice),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        Row(
                                          children: [
                                            qtyControl,
                                            const Spacer(),
                                            amountText(align: TextAlign.left),
                                            removeButton,
                                          ],
                                        ),
                                      ],
                                    );
                                  }

                                  return Row(
                                    children: [
                                      image,
                                      const SizedBox(width: 12), // space.md
                                      Expanded(child: nameAndPrice),
                                      qtyControl,
                                      const SizedBox(width: 12), // space.md
                                      SizedBox(
                                        width: 84,
                                        child: amountText(
                                          align: TextAlign.right,
                                        ),
                                      ),
                                      removeButton,
                                    ],
                                  );
                                },
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(20), // space.xl
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        border: Border(
                          top: BorderSide(color: StoreColors.border),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Ara Toplam ($totalQty adet)',
                                style: const TextStyle(
                                  color: StoreColors.textMuted,
                                  fontSize: 13,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                formatCurrency(total),
                                style: const TextStyle(
                                  color: StoreColors.textPrimary,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8), // space.sm
                          const Divider(height: 1, color: StoreColors.border),
                          const SizedBox(height: 8), // space.sm
                          Row(
                            children: [
                              const Text(
                                'Toplam',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                formatCurrency(total),
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: StoreColors.navy,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16), // space.lg
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
        SizedBox(
          width: 24,
          child: Text('$quantity', textAlign: TextAlign.center),
        ),
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
