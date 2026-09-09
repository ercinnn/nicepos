// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'audit_log_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$auditLogRepositoryHash() =>
    r'44d6093d680c48ba5f90196bcf33156bbf1961ea';

/// See also [auditLogRepository].
@ProviderFor(auditLogRepository)
final auditLogRepositoryProvider =
    AutoDisposeProvider<AuditLogRepository>.internal(
      auditLogRepository,
      name: r'auditLogRepositoryProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$auditLogRepositoryHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AuditLogRepositoryRef = AutoDisposeProviderRef<AuditLogRepository>;
String _$auditLogPageHash() => r'48c329da42f2e2c41f5a38a1b821165808ccbb39';

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

/// [page] (0 = ilk sayfa) için denetim kaydı listesi — Dashboard/Görevler
/// provider'larıyla AYNI KARAR: autoDispose, sayfaya her dönüşte taze sorgu.
///
/// Copied from [auditLogPage].
@ProviderFor(auditLogPage)
const auditLogPageProvider = AuditLogPageFamily();

/// [page] (0 = ilk sayfa) için denetim kaydı listesi — Dashboard/Görevler
/// provider'larıyla AYNI KARAR: autoDispose, sayfaya her dönüşte taze sorgu.
///
/// Copied from [auditLogPage].
class AuditLogPageFamily extends Family<AsyncValue<List<AuditLogEntry>>> {
  /// [page] (0 = ilk sayfa) için denetim kaydı listesi — Dashboard/Görevler
  /// provider'larıyla AYNI KARAR: autoDispose, sayfaya her dönüşte taze sorgu.
  ///
  /// Copied from [auditLogPage].
  const AuditLogPageFamily();

  /// [page] (0 = ilk sayfa) için denetim kaydı listesi — Dashboard/Görevler
  /// provider'larıyla AYNI KARAR: autoDispose, sayfaya her dönüşte taze sorgu.
  ///
  /// Copied from [auditLogPage].
  AuditLogPageProvider call(int page) {
    return AuditLogPageProvider(page);
  }

  @override
  AuditLogPageProvider getProviderOverride(
    covariant AuditLogPageProvider provider,
  ) {
    return call(provider.page);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'auditLogPageProvider';
}

/// [page] (0 = ilk sayfa) için denetim kaydı listesi — Dashboard/Görevler
/// provider'larıyla AYNI KARAR: autoDispose, sayfaya her dönüşte taze sorgu.
///
/// Copied from [auditLogPage].
class AuditLogPageProvider
    extends AutoDisposeFutureProvider<List<AuditLogEntry>> {
  /// [page] (0 = ilk sayfa) için denetim kaydı listesi — Dashboard/Görevler
  /// provider'larıyla AYNI KARAR: autoDispose, sayfaya her dönüşte taze sorgu.
  ///
  /// Copied from [auditLogPage].
  AuditLogPageProvider(int page)
    : this._internal(
        (ref) => auditLogPage(ref as AuditLogPageRef, page),
        from: auditLogPageProvider,
        name: r'auditLogPageProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$auditLogPageHash,
        dependencies: AuditLogPageFamily._dependencies,
        allTransitiveDependencies:
            AuditLogPageFamily._allTransitiveDependencies,
        page: page,
      );

  AuditLogPageProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.page,
  }) : super.internal();

  final int page;

  @override
  Override overrideWith(
    FutureOr<List<AuditLogEntry>> Function(AuditLogPageRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: AuditLogPageProvider._internal(
        (ref) => create(ref as AuditLogPageRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        page: page,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<List<AuditLogEntry>> createElement() {
    return _AuditLogPageProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is AuditLogPageProvider && other.page == page;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, page.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin AuditLogPageRef on AutoDisposeFutureProviderRef<List<AuditLogEntry>> {
  /// The parameter `page` of this provider.
  int get page;
}

class _AuditLogPageProviderElement
    extends AutoDisposeFutureProviderElement<List<AuditLogEntry>>
    with AuditLogPageRef {
  _AuditLogPageProviderElement(super.provider);

  @override
  int get page => (origin as AuditLogPageProvider).page;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
