import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../data/models/product.dart';
import '../data/models/product_group.dart';
import '../data/repositories/product_repository.dart';
import '../data/repositories/product_group_repository.dart';

part 'products_provider.g.dart';

const kProductPageSize = 50;

@Riverpod(keepAlive: true)
ProductRepository productRepository(ProductRepositoryRef ref) => ProductRepository();

@Riverpod(keepAlive: true)
ProductGroupRepository productGroupRepository(ProductGroupRepositoryRef ref) => ProductGroupRepository();

@riverpod
Future<List<ProductGroup>> productGroups(ProductGroupsRef ref) {
  return ref.watch(productGroupRepositoryProvider).fetchAll();
}

@riverpod
Future<Product?> productById(ProductByIdRef ref, String id) {
  return ref.watch(productRepositoryProvider).fetchById(id);
}

@riverpod
Future<List<Product>> productsByGroup(ProductsByGroupRef ref, String groupId) {
  return ref.watch(productRepositoryProvider).fetchByGroup(groupId);
}

class ProductsQuery {
  final String? query;
  final String? groupId;
  final int page;
  final int pageSize;

  const ProductsQuery({this.query, this.groupId, this.page = 0, this.pageSize = 50});

  @override
  bool operator ==(Object other) =>
      other is ProductsQuery &&
      other.query == query &&
      other.groupId == groupId &&
      other.page == page &&
      other.pageSize == pageSize;

  @override
  int get hashCode => Object.hash(query, groupId, page, pageSize);
}

@riverpod
Future<List<Product>> pagedProducts(PagedProductsRef ref, ProductsQuery q) {
  return ref.watch(productRepositoryProvider).fetchPaged(
    query: q.query,
    groupId: q.groupId,
    page: q.page,
    pageSize: q.pageSize,
  );
}
