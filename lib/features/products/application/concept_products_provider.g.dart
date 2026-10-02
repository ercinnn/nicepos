// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'concept_products_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$conceptRepositoryHash() => r'082fbd6b02dff0afa966d1eac65b0b098c345818';

/// See also [conceptRepository].
@ProviderFor(conceptRepository)
final conceptRepositoryProvider = Provider<ConceptRepository>.internal(
  conceptRepository,
  name: r'conceptRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$conceptRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ConceptRepositoryRef = ProviderRef<ConceptRepository>;
String _$conceptProductsHash() => r'0585e94000e54c6c12eee3dbdaa870ce6747c4da';

/// Konsept Ürünler sekmesinin listesi — her açılışta taze (autoDispose).
///
/// Copied from [conceptProducts].
@ProviderFor(conceptProducts)
final conceptProductsProvider =
    AutoDisposeFutureProvider<List<ConceptProduct>>.internal(
      conceptProducts,
      name: r'conceptProductsProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$conceptProductsHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ConceptProductsRef = AutoDisposeFutureProviderRef<List<ConceptProduct>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
