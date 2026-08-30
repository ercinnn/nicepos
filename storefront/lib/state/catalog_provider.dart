import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/store_category.dart';
import '../data/models/store_product.dart';
import 'cart_provider.dart';
import 'tenant_provider.dart';

final categoriesProvider = FutureProvider<List<StoreCategory>>((ref) async {
  final tenantId = ref.watch(currentTenantProvider).id;
  return ref.watch(storeRepositoryProvider).fetchCategories(tenantId: tenantId);
});

final _activeCategoryIdsProvider = FutureProvider<Set<String>>((ref) async {
  final tenantId = ref.watch(currentTenantProvider).id;
  return ref.watch(storeRepositoryProvider).fetchActiveCategoryIds(tenantId);
});

// Yalnız online-aktif ürünü OLAN kategoriler — filtre UI'sında (FilterSidebar
// + mobil chip şeridi) gösterilecek liste budur, ham `categoriesProvider`
// DEĞİL (kullanıcı isteği: boş kategori filtre olarak görünmesin).
final visibleCategoriesProvider = FutureProvider<List<StoreCategory>>((ref) async {
  final categories = await ref.watch(categoriesProvider.future);
  final activeIds = await ref.watch(_activeCategoryIdsProvider.future);
  return categories.where((c) => activeIds.contains(c.id)).toList();
});

class CatalogFilter {
  final String query;
  final String? groupId;

  const CatalogFilter({this.query = '', this.groupId});

  CatalogFilter copyWith({
    String? query,
    String? groupId,
    bool clearGroup = false,
  }) {
    return CatalogFilter(
      query: query ?? this.query,
      groupId: clearGroup ? null : (groupId ?? this.groupId),
    );
  }
}

final catalogFilterProvider = StateProvider<CatalogFilter>(
  (ref) => const CatalogFilter(),
);

final catalogProductsProvider = FutureProvider<List<StoreProduct>>((ref) async {
  final filter = ref.watch(catalogFilterProvider);
  final tenantId = ref.watch(currentTenantProvider).id;
  return ref
      .watch(storeRepositoryProvider)
      .fetchProducts(tenantId: tenantId, query: filter.query, groupId: filter.groupId);
});
