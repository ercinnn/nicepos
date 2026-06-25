// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'customers_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$customerRepositoryHash() =>
    r'b35534291364b1230d1e4345208b9c58af12e522';

/// See also [customerRepository].
@ProviderFor(customerRepository)
final customerRepositoryProvider = Provider<CustomerRepository>.internal(
  customerRepository,
  name: r'customerRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$customerRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef CustomerRepositoryRef = ProviderRef<CustomerRepository>;
String _$customersHash() => r'b1d838d1d466ada4c1984dff1378a41f6ce44d76';

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

/// See also [customers].
@ProviderFor(customers)
const customersProvider = CustomersFamily();

/// See also [customers].
class CustomersFamily extends Family<AsyncValue<List<Customer>>> {
  /// See also [customers].
  const CustomersFamily();

  /// See also [customers].
  CustomersProvider call(CustomersQuery q) {
    return CustomersProvider(q);
  }

  @override
  CustomersProvider getProviderOverride(covariant CustomersProvider provider) {
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
  String? get name => r'customersProvider';
}

/// See also [customers].
class CustomersProvider extends AutoDisposeFutureProvider<List<Customer>> {
  /// See also [customers].
  CustomersProvider(CustomersQuery q)
    : this._internal(
        (ref) => customers(ref as CustomersRef, q),
        from: customersProvider,
        name: r'customersProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$customersHash,
        dependencies: CustomersFamily._dependencies,
        allTransitiveDependencies: CustomersFamily._allTransitiveDependencies,
        q: q,
      );

  CustomersProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.q,
  }) : super.internal();

  final CustomersQuery q;

  @override
  Override overrideWith(
    FutureOr<List<Customer>> Function(CustomersRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: CustomersProvider._internal(
        (ref) => create(ref as CustomersRef),
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
  AutoDisposeFutureProviderElement<List<Customer>> createElement() {
    return _CustomersProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is CustomersProvider && other.q == q;
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
mixin CustomersRef on AutoDisposeFutureProviderRef<List<Customer>> {
  /// The parameter `q` of this provider.
  CustomersQuery get q;
}

class _CustomersProviderElement
    extends AutoDisposeFutureProviderElement<List<Customer>>
    with CustomersRef {
  _CustomersProviderElement(super.provider);

  @override
  CustomersQuery get q => (origin as CustomersProvider).q;
}

String _$customerByIdHash() => r'a58b96322b54899ecec4ff7f60191f21ff16ff96';

/// See also [customerById].
@ProviderFor(customerById)
const customerByIdProvider = CustomerByIdFamily();

/// See also [customerById].
class CustomerByIdFamily extends Family<AsyncValue<Customer?>> {
  /// See also [customerById].
  const CustomerByIdFamily();

  /// See also [customerById].
  CustomerByIdProvider call(String id) {
    return CustomerByIdProvider(id);
  }

  @override
  CustomerByIdProvider getProviderOverride(
    covariant CustomerByIdProvider provider,
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
  String? get name => r'customerByIdProvider';
}

/// See also [customerById].
class CustomerByIdProvider extends AutoDisposeFutureProvider<Customer?> {
  /// See also [customerById].
  CustomerByIdProvider(String id)
    : this._internal(
        (ref) => customerById(ref as CustomerByIdRef, id),
        from: customerByIdProvider,
        name: r'customerByIdProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$customerByIdHash,
        dependencies: CustomerByIdFamily._dependencies,
        allTransitiveDependencies:
            CustomerByIdFamily._allTransitiveDependencies,
        id: id,
      );

  CustomerByIdProvider._internal(
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
    FutureOr<Customer?> Function(CustomerByIdRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: CustomerByIdProvider._internal(
        (ref) => create(ref as CustomerByIdRef),
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
  AutoDisposeFutureProviderElement<Customer?> createElement() {
    return _CustomerByIdProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is CustomerByIdProvider && other.id == id;
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
mixin CustomerByIdRef on AutoDisposeFutureProviderRef<Customer?> {
  /// The parameter `id` of this provider.
  String get id;
}

class _CustomerByIdProviderElement
    extends AutoDisposeFutureProviderElement<Customer?>
    with CustomerByIdRef {
  _CustomerByIdProviderElement(super.provider);

  @override
  String get id => (origin as CustomerByIdProvider).id;
}

String _$totalCustomerDebtHash() => r'8847d7961c81995d6f1ac11691618e59969805d3';

/// See also [totalCustomerDebt].
@ProviderFor(totalCustomerDebt)
final totalCustomerDebtProvider = AutoDisposeFutureProvider<num>.internal(
  totalCustomerDebt,
  name: r'totalCustomerDebtProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$totalCustomerDebtHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef TotalCustomerDebtRef = AutoDisposeFutureProviderRef<num>;
String _$customerSalesHash() => r'd25a6ecaa9a9b8e9a3239416a1e1965bfe6b2683';

/// See also [customerSales].
@ProviderFor(customerSales)
const customerSalesProvider = CustomerSalesFamily();

/// See also [customerSales].
class CustomerSalesFamily extends Family<AsyncValue<List<Sale>>> {
  /// See also [customerSales].
  const CustomerSalesFamily();

  /// See also [customerSales].
  CustomerSalesProvider call(CustomerSalesQuery q) {
    return CustomerSalesProvider(q);
  }

  @override
  CustomerSalesProvider getProviderOverride(
    covariant CustomerSalesProvider provider,
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
  String? get name => r'customerSalesProvider';
}

/// See also [customerSales].
class CustomerSalesProvider extends AutoDisposeFutureProvider<List<Sale>> {
  /// See also [customerSales].
  CustomerSalesProvider(CustomerSalesQuery q)
    : this._internal(
        (ref) => customerSales(ref as CustomerSalesRef, q),
        from: customerSalesProvider,
        name: r'customerSalesProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$customerSalesHash,
        dependencies: CustomerSalesFamily._dependencies,
        allTransitiveDependencies:
            CustomerSalesFamily._allTransitiveDependencies,
        q: q,
      );

  CustomerSalesProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.q,
  }) : super.internal();

  final CustomerSalesQuery q;

  @override
  Override overrideWith(
    FutureOr<List<Sale>> Function(CustomerSalesRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: CustomerSalesProvider._internal(
        (ref) => create(ref as CustomerSalesRef),
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
  AutoDisposeFutureProviderElement<List<Sale>> createElement() {
    return _CustomerSalesProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is CustomerSalesProvider && other.q == q;
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
mixin CustomerSalesRef on AutoDisposeFutureProviderRef<List<Sale>> {
  /// The parameter `q` of this provider.
  CustomerSalesQuery get q;
}

class _CustomerSalesProviderElement
    extends AutoDisposeFutureProviderElement<List<Sale>>
    with CustomerSalesRef {
  _CustomerSalesProviderElement(super.provider);

  @override
  CustomerSalesQuery get q => (origin as CustomerSalesProvider).q;
}

String _$customerPaymentsHash() => r'7033e5769f81b4bac3c211b67701e75f938f62b6';

/// See also [customerPayments].
@ProviderFor(customerPayments)
const customerPaymentsProvider = CustomerPaymentsFamily();

/// See also [customerPayments].
class CustomerPaymentsFamily extends Family<AsyncValue<List<CustomerPayment>>> {
  /// See also [customerPayments].
  const CustomerPaymentsFamily();

  /// See also [customerPayments].
  CustomerPaymentsProvider call(String customerId) {
    return CustomerPaymentsProvider(customerId);
  }

  @override
  CustomerPaymentsProvider getProviderOverride(
    covariant CustomerPaymentsProvider provider,
  ) {
    return call(provider.customerId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'customerPaymentsProvider';
}

/// See also [customerPayments].
class CustomerPaymentsProvider
    extends AutoDisposeFutureProvider<List<CustomerPayment>> {
  /// See also [customerPayments].
  CustomerPaymentsProvider(String customerId)
    : this._internal(
        (ref) => customerPayments(ref as CustomerPaymentsRef, customerId),
        from: customerPaymentsProvider,
        name: r'customerPaymentsProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$customerPaymentsHash,
        dependencies: CustomerPaymentsFamily._dependencies,
        allTransitiveDependencies:
            CustomerPaymentsFamily._allTransitiveDependencies,
        customerId: customerId,
      );

  CustomerPaymentsProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.customerId,
  }) : super.internal();

  final String customerId;

  @override
  Override overrideWith(
    FutureOr<List<CustomerPayment>> Function(CustomerPaymentsRef provider)
    create,
  ) {
    return ProviderOverride(
      origin: this,
      override: CustomerPaymentsProvider._internal(
        (ref) => create(ref as CustomerPaymentsRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        customerId: customerId,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<List<CustomerPayment>> createElement() {
    return _CustomerPaymentsProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is CustomerPaymentsProvider && other.customerId == customerId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, customerId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin CustomerPaymentsRef
    on AutoDisposeFutureProviderRef<List<CustomerPayment>> {
  /// The parameter `customerId` of this provider.
  String get customerId;
}

class _CustomerPaymentsProviderElement
    extends AutoDisposeFutureProviderElement<List<CustomerPayment>>
    with CustomerPaymentsRef {
  _CustomerPaymentsProviderElement(super.provider);

  @override
  String get customerId => (origin as CustomerPaymentsProvider).customerId;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
