import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/store_category.dart';
import '../data/models/store_product.dart';
import 'cart_provider.dart';

final categoriesProvider = FutureProvider<List<StoreCategory>>((ref) async {
  return ref.watch(storeRepositoryProvider).fetchCategories();
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
  return ref
      .watch(storeRepositoryProvider)
      .fetchProducts(query: filter.query, groupId: filter.groupId);
});
