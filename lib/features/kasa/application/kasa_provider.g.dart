// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'kasa_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$kasaRepositoryHash() => r'312514c8746a42242ce4193af4df3dc34ae9727f';

/// Kasa repository provider — tekil örüntü, oturum boyunca aynı örnek.
///
/// Copied from [kasaRepository].
@ProviderFor(kasaRepository)
final kasaRepositoryProvider = Provider<KasaRepository>.internal(
  kasaRepository,
  name: r'kasaRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$kasaRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef KasaRepositoryRef = ProviderRef<KasaRepository>;
String _$kasaReconciliationServiceHash() =>
    r'7bf3324ea6bfa15a054b02473f4033d02b4c36c8';

/// Kasa mutabakat motoru (Faz C) provider — tekil örüntü.
///
/// Copied from [kasaReconciliationService].
@ProviderFor(kasaReconciliationService)
final kasaReconciliationServiceProvider =
    Provider<KasaReconciliationService>.internal(
      kasaReconciliationService,
      name: r'kasaReconciliationServiceProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$kasaReconciliationServiceHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef KasaReconciliationServiceRef = ProviderRef<KasaReconciliationService>;
String _$kasaEntriesHash() => r'9afc44b2b5fdef6552190093338e6c0333421c23';

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

/// Seçili mali yıl / gün / yön için kasa kalemleri.
///
/// Copied from [kasaEntries].
@ProviderFor(kasaEntries)
const kasaEntriesProvider = KasaEntriesFamily();

/// Seçili mali yıl / gün / yön için kasa kalemleri.
///
/// Copied from [kasaEntries].
class KasaEntriesFamily extends Family<AsyncValue<List<KasaEntry>>> {
  /// Seçili mali yıl / gün / yön için kasa kalemleri.
  ///
  /// Copied from [kasaEntries].
  const KasaEntriesFamily();

  /// Seçili mali yıl / gün / yön için kasa kalemleri.
  ///
  /// Copied from [kasaEntries].
  KasaEntriesProvider call(KasaEntriesQuery q) {
    return KasaEntriesProvider(q);
  }

  @override
  KasaEntriesProvider getProviderOverride(
    covariant KasaEntriesProvider provider,
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
  String? get name => r'kasaEntriesProvider';
}

/// Seçili mali yıl / gün / yön için kasa kalemleri.
///
/// Copied from [kasaEntries].
class KasaEntriesProvider extends AutoDisposeFutureProvider<List<KasaEntry>> {
  /// Seçili mali yıl / gün / yön için kasa kalemleri.
  ///
  /// Copied from [kasaEntries].
  KasaEntriesProvider(KasaEntriesQuery q)
    : this._internal(
        (ref) => kasaEntries(ref as KasaEntriesRef, q),
        from: kasaEntriesProvider,
        name: r'kasaEntriesProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$kasaEntriesHash,
        dependencies: KasaEntriesFamily._dependencies,
        allTransitiveDependencies: KasaEntriesFamily._allTransitiveDependencies,
        q: q,
      );

  KasaEntriesProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.q,
  }) : super.internal();

  final KasaEntriesQuery q;

  @override
  Override overrideWith(
    FutureOr<List<KasaEntry>> Function(KasaEntriesRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: KasaEntriesProvider._internal(
        (ref) => create(ref as KasaEntriesRef),
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
  AutoDisposeFutureProviderElement<List<KasaEntry>> createElement() {
    return _KasaEntriesProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is KasaEntriesProvider && other.q == q;
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
mixin KasaEntriesRef on AutoDisposeFutureProviderRef<List<KasaEntry>> {
  /// The parameter `q` of this provider.
  KasaEntriesQuery get q;
}

class _KasaEntriesProviderElement
    extends AutoDisposeFutureProviderElement<List<KasaEntry>>
    with KasaEntriesRef {
  _KasaEntriesProviderElement(super.provider);

  @override
  KasaEntriesQuery get q => (origin as KasaEntriesProvider).q;
}

String _$kasaProductPurchasesHash() =>
    r'be8b24aa0f039ef63ca63dd8875a76fb03c5f874';

/// Seçili mali yılın ürün-alımı giderleri (firma bazlı rapor için ham liste).
///
/// Copied from [kasaProductPurchases].
@ProviderFor(kasaProductPurchases)
const kasaProductPurchasesProvider = KasaProductPurchasesFamily();

/// Seçili mali yılın ürün-alımı giderleri (firma bazlı rapor için ham liste).
///
/// Copied from [kasaProductPurchases].
class KasaProductPurchasesFamily extends Family<AsyncValue<List<KasaEntry>>> {
  /// Seçili mali yılın ürün-alımı giderleri (firma bazlı rapor için ham liste).
  ///
  /// Copied from [kasaProductPurchases].
  const KasaProductPurchasesFamily();

  /// Seçili mali yılın ürün-alımı giderleri (firma bazlı rapor için ham liste).
  ///
  /// Copied from [kasaProductPurchases].
  KasaProductPurchasesProvider call(int fiscalYear) {
    return KasaProductPurchasesProvider(fiscalYear);
  }

  @override
  KasaProductPurchasesProvider getProviderOverride(
    covariant KasaProductPurchasesProvider provider,
  ) {
    return call(provider.fiscalYear);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'kasaProductPurchasesProvider';
}

/// Seçili mali yılın ürün-alımı giderleri (firma bazlı rapor için ham liste).
///
/// Copied from [kasaProductPurchases].
class KasaProductPurchasesProvider
    extends AutoDisposeFutureProvider<List<KasaEntry>> {
  /// Seçili mali yılın ürün-alımı giderleri (firma bazlı rapor için ham liste).
  ///
  /// Copied from [kasaProductPurchases].
  KasaProductPurchasesProvider(int fiscalYear)
    : this._internal(
        (ref) =>
            kasaProductPurchases(ref as KasaProductPurchasesRef, fiscalYear),
        from: kasaProductPurchasesProvider,
        name: r'kasaProductPurchasesProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$kasaProductPurchasesHash,
        dependencies: KasaProductPurchasesFamily._dependencies,
        allTransitiveDependencies:
            KasaProductPurchasesFamily._allTransitiveDependencies,
        fiscalYear: fiscalYear,
      );

  KasaProductPurchasesProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.fiscalYear,
  }) : super.internal();

  final int fiscalYear;

  @override
  Override overrideWith(
    FutureOr<List<KasaEntry>> Function(KasaProductPurchasesRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: KasaProductPurchasesProvider._internal(
        (ref) => create(ref as KasaProductPurchasesRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        fiscalYear: fiscalYear,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<List<KasaEntry>> createElement() {
    return _KasaProductPurchasesProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is KasaProductPurchasesProvider &&
        other.fiscalYear == fiscalYear;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, fiscalYear.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin KasaProductPurchasesRef on AutoDisposeFutureProviderRef<List<KasaEntry>> {
  /// The parameter `fiscalYear` of this provider.
  int get fiscalYear;
}

class _KasaProductPurchasesProviderElement
    extends AutoDisposeFutureProviderElement<List<KasaEntry>>
    with KasaProductPurchasesRef {
  _KasaProductPurchasesProviderElement(super.provider);

  @override
  int get fiscalYear => (origin as KasaProductPurchasesProvider).fiscalYear;
}

String _$kasaOpeningBalanceHash() =>
    r'447e38651c16c6bbd89f5bcea9d74d0e964f3c5c';

/// Mali yılın kasa açılış bakiyesi (kayıt yoksa null).
///
/// Copied from [kasaOpeningBalance].
@ProviderFor(kasaOpeningBalance)
const kasaOpeningBalanceProvider = KasaOpeningBalanceFamily();

/// Mali yılın kasa açılış bakiyesi (kayıt yoksa null).
///
/// Copied from [kasaOpeningBalance].
class KasaOpeningBalanceFamily extends Family<AsyncValue<KasaOpeningBalance?>> {
  /// Mali yılın kasa açılış bakiyesi (kayıt yoksa null).
  ///
  /// Copied from [kasaOpeningBalance].
  const KasaOpeningBalanceFamily();

  /// Mali yılın kasa açılış bakiyesi (kayıt yoksa null).
  ///
  /// Copied from [kasaOpeningBalance].
  KasaOpeningBalanceProvider call(int fiscalYear) {
    return KasaOpeningBalanceProvider(fiscalYear);
  }

  @override
  KasaOpeningBalanceProvider getProviderOverride(
    covariant KasaOpeningBalanceProvider provider,
  ) {
    return call(provider.fiscalYear);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'kasaOpeningBalanceProvider';
}

/// Mali yılın kasa açılış bakiyesi (kayıt yoksa null).
///
/// Copied from [kasaOpeningBalance].
class KasaOpeningBalanceProvider
    extends AutoDisposeFutureProvider<KasaOpeningBalance?> {
  /// Mali yılın kasa açılış bakiyesi (kayıt yoksa null).
  ///
  /// Copied from [kasaOpeningBalance].
  KasaOpeningBalanceProvider(int fiscalYear)
    : this._internal(
        (ref) => kasaOpeningBalance(ref as KasaOpeningBalanceRef, fiscalYear),
        from: kasaOpeningBalanceProvider,
        name: r'kasaOpeningBalanceProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$kasaOpeningBalanceHash,
        dependencies: KasaOpeningBalanceFamily._dependencies,
        allTransitiveDependencies:
            KasaOpeningBalanceFamily._allTransitiveDependencies,
        fiscalYear: fiscalYear,
      );

  KasaOpeningBalanceProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.fiscalYear,
  }) : super.internal();

  final int fiscalYear;

  @override
  Override overrideWith(
    FutureOr<KasaOpeningBalance?> Function(KasaOpeningBalanceRef provider)
    create,
  ) {
    return ProviderOverride(
      origin: this,
      override: KasaOpeningBalanceProvider._internal(
        (ref) => create(ref as KasaOpeningBalanceRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        fiscalYear: fiscalYear,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<KasaOpeningBalance?> createElement() {
    return _KasaOpeningBalanceProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is KasaOpeningBalanceProvider &&
        other.fiscalYear == fiscalYear;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, fiscalYear.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin KasaOpeningBalanceRef
    on AutoDisposeFutureProviderRef<KasaOpeningBalance?> {
  /// The parameter `fiscalYear` of this provider.
  int get fiscalYear;
}

class _KasaOpeningBalanceProviderElement
    extends AutoDisposeFutureProviderElement<KasaOpeningBalance?>
    with KasaOpeningBalanceRef {
  _KasaOpeningBalanceProviderElement(super.provider);

  @override
  int get fiscalYear => (origin as KasaOpeningBalanceProvider).fiscalYear;
}

String _$kasaExpenseCategoriesHash() =>
    r'9ac937667c207bfa38a97ea8e9e9f3fd95f3be66';

/// Aktif gider kategorileri.
///
/// Copied from [kasaExpenseCategories].
@ProviderFor(kasaExpenseCategories)
final kasaExpenseCategoriesProvider =
    AutoDisposeFutureProvider<List<KasaExpenseCategory>>.internal(
      kasaExpenseCategories,
      name: r'kasaExpenseCategoriesProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$kasaExpenseCategoriesHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef KasaExpenseCategoriesRef =
    AutoDisposeFutureProviderRef<List<KasaExpenseCategory>>;
String _$kasaCumulativeSummaryHash() =>
    r'8a6948d43dbbed37f7f98b0f823c0759ba36d745';

/// Hero için kümülatif gelir / gider / net özeti ([uptoDate] dahil).
/// SADECE kasa_entries + opening_balances üzerinden — satışa dokunmaz.
///
/// Copied from [kasaCumulativeSummary].
@ProviderFor(kasaCumulativeSummary)
const kasaCumulativeSummaryProvider = KasaCumulativeSummaryFamily();

/// Hero için kümülatif gelir / gider / net özeti ([uptoDate] dahil).
/// SADECE kasa_entries + opening_balances üzerinden — satışa dokunmaz.
///
/// Copied from [kasaCumulativeSummary].
class KasaCumulativeSummaryFamily
    extends Family<AsyncValue<({num income, num expense, num net})>> {
  /// Hero için kümülatif gelir / gider / net özeti ([uptoDate] dahil).
  /// SADECE kasa_entries + opening_balances üzerinden — satışa dokunmaz.
  ///
  /// Copied from [kasaCumulativeSummary].
  const KasaCumulativeSummaryFamily();

  /// Hero için kümülatif gelir / gider / net özeti ([uptoDate] dahil).
  /// SADECE kasa_entries + opening_balances üzerinden — satışa dokunmaz.
  ///
  /// Copied from [kasaCumulativeSummary].
  KasaCumulativeSummaryProvider call(KasaSummaryQuery q) {
    return KasaCumulativeSummaryProvider(q);
  }

  @override
  KasaCumulativeSummaryProvider getProviderOverride(
    covariant KasaCumulativeSummaryProvider provider,
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
  String? get name => r'kasaCumulativeSummaryProvider';
}

/// Hero için kümülatif gelir / gider / net özeti ([uptoDate] dahil).
/// SADECE kasa_entries + opening_balances üzerinden — satışa dokunmaz.
///
/// Copied from [kasaCumulativeSummary].
class KasaCumulativeSummaryProvider
    extends AutoDisposeFutureProvider<({num income, num expense, num net})> {
  /// Hero için kümülatif gelir / gider / net özeti ([uptoDate] dahil).
  /// SADECE kasa_entries + opening_balances üzerinden — satışa dokunmaz.
  ///
  /// Copied from [kasaCumulativeSummary].
  KasaCumulativeSummaryProvider(KasaSummaryQuery q)
    : this._internal(
        (ref) => kasaCumulativeSummary(ref as KasaCumulativeSummaryRef, q),
        from: kasaCumulativeSummaryProvider,
        name: r'kasaCumulativeSummaryProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$kasaCumulativeSummaryHash,
        dependencies: KasaCumulativeSummaryFamily._dependencies,
        allTransitiveDependencies:
            KasaCumulativeSummaryFamily._allTransitiveDependencies,
        q: q,
      );

  KasaCumulativeSummaryProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.q,
  }) : super.internal();

  final KasaSummaryQuery q;

  @override
  Override overrideWith(
    FutureOr<({num income, num expense, num net})> Function(
      KasaCumulativeSummaryRef provider,
    )
    create,
  ) {
    return ProviderOverride(
      origin: this,
      override: KasaCumulativeSummaryProvider._internal(
        (ref) => create(ref as KasaCumulativeSummaryRef),
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
  AutoDisposeFutureProviderElement<({num income, num expense, num net})>
  createElement() {
    return _KasaCumulativeSummaryProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is KasaCumulativeSummaryProvider && other.q == q;
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
mixin KasaCumulativeSummaryRef
    on AutoDisposeFutureProviderRef<({num income, num expense, num net})> {
  /// The parameter `q` of this provider.
  KasaSummaryQuery get q;
}

class _KasaCumulativeSummaryProviderElement
    extends
        AutoDisposeFutureProviderElement<({num income, num expense, num net})>
    with KasaCumulativeSummaryRef {
  _KasaCumulativeSummaryProviderElement(super.provider);

  @override
  KasaSummaryQuery get q => (origin as KasaCumulativeSummaryProvider).q;
}

String _$kasaDailyChannelIncomeHash() =>
    r'459f8fef8af6687b8af6aff220d9329ce8a6aa06';

/// Seçili günün gelir kanalı kırılımı (Nakit / POS).
///
/// Copied from [kasaDailyChannelIncome].
@ProviderFor(kasaDailyChannelIncome)
const kasaDailyChannelIncomeProvider = KasaDailyChannelIncomeFamily();

/// Seçili günün gelir kanalı kırılımı (Nakit / POS).
///
/// Copied from [kasaDailyChannelIncome].
class KasaDailyChannelIncomeFamily
    extends Family<AsyncValue<({num nakit, num pos})>> {
  /// Seçili günün gelir kanalı kırılımı (Nakit / POS).
  ///
  /// Copied from [kasaDailyChannelIncome].
  const KasaDailyChannelIncomeFamily();

  /// Seçili günün gelir kanalı kırılımı (Nakit / POS).
  ///
  /// Copied from [kasaDailyChannelIncome].
  KasaDailyChannelIncomeProvider call(KasaDailyQuery q) {
    return KasaDailyChannelIncomeProvider(q);
  }

  @override
  KasaDailyChannelIncomeProvider getProviderOverride(
    covariant KasaDailyChannelIncomeProvider provider,
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
  String? get name => r'kasaDailyChannelIncomeProvider';
}

/// Seçili günün gelir kanalı kırılımı (Nakit / POS).
///
/// Copied from [kasaDailyChannelIncome].
class KasaDailyChannelIncomeProvider
    extends AutoDisposeFutureProvider<({num nakit, num pos})> {
  /// Seçili günün gelir kanalı kırılımı (Nakit / POS).
  ///
  /// Copied from [kasaDailyChannelIncome].
  KasaDailyChannelIncomeProvider(KasaDailyQuery q)
    : this._internal(
        (ref) => kasaDailyChannelIncome(ref as KasaDailyChannelIncomeRef, q),
        from: kasaDailyChannelIncomeProvider,
        name: r'kasaDailyChannelIncomeProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$kasaDailyChannelIncomeHash,
        dependencies: KasaDailyChannelIncomeFamily._dependencies,
        allTransitiveDependencies:
            KasaDailyChannelIncomeFamily._allTransitiveDependencies,
        q: q,
      );

  KasaDailyChannelIncomeProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.q,
  }) : super.internal();

  final KasaDailyQuery q;

  @override
  Override overrideWith(
    FutureOr<({num nakit, num pos})> Function(
      KasaDailyChannelIncomeRef provider,
    )
    create,
  ) {
    return ProviderOverride(
      origin: this,
      override: KasaDailyChannelIncomeProvider._internal(
        (ref) => create(ref as KasaDailyChannelIncomeRef),
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
  AutoDisposeFutureProviderElement<({num nakit, num pos})> createElement() {
    return _KasaDailyChannelIncomeProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is KasaDailyChannelIncomeProvider && other.q == q;
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
mixin KasaDailyChannelIncomeRef
    on AutoDisposeFutureProviderRef<({num nakit, num pos})> {
  /// The parameter `q` of this provider.
  KasaDailyQuery get q;
}

class _KasaDailyChannelIncomeProviderElement
    extends AutoDisposeFutureProviderElement<({num nakit, num pos})>
    with KasaDailyChannelIncomeRef {
  _KasaDailyChannelIncomeProviderElement(super.provider);

  @override
  KasaDailyQuery get q => (origin as KasaDailyChannelIncomeProvider).q;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
