// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'products_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$productRepositoryHash() => r'c04203ee84ecd5f33fdce58bd64f7ae1ecf91dc2';

/// See also [productRepository].
@ProviderFor(productRepository)
final productRepositoryProvider = Provider<ProductRepository>.internal(
  productRepository,
  name: r'productRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$productRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ProductRepositoryRef = ProviderRef<ProductRepository>;
String _$productGroupRepositoryHash() =>
    r'1d8fc51a53ba2483dab53100570faf306df383ca';

/// See also [productGroupRepository].
@ProviderFor(productGroupRepository)
final productGroupRepositoryProvider =
    Provider<ProductGroupRepository>.internal(
      productGroupRepository,
      name: r'productGroupRepositoryProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$productGroupRepositoryHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ProductGroupRepositoryRef = ProviderRef<ProductGroupRepository>;
String _$productGroupsHash() => r'df46c68379172513479caa7fdabfd6dfb4fd3683';

/// See also [productGroups].
@ProviderFor(productGroups)
final productGroupsProvider =
    AutoDisposeFutureProvider<List<ProductGroup>>.internal(
      productGroups,
      name: r'productGroupsProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$productGroupsHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ProductGroupsRef = AutoDisposeFutureProviderRef<List<ProductGroup>>;
String _$companyRepositoryHash() => r'c86e7056148cee76d008875cb39ed555b231fd03';

/// See also [companyRepository].
@ProviderFor(companyRepository)
final companyRepositoryProvider = Provider<CompanyRepository>.internal(
  companyRepository,
  name: r'companyRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$companyRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef CompanyRepositoryRef = ProviderRef<CompanyRepository>;
String _$companiesHash() => r'47b2e5180a43ecaf382a0b9def80a7a840d1c8eb';

/// See also [companies].
@ProviderFor(companies)
final companiesProvider = AutoDisposeFutureProvider<List<Company>>.internal(
  companies,
  name: r'companiesProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$companiesHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef CompaniesRef = AutoDisposeFutureProviderRef<List<Company>>;
String _$productByIdHash() => r'97ee5f6966e1f971153247c89ad19cd99b10b8f7';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

/// See also [productById].
@ProviderFor(productById)
const productByIdProvider = ProductByIdFamily();

/// See also [productById].
class ProductByIdFamily extends Family<AsyncValue<Product?>> {
  /// See also [productById].
  const ProductByIdFamily();

  /// See also [productById].
  ProductByIdProvider call(String id) {
    return ProductByIdProvider(id);
  }

  @override
  ProductByIdProvider getProviderOverride(
    covariant ProductByIdProvider provider,
  ) {
    return call(provider.id);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'productByIdProvider';
}

/// See also [productById].
class ProductByIdProvider extends AutoDisposeFutureProvider<Product?> {
  /// See also [productById].
  ProductByIdProvider(String id)
    : this._internal(
        (ref) => productById(ref as ProductByIdRef, id),
        from: productByIdProvider,
        name: r'productByIdProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$productByIdHash,
        dependencies: ProductByIdFamily._dependencies,
        allTransitiveDependencies: ProductByIdFamily._allTransitiveDependencies,
        id: id,
      );

  ProductByIdProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.id,
  }) : super.internal();

  final String id;

  @override
  Override overrideWith(
    FutureOr<Product?> Function(ProductByIdRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: ProductByIdProvider._internal(
        (ref) => create(ref as ProductByIdRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        id: id,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<Product?> createElement() {
    return _ProductByIdProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ProductByIdProvider && other.id == id;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, id.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin ProductByIdRef on AutoDisposeFutureProviderRef<Product?> {
  /// The parameter `id` of this provider.
  String get id;
}

class _ProductByIdProviderElement
    extends AutoDisposeFutureProviderElement<Product?>
    with ProductByIdRef {
  _ProductByIdProviderElement(super.provider);

  @override
  String get id => (origin as ProductByIdProvider).id;
}

String _$productsByGroupHash() => r'28e48f2e72332adbb0aff17ff8e3d0407983665f';

/// See also [productsByGroup].
@ProviderFor(productsByGroup)
const productsByGroupProvider = ProductsByGroupFamily();

/// See also [productsByGroup].
class ProductsByGroupFamily extends Family<AsyncValue<List<Product>>> {
  /// See also [productsByGroup].
  const ProductsByGroupFamily();

  /// See also [productsByGroup].
  ProductsByGroupProvider call(String groupId) {
    return ProductsByGroupProvider(groupId);
  }

  @override
  ProductsByGroupProvider getProviderOverride(
    covariant ProductsByGroupProvider provider,
  ) {
    return call(provider.groupId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'productsByGroupProvider';
}

/// See also [productsByGroup].
class ProductsByGroupProvider extends AutoDisposeFutureProvider<List<Product>> {
  /// See also [productsByGroup].
  ProductsByGroupProvider(String groupId)
    : this._internal(
        (ref) => productsByGroup(ref as ProductsByGroupRef, groupId),
        from: productsByGroupProvider,
        name: r'productsByGroupProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$productsByGroupHash,
        dependencies: ProductsByGroupFamily._dependencies,
        allTransitiveDependencies:
            ProductsByGroupFamily._allTransitiveDependencies,
        groupId: groupId,
      );

  ProductsByGroupProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.groupId,
  }) : super.internal();

  final String groupId;

  @override
  Override overrideWith(
    FutureOr<List<Product>> Function(ProductsByGroupRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: ProductsByGroupProvider._internal(
        (ref) => create(ref as ProductsByGroupRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        groupId: groupId,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<List<Product>> createElement() {
    return _ProductsByGroupProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ProductsByGroupProvider && other.groupId == groupId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, groupId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin ProductsByGroupRef on AutoDisposeFutureProviderRef<List<Product>> {
  /// The parameter `groupId` of this provider.
  String get groupId;
}

class _ProductsByGroupProviderElement
    extends AutoDisposeFutureProviderElement<List<Product>>
    with ProductsByGroupRef {
  _ProductsByGroupProviderElement(super.provider);

  @override
  String get groupId => (origin as ProductsByGroupProvider).groupId;
}

String _$pagedProductsHash() => r'9f1a1127209f7da61ac80cde8f3429d42a490618';

/// See also [pagedProducts].
@ProviderFor(pagedProducts)
const pagedProductsProvider = PagedProductsFamily();

/// See also [pagedProducts].
class PagedProductsFamily extends Family<AsyncValue<List<Product>>> {
  /// See also [pagedProducts].
  const PagedProductsFamily();

  /// See also [pagedProducts].
  PagedProductsProvider call(ProductsQuery q) {
    return PagedProductsProvider(q);
  }

  @override
  PagedProductsProvider getProviderOverride(
    covariant PagedProductsProvider provider,
  ) {
    return call(provider.q);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'pagedProductsProvider';
}

/// See also [pagedProducts].
class PagedProductsProvider extends AutoDisposeFutureProvider<List<Product>> {
  /// See also [pagedProducts].
  PagedProductsProvider(ProductsQuery q)
    : this._internal(
        (ref) => pagedProducts(ref as PagedProductsRef, q),
        from: pagedProductsProvider,
        name: r'pagedProductsProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$pagedProductsHash,
        dependencies: PagedProductsFamily._dependencies,
        allTransitiveDependencies:
            PagedProductsFamily._allTransitiveDependencies,
        q: q,
      );

  PagedProductsProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.q,
  }) : super.internal();

  final ProductsQuery q;

  @override
  Override overrideWith(
    FutureOr<List<Product>> Function(PagedProductsRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: PagedProductsProvider._internal(
        (ref) => create(ref as PagedProductsRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        q: q,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<List<Product>> createElement() {
    return _PagedProductsProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is PagedProductsProvider && other.q == q;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, q.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin PagedProductsRef on AutoDisposeFutureProviderRef<List<Product>> {
  /// The parameter `q` of this provider.
  ProductsQuery get q;
}

class _PagedProductsProviderElement
    extends AutoDisposeFutureProviderElement<List<Product>>
    with PagedProductsRef {
  _PagedProductsProviderElement(super.provider);

  @override
  ProductsQuery get q => (origin as PagedProductsProvider).q;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
