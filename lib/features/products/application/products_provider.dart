import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../data/local/reference_cache_dao.dart';
import '../data/models/product.dart';
import '../data/models/product_group.dart';
import '../data/models/company.dart';
import '../data/repositories/product_repository.dart';
import '../data/repositories/product_group_repository.dart';
import '../data/repositories/company_repository.dart';

part 'products_provider.g.dart';

const kProductPageSize = 50;

@Riverpod(keepAlive: true)
ProductRepository productRepository(ProductRepositoryRef ref) => ProductRepository();

@Riverpod(keepAlive: true)
ProductGroupRepository productGroupRepository(ProductGroupRepositoryRef ref) => ProductGroupRepository();

// Mobil çevrimdışı destek: Ürün Grubu dropdown'ı offline'da boş kalmasın diye
// canlı sorgu başarısız olursa (!kIsWeb) yerel önbelleğe düşer — cihaz hiç
// senkron olmadıysa cache de boş döner, bu durumda dropdown zaten mevcut
// "grup yok" davranışına (SizedBox) düşer, yeni bir hata durumu eklemez.
@riverpod
Future<List<ProductGroup>> productGroups(ProductGroupsRef ref) async {
  try {
    return await ref.watch(productGroupRepositoryProvider).fetchAll();
  } catch (e) {
    if (kIsWeb) rethrow;
    return ref.watch(referenceCacheDaoProvider).fetchGroups();
  }
}

@Riverpod(keepAlive: true)
CompanyRepository companyRepository(CompanyRepositoryRef ref) =>
    CompanyRepository();

// Firma serbest-metin alanı olduğu için offline'da otomatik tamamlama
// önerisi olmasa da yazılabilir kalır — yine de mümkünse cache'ten doldurulur.
@riverpod
Future<List<Company>> companies(CompaniesRef ref) async {
  try {
    return await ref.watch(companyRepositoryProvider).fetchAll();
  } catch (e) {
    if (kIsWeb) rethrow;
    return ref.watch(referenceCacheDaoProvider).fetchCompanies();
  }
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
