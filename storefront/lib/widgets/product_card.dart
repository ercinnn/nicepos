import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/formatters.dart';
import '../core/theme.dart';
import '../data/models/store_product.dart';

class ProductCard extends StatelessWidget {
  final StoreProduct product;
  final VoidCallback onAddToCart;

  const ProductCard({super.key, required this.product, required this.onAddToCart});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.go('/urun/${product.id}'),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: BoxDecoration(
          color: StoreColors.cardBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: StoreColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: product.imageUrl != null
                        ? Image.network(
                            product.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stack) => const _ImagePlaceholder(),
                          )
                        : const _ImagePlaceholder(),
                  ),
                  if (!product.inStock)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: StoreColors.danger,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('Tükendi', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
              child: Text(
                product.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: StoreColors.textPrimary),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      formatCurrency(product.price),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: StoreColors.navy),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Sepete ekle',
                    onPressed: product.inStock ? onAddToCart : null,
                    icon: const Icon(Icons.add_shopping_cart_outlined, size: 20),
                    style: IconButton.styleFrom(
                      backgroundColor: StoreColors.navy.withValues(alpha: 0.06),
                      foregroundColor: StoreColors.navy,
                    ),
                    constraints: const BoxConstraints.tightFor(width: 36, height: 36),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: StoreColors.pageBg,
      alignment: Alignment.center,
      child: const Icon(Icons.image_not_supported_outlined, color: StoreColors.textMuted, size: 32),
    );
  }
}
