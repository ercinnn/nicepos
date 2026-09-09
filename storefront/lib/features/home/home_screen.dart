import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../data/models/store_category.dart';
import '../../data/models/store_product.dart';
import '../../state/cart_provider.dart';
import '../../state/catalog_provider.dart';
import '../../state/tenant_provider.dart';
import '../../widgets/filter_sidebar.dart';
import '../../widgets/product_grid.dart';
import '../../widgets/skeleton_box.dart';
import '../../widgets/store_app_bar.dart';
import '../../widgets/store_footer.dart';
import '../../widgets/store_hero_banner.dart';

// Tailwind referans breakpoint'leri (promptta birebir istendiği gibi): sm=640
// (2 kolon), lg=1024 (4 kolon + sol sidebar). Kolon SAYISI viewport'a göre
// burada (sayfa seviyesinde) karar verilir — ProductGrid'in kendi genişliği
// masaüstünde sidebar'ın yanında daralmış olabileceğinden (bkz. product_grid.
// dart üstündeki not), breakpoint kararını KENDİ yerel genişliğine göre
// vermesi yanlış olurdu.
int _columnsForWidth(double width) {
  if (width >= 1024) return 4;
  if (width >= 640) return 2;
  return 1;
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  // Dar ekranda (<600) arama satırının açık/kapalı durumu — bkz.
  // store_app_bar.dart üstündeki not: bu state StoreAppBar'ın DEĞİL, üst
  // ekranın kendisinde yaşamak zorunda (aksi halde Scaffold'un dinamik
  // AppBar yüksekliğini fark etmesi için gereken yeniden derleme tetiklenmez).
  bool _searchExpanded = false;

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
    // Ad çözümlemesi (categoryNames) TÜM kategorilerden — filtre UI'sında
    // GÖSTERİLECEK liste ise yalnız online-aktif ürünü olanlar
    // (visibleCategoriesProvider, kullanıcı isteği: boş kategori filtre
    // olarak görünmesin).
    final allCategoriesAsync = ref.watch(categoriesProvider);
    final visibleCategoriesAsync = ref.watch(visibleCategoriesProvider);
    final productsAsync = ref.watch(catalogProductsProvider);
    final imageAspectRatio = ref.watch(currentTenantProvider).imageAspectRatio;
    final narrow = MediaQuery.sizeOf(context).width < 600;

    return Scaffold(
      appBar: StoreAppBar(
        narrow: narrow,
        searchExpanded: _searchExpanded,
        onToggleSearch: () =>
            setState(() => _searchExpanded = !_searchExpanded),
        searchField: ValueListenableBuilder<TextEditingValue>(
          valueListenable: _searchController,
          builder: (context, value, _) {
            return TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Ürün ara...',
                hintStyle: const TextStyle(color: Colors.white70),
                prefixIcon: const Icon(Icons.search, color: Colors.white70),
                suffixIcon: value.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Aramayı temizle',
                        icon: const Icon(
                          Icons.close,
                          color: Colors.white70,
                          size: 18,
                        ),
                        onPressed: () {
                          _debounce?.cancel();
                          _searchController.clear();
                          final current = ref.read(catalogFilterProvider);
                          ref.read(catalogFilterProvider.notifier).state =
                              current.copyWith(query: '');
                        },
                      ),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                isDense: true,
              ),
            );
          },
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // `constraints.maxWidth` burada = tam viewport genişliği (Scaffold.
          // body doğrudan LayoutBuilder'ı sarıyor, aralarında daraltan bir
          // sidebar YOK henüz) — _columnsForWidth'in Tailwind sm/lg
          // referansıyla birebir örtüşmesi için doğru ölçüm noktası budur.
          final viewportWidth = constraints.maxWidth;
          final columns = _columnsForWidth(viewportWidth);
          final showSidebar = viewportWidth >= 1024; // lg
          final allCategories = allCategoriesAsync.value ?? const <StoreCategory>[];
          final visibleCategories =
              visibleCategoriesAsync.value ?? const <StoreCategory>[];
          final categoryNames = {
            for (final category in allCategories) category.id: category.name,
          };

          void handleAddToCart(StoreProduct product) {
            ref.read(cartProvider.notifier).add(product);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${product.name} sepete eklendi'),
                duration: const Duration(seconds: 1),
              ),
            );
          }

          final grid = ProductGrid(
            productsAsync: productsAsync,
            categoryNames: categoryNames,
            searchQuery: filter.query,
            columns: columns,
            onAddToCart: handleAddToCart,
            imageAspectRatio: imageAspectRatio,
          );

          if (showSidebar) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilterSidebar(
                  categories: visibleCategories,
                  selectedGroupId: filter.groupId,
                  onSelect: (groupId) =>
                      ref.read(catalogFilterProvider.notifier).state =
                          groupId == null
                          ? filter.copyWith(clearGroup: true)
                          : filter.copyWith(groupId: groupId),
                ),
                const VerticalDivider(width: 1, color: StoreColors.border),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        const StoreHeroBanner(),
                        grid,
                        const SizedBox(height: 24),
                        const StoreFooter(),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }

          // Mobil/tablet (<1024): 256px sabit sidebar sığmaz — mevcut yatay
          // kategori chip şeridi korunur (§7, 200+ kategori taşma dersi).
          return SingleChildScrollView(
            child: Column(
              children: [
                const StoreHeroBanner(),
                visibleCategoriesAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: SkeletonChipRow(),
                  ),
                  error: (e, _) => const Padding(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Text(
                      'Kategoriler yüklenemedi',
                      style: TextStyle(
                        color: StoreColors.textMuted,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                  data: (categories) {
                    if (categories.isEmpty) return const SizedBox(height: 8);
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
                                  ref
                                      .read(catalogFilterProvider.notifier)
                                      .state = filter.copyWith(
                                    clearGroup: true,
                                  ),
                            ),
                            for (final category in categories)
                              _CategoryChip(
                                label: category.name,
                                selected: filter.groupId == category.id,
                                onTap: () =>
                                    ref
                                        .read(catalogFilterProvider.notifier)
                                        .state = filter.copyWith(
                                      groupId: category.id,
                                    ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const Divider(height: 1, color: StoreColors.border),
                grid,
                const SizedBox(height: 24),
                const StoreFooter(),
              ],
            ),
          );
        },
      ),
    );
  }
}

// design-tokens.md §7 — token'lı kategori chip'i (bare ChoiceChip yerine).
// Gold KULLANILMAZ: seçili durum navy zeminle işaretlenir.
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
    return Material(
      color: selected ? StoreColors.navy : StoreColors.cardBg,
      shape: StadiumBorder(
        side: BorderSide(
          color: selected ? StoreColors.navy : StoreColors.border,
        ),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 12, // space.md
            vertical: 4, // space.xs
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : StoreColors.textPrimary,
              fontSize: 12.5,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
