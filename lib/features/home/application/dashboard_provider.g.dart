// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dashboard_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$dashboardRepositoryHash() =>
    r'7904c5718b5b31b41083140aaa472b9080af4714';

/// Dashboard repository provider — her build'de aynı örnek kullanılır.
///
/// Copied from [dashboardRepository].
@ProviderFor(dashboardRepository)
final dashboardRepositoryProvider =
    AutoDisposeProvider<DashboardRepository>.internal(
      dashboardRepository,
      name: r'dashboardRepositoryProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$dashboardRepositoryHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef DashboardRepositoryRef = AutoDisposeProviderRef<DashboardRepository>;
String _$todaySummaryHash() => r'e2e81bfa434e659b9d91c471ff76c88fec1453c4';

/// Bugünün satış adedi + tutarı.
///
/// Copied from [todaySummary].
@ProviderFor(todaySummary)
final todaySummaryProvider =
    AutoDisposeFutureProvider<({int count, num revenue})>.internal(
      todaySummary,
      name: r'todaySummaryProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$todaySummaryHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef TodaySummaryRef =
    AutoDisposeFutureProviderRef<({int count, num revenue})>;
String _$yesterdaySummaryHash() => r'5c2050c997a6a2649ad3163ec15d528e9b2772f8';

/// Dünün satış adedi + tutarı (yüzde değişim hesabı için).
///
/// Copied from [yesterdaySummary].
@ProviderFor(yesterdaySummary)
final yesterdaySummaryProvider =
    AutoDisposeFutureProvider<({int count, num revenue})>.internal(
      yesterdaySummary,
      name: r'yesterdaySummaryProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$yesterdaySummaryHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef YesterdaySummaryRef =
    AutoDisposeFutureProviderRef<({int count, num revenue})>;
String _$monthSummaryHash() => r'657f745f2ab120473b7d37dfaec5bfe101887d3e';

/// Bu ayın satış adedi + tutarı.
///
/// Copied from [monthSummary].
@ProviderFor(monthSummary)
final monthSummaryProvider =
    AutoDisposeFutureProvider<({int count, num revenue})>.internal(
      monthSummary,
      name: r'monthSummaryProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$monthSummaryHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef MonthSummaryRef =
    AutoDisposeFutureProviderRef<({int count, num revenue})>;
String _$lastMonthRevenueHash() => r'66ae665178cf28d2541fb2c566ece4cdb6886ede';

/// Geçen ayın toplam satış tutarı.
///
/// Copied from [lastMonthRevenue].
@ProviderFor(lastMonthRevenue)
final lastMonthRevenueProvider = AutoDisposeFutureProvider<num>.internal(
  lastMonthRevenue,
  name: r'lastMonthRevenueProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$lastMonthRevenueHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef LastMonthRevenueRef = AutoDisposeFutureProviderRef<num>;
String _$dailySalesHash() => r'4878beab527d4f745e39e068c1663752c980109b';

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

/// Son [days] günün günlük satış verileri.
///
/// Copied from [dailySales].
@ProviderFor(dailySales)
const dailySalesProvider = DailySalesFamily();

/// Son [days] günün günlük satış verileri.
///
/// Copied from [dailySales].
class DailySalesFamily
    extends Family<AsyncValue<List<({DateTime date, num amount})>>> {
  /// Son [days] günün günlük satış verileri.
  ///
  /// Copied from [dailySales].
  const DailySalesFamily();

  /// Son [days] günün günlük satış verileri.
  ///
  /// Copied from [dailySales].
  DailySalesProvider call(int days) {
    return DailySalesProvider(days);
  }

  @override
  DailySalesProvider getProviderOverride(
    covariant DailySalesProvider provider,
  ) {
    return call(provider.days);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'dailySalesProvider';
}

/// Son [days] günün günlük satış verileri.
///
/// Copied from [dailySales].
class DailySalesProvider
    extends AutoDisposeFutureProvider<List<({DateTime date, num amount})>> {
  /// Son [days] günün günlük satış verileri.
  ///
  /// Copied from [dailySales].
  DailySalesProvider(int days)
    : this._internal(
        (ref) => dailySales(ref as DailySalesRef, days),
        from: dailySalesProvider,
        name: r'dailySalesProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$dailySalesHash,
        dependencies: DailySalesFamily._dependencies,
        allTransitiveDependencies: DailySalesFamily._allTransitiveDependencies,
        days: days,
      );

  DailySalesProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.days,
  }) : super.internal();

  final int days;

  @override
  Override overrideWith(
    FutureOr<List<({DateTime date, num amount})>> Function(
      DailySalesRef provider,
    )
    create,
  ) {
    return ProviderOverride(
      origin: this,
      override: DailySalesProvider._internal(
        (ref) => create(ref as DailySalesRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        days: days,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<List<({DateTime date, num amount})>>
  createElement() {
    return _DailySalesProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is DailySalesProvider && other.days == days;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, days.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin DailySalesRef
    on AutoDisposeFutureProviderRef<List<({DateTime date, num amount})>> {
  /// The parameter `days` of this provider.
  int get days;
}

class _DailySalesProviderElement
    extends
        AutoDisposeFutureProviderElement<List<({DateTime date, num amount})>>
    with DailySalesRef {
  _DailySalesProviderElement(super.provider);

  @override
  int get days => (origin as DailySalesProvider).days;
}

String _$monthlySalesHash() => r'74a220501d7415d9b3bbebe0129a0aa8f0319088';

/// Son [months] ayın aylık satış verileri.
///
/// Copied from [monthlySales].
@ProviderFor(monthlySales)
const monthlySalesProvider = MonthlySalesFamily();

/// Son [months] ayın aylık satış verileri.
///
/// Copied from [monthlySales].
class MonthlySalesFamily
    extends Family<AsyncValue<List<({DateTime date, num amount})>>> {
  /// Son [months] ayın aylık satış verileri.
  ///
  /// Copied from [monthlySales].
  const MonthlySalesFamily();

  /// Son [months] ayın aylık satış verileri.
  ///
  /// Copied from [monthlySales].
  MonthlySalesProvider call(int months) {
    return MonthlySalesProvider(months);
  }

  @override
  MonthlySalesProvider getProviderOverride(
    covariant MonthlySalesProvider provider,
  ) {
    return call(provider.months);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'monthlySalesProvider';
}

/// Son [months] ayın aylık satış verileri.
///
/// Copied from [monthlySales].
class MonthlySalesProvider
    extends AutoDisposeFutureProvider<List<({DateTime date, num amount})>> {
  /// Son [months] ayın aylık satış verileri.
  ///
  /// Copied from [monthlySales].
  MonthlySalesProvider(int months)
    : this._internal(
        (ref) => monthlySales(ref as MonthlySalesRef, months),
        from: monthlySalesProvider,
        name: r'monthlySalesProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$monthlySalesHash,
        dependencies: MonthlySalesFamily._dependencies,
        allTransitiveDependencies:
            MonthlySalesFamily._allTransitiveDependencies,
        months: months,
      );

  MonthlySalesProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.months,
  }) : super.internal();

  final int months;

  @override
  Override overrideWith(
    FutureOr<List<({DateTime date, num amount})>> Function(
      MonthlySalesRef provider,
    )
    create,
  ) {
    return ProviderOverride(
      origin: this,
      override: MonthlySalesProvider._internal(
        (ref) => create(ref as MonthlySalesRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        months: months,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<List<({DateTime date, num amount})>>
  createElement() {
    return _MonthlySalesProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is MonthlySalesProvider && other.months == months;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, months.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin MonthlySalesRef
    on AutoDisposeFutureProviderRef<List<({DateTime date, num amount})>> {
  /// The parameter `months` of this provider.
  int get months;
}

class _MonthlySalesProviderElement
    extends
        AutoDisposeFutureProviderElement<List<({DateTime date, num amount})>>
    with MonthlySalesRef {
  _MonthlySalesProviderElement(super.provider);

  @override
  int get months => (origin as MonthlySalesProvider).months;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
