// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sales_cart_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$salesRepositoryHash() => r'553e650b141667b60740fe99da9d820083bd5233';

/// See also [salesRepository].
@ProviderFor(salesRepository)
final salesRepositoryProvider = Provider<SalesRepository>.internal(
  salesRepository,
  name: r'salesRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$salesRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef SalesRepositoryRef = ProviderRef<SalesRepository>;
String _$salesCartHash() => r'2fb955cc3747638b8c84d5c7535b4b3f30d63b2b';

/// See also [SalesCart].
@ProviderFor(SalesCart)
final salesCartProvider = NotifierProvider<SalesCart, SalesState>.internal(
  SalesCart.new,
  name: r'salesCartProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$salesCartHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$SalesCart = Notifier<SalesState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
