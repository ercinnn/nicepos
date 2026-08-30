import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/store_product.dart';
import 'product_card.dart';
import 'skeleton_box.dart';
import 'store_empty_state.dart';

// Editoryal ürün ızgarası (design-tokens.md §15) — tam olarak 1/2/4 kolon
// (mobil/`sm`/`lg`), gap `space.xxl` (24). Kolon SAYISI çağıran taraftan
// (`columns`) gelir — bu widget'ın kendi genişliği (masaüstünde sidebar'ın
// yanında daralmış olabilir) tailwind'in `sm`/`lg` breakpoint'lerinin GERÇEK
// referansı olan VIEWPORT genişliğiyle karışmasın diye (bkz. home_screen.dart
// `_columnsForWidth`).
class ProductGrid extends StatelessWidget {
  final AsyncValue<List<StoreProduct>> productsAsync;
  final Map<String, String> categoryNames;
  final String searchQuery;
  final int columns;
  final void Function(StoreProduct) onAddToCart;

  static const double gap = 24; // space.xxl — Tailwind gap-6

  const ProductGrid({
    super.key,
    required this.productsAsync,
    required this.categoryNames,
    required this.searchQuery,
    required this.columns,
    required this.onAddToCart,
  });

  @override
  Widget build(BuildContext context) {
    return productsAsync.when(
      loading: () => _buildGrid(
        itemCount: 8,
        itemBuilder: (context, i) => const SkeletonProductCard(),
      ),
      error: (e, _) => SizedBox(
        height: 240,
        child: StoreEmptyState(
          icon: Icons.error_outline,
          message: 'Ürünler yüklenemedi: $e',
        ),
      ),
      data: (products) {
        if (products.isEmpty) {
          final query = searchQuery.trim();
          return SizedBox(
            height: 240,
            child: StoreEmptyState(
              icon: query.isNotEmpty
                  ? Icons.search_off_outlined
                  : Icons.inventory_2_outlined,
              message: query.isNotEmpty
                  ? '"$query" için sonuç yok'
                  : 'Bu kategoride ürün yok',
            ),
          );
        }
        return _buildGrid(
          itemCount: products.length,
          itemBuilder: (context, i) {
            final product = products[i];
            return ProductCard(
              product: product,
              categoryName:
                  product.groupId == null ? null : categoryNames[product.groupId],
              onAddToCart: () => onAddToCart(product),
            );
          },
        );
      },
    );
  }

  Widget _buildGrid({
    required int itemCount,
    required Widget Function(BuildContext, int) itemBuilder,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // `constraints.maxWidth` GridView'ın KENDİ `padding`'inden ÖNCEki
        // genişlik — asıl hücre genişliği o dolgu düşüldükten sonraki alandan
        // hesaplanmalı, aksi halde childAspectRatio hafif yanlış (dar) çıkar.
        const gridPadding = EdgeInsets.all(24); // space.xxl
        final contentWidth = constraints.maxWidth - gridPadding.horizontal;
        final cellWidth = (contentWidth - gap * (columns - 1)) / columns;
        // +6: kart kenarlığının (Container'ın örtük border-inset padding'i)
        // ve font metrik yuvarlamalarının payı — QA testinde (bkz. storefront
        // deploy notları) yakalanan gerçek bir taşma hatasına karşı güvenlik.
        final cellHeight = cellWidth * 4 / 3 + ProductCard.textBlockHeight + 6;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: gridPadding,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: gap,
            mainAxisSpacing: gap,
            childAspectRatio: cellWidth / cellHeight,
          ),
          itemCount: itemCount,
          itemBuilder: itemBuilder,
        );
      },
    );
  }
}
