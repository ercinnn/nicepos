import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/formatters.dart';
import '../core/theme.dart';
import '../data/models/store_product.dart';
import 'skeleton_box.dart';

class ProductCard extends StatefulWidget {
  final StoreProduct product;
  final VoidCallback onAddToCart;

  const ProductCard({
    super.key,
    required this.product,
    required this.onAddToCart,
  });

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: InkWell(
        onTap: () => context.go('/urun/${product.id}'),
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          transform: Matrix4.translationValues(0, _hovered ? -3 : 0, 0),
          decoration: BoxDecoration(
            color: StoreColors.cardBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _hovered
                  ? StoreColors.gold.withValues(alpha: 0.7)
                  : StoreColors.border,
            ),
            boxShadow: _hovered
                ? [
                    BoxShadow(
                      color: StoreColors.navy.withValues(alpha: 0.14),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : const [],
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
                          ? CachedNetworkImage(
                              imageUrl: product.imageUrl!,
                              fit: BoxFit.cover,
                              fadeInDuration: const Duration(milliseconds: 150),
                              placeholder: (context, url) => StoreShimmer(
                                child: const SkeletonBox(
                                  borderRadius: BorderRadius.zero,
                                ),
                              ),
                              errorWidget: (context, url, error) =>
                                  const _ImagePlaceholder(),
                            )
                          : const _ImagePlaceholder(),
                    ),
                    if (!product.inStock)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: StoreColors.danger,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Tükendi',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
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
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: StoreColors.textPrimary,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        formatCurrency(product.price),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: StoreColors.navy,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Sepete ekle',
                      onPressed: product.inStock ? widget.onAddToCart : null,
                      icon: const Icon(
                        Icons.add_shopping_cart_outlined,
                        size: 20,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: StoreColors.navy.withValues(
                          alpha: 0.06,
                        ),
                        foregroundColor: StoreColors.navy,
                      ),
                      constraints: const BoxConstraints.tightFor(
                        width: 36,
                        height: 36,
                      ),
                      padding: EdgeInsets.zero,
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

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: StoreColors.pageBg,
      alignment: Alignment.center,
      child: const Icon(
        Icons.image_not_supported_outlined,
        color: StoreColors.textMuted,
        size: 32,
      ),
    );
  }
}
