import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/formatters.dart';
import '../core/theme.dart';
import '../data/models/store_product.dart';
import 'skeleton_box.dart';

// Editoryal ürün kartı (design-tokens.md §15) — dikey 3:4 görsel + sabit
// yükseklikli metin bloğu (kategori + başlık + fiyat). Palet/kimlik KORUNDU
// (lacivert+altın) — yalnız YAPI (görsel oranı, hover quick-add barı) COS/
// Ferm Living gibi editoryal referanslara göre yenilendi.
class ProductCard extends StatefulWidget {
  final StoreProduct product;
  final String? categoryName;
  final VoidCallback onAddToCart;

  // ProductGrid'in aspectRatio hesabıyla BİREBİR aynı sabit — burada değişirse
  // orada da değişmeli (bkz. product_grid.dart _cellAspectRatio).
  static const double textBlockHeight = 96;

  const ProductCard({
    super.key,
    required this.product,
    required this.onAddToCart,
    this.categoryName,
  });

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  bool _hovered = false;

  // Dokunmatik ekranda hover hiç tetiklenmez — quick-add barı o zaman
  // GİZLİ kalmamalı (a11y/kullanılabilirlik). >=1024 (masaüstü/fare
  // varsayımı) hover'a bağlı slide-up; altında bar her zaman görünür.
  bool get _isPointerWidth => MediaQuery.sizeOf(context).width >= 1024;

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final showQuickAdd = _hovered || !_isPointerWidth;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Semantics(
        button: true,
        label:
            '${product.name}, ${formatCurrency(product.price)}'
            '${product.inStock ? '' : ', stokta yok'}',
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
                AspectRatio(
                  aspectRatio: 3 / 4,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // İkinci ürün görseli veri modelinde yok (StoreProduct
                      // tek image_url taşır) — hover dinamiği görsel takas
                      // yerine hafif bir yakınlaştırma (zoom) ile karşılanır.
                      AnimatedScale(
                        scale: _hovered ? 1.06 : 1.0,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
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
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: AnimatedSlide(
                          offset: showQuickAdd ? Offset.zero : const Offset(0, 1),
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOut,
                          child: _QuickAddBar(
                            enabled: product.inStock,
                            onTap: widget.onAddToCart,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: ProductCard.textBlockHeight,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (widget.categoryName != null) ...[
                          Text(
                            widget.categoryName!.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.8,
                              color: StoreColors.textMuted,
                            ),
                          ),
                          const SizedBox(height: 4),
                        ],
                        Text(
                          product.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.left,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: StoreColors.textPrimary,
                            height: 1.25,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          formatCurrency(product.price),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: StoreColors.navy,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Görsel alanının altına yaslanan, hover'da (veya dokunmatikte her zaman)
// beliren birincil aksiyon barı — §6'daki dolu-navy birincil buton diliyle
// aynı, yalnız kart görselinin İÇİNDE yaşıyor.
class _QuickAddBar extends StatelessWidget {
  final bool enabled;
  final VoidCallback onTap;

  const _QuickAddBar({required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: enabled ? 'Sepete ekle' : 'Stokta yok',
      child: Material(
        color: enabled
            ? StoreColors.navy.withValues(alpha: 0.94)
            : StoreColors.textMuted.withValues(alpha: 0.55),
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: Container(
            height: 40,
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.add_shopping_cart_outlined,
                  size: 16,
                  color: Colors.white,
                ),
                const SizedBox(width: 8),
                Text(
                  enabled ? 'Sepete Ekle' : 'Tükendi',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
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
