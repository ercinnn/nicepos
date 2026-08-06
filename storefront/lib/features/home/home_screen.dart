import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../state/cart_provider.dart';
import '../../state/catalog_provider.dart';
import '../../widgets/product_card.dart';
import '../../widgets/store_app_bar.dart';

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
      ref.read(catalogFilterProvider.notifier).state = filter.copyWith(query: value);
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
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
            isDense: true,
          ),
        ),
      ),
      body: Column(
        children: [
          categoriesAsync.when(
            loading: () => const SizedBox(height: 48),
            error: (e, _) => const SizedBox.shrink(),
            data: (categories) {
              if (categories.isEmpty) return const SizedBox(height: 8);
              return SizedBox(
                height: 52,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  children: [
                    _CategoryChip(
                      label: 'Tümü',
                      selected: filter.groupId == null,
                      onTap: () => ref.read(catalogFilterProvider.notifier).state = filter.copyWith(clearGroup: true),
                    ),
                    const SizedBox(width: 8),
                    for (final category in categories) ...[
                      _CategoryChip(
                        label: category.name,
                        selected: filter.groupId == category.id,
                        onTap: () => ref.read(catalogFilterProvider.notifier).state = filter.copyWith(groupId: category.id),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              );
            },
          ),
          const Divider(height: 1, color: StoreColors.border),
          Expanded(
            child: productsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Ürünler yüklenemedi: $e', textAlign: TextAlign.center),
                ),
              ),
              data: (products) {
                if (products.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('Bu kriterlere uygun ürün bulunamadı', style: TextStyle(color: StoreColors.textMuted)),
                    ),
                  );
                }
                return GridView.builder(
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
                          SnackBar(content: Text('${product.name} sepete eklendi'), duration: const Duration(seconds: 1)),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: StoreColors.navy,
      labelStyle: TextStyle(color: selected ? Colors.white : StoreColors.textPrimary, fontSize: 12.5),
      backgroundColor: Colors.white,
      side: BorderSide(color: selected ? StoreColors.navy : StoreColors.border),
    );
  }
}
