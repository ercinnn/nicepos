import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../state/cart_provider.dart';
import '../../state/catalog_provider.dart';
import '../../widgets/product_card.dart';
import '../../widgets/store_app_bar.dart';
import '../../widgets/store_footer.dart';
import '../../widgets/store_hero_banner.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      final filter = ref.read(catalogFilterProvider);
      ref.read(catalogFilterProvider.notifier).state = filter.copyWith(
        query: value,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(catalogFilterProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final productsAsync = ref.watch(catalogProductsProvider);

    return Scaffold(
      appBar: StoreAppBar(
        searchField: TextField(
          controller: _searchController,
          onChanged: _onSearchChanged,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Ürün ara...',
            hintStyle: const TextStyle(color: Colors.white70),
            prefixIcon: const Icon(Icons.search, color: Colors.white70),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            isDense: true,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const StoreHeroBanner(),
            categoriesAsync.when(
              loading: () => const SizedBox(height: 64),
              error: (e, _) => const SizedBox.shrink(),
              data: (categories) {
                if (categories.isEmpty) return const SizedBox(height: 8);
                // 200+ kategori tek satır yatay kaydırmaya sığmıyor (yalnız
                // 10-12'si görünüyordu) — Wrap ile alt sıralara geçer. Hepsi
                // birden açık kalırsa sayfa aşırı uzayacağından sabit yükseklikli
                // bir alanda (yaklaşık 3 satır) dikey kaydırmalı gösterilir.
                return Container(
                  constraints: const BoxConstraints(maxHeight: 168),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _CategoryChip(
                          label: 'Tümü',
                          selected: filter.groupId == null,
                          onTap: () =>
                              ref.read(catalogFilterProvider.notifier).state =
                                  filter.copyWith(clearGroup: true),
                        ),
                        for (final category in categories)
                          _CategoryChip(
                            label: category.name,
                            selected: filter.groupId == category.id,
                            onTap: () =>
                                ref.read(catalogFilterProvider.notifier).state =
                                    filter.copyWith(groupId: category.id),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const Divider(height: 1, color: StoreColors.border),
            productsAsync.when(
              loading: () => const SizedBox(
                height: 320,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => SizedBox(
                height: 200,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Ürünler yüklenemedi: $e',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
              data: (products) {
                if (products.isEmpty) {
                  return const SizedBox(
                    height: 200,
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Bu kriterlere uygun ürün bulunamadı',
                          style: TextStyle(color: StoreColors.textMuted),
                        ),
                      ),
                    ),
                  );
                }
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 220,
                    mainAxisExtent: 250,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: products.length,
                  itemBuilder: (context, i) {
                    final product = products[i];
                    return ProductCard(
                      product: product,
                      onAddToCart: () {
                        ref.read(cartProvider.notifier).add(product);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${product.name} sepete eklendi'),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 24),
            const StoreFooter(),
          ],
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: StoreColors.navy,
      labelStyle: TextStyle(
        color: selected ? Colors.white : StoreColors.textPrimary,
        fontSize: 12.5,
      ),
      backgroundColor: Colors.white,
      side: BorderSide(color: selected ? StoreColors.navy : StoreColors.border),
    );
  }
}
