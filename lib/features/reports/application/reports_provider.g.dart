// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reports_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$reportRepositoryHash() => r'0bc81e8fee96e1f20d9174f2a8234147a95d8a8b';

/// See also [reportRepository].
@ProviderFor(reportRepository)
final reportRepositoryProvider = Provider<ReportRepository>.internal(
  reportRepository,
  name: r'reportRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$reportRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ReportRepositoryRef = ProviderRef<ReportRepository>;
String _$dailyReportHash() => r'54c5211782e2435fc3065b1ce7e3cebd6c233f67';

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

/// See also [dailyReport].
@ProviderFor(dailyReport)
const dailyReportProvider = DailyReportFamily();

/// See also [dailyReport].
class DailyReportFamily extends Family<AsyncValue<DailyReportSummary>> {
  /// See also [dailyReport].
  const DailyReportFamily();

  /// See also [dailyReport].
  DailyReportProvider call(DateTime date) {
    return DailyReportProvider(date);
  }

  @override
  DailyReportProvider getProviderOverride(
    covariant DailyReportProvider provider,
  ) {
    return call(provider.date);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'dailyReportProvider';
}

/// See also [dailyReport].
class DailyReportProvider
    extends AutoDisposeFutureProvider<DailyReportSummary> {
  /// See also [dailyReport].
  DailyReportProvider(DateTime date)
    : this._internal(
        (ref) => dailyReport(ref as DailyReportRef, date),
        from: dailyReportProvider,
        name: r'dailyReportProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$dailyReportHash,
        dependencies: DailyReportFamily._dependencies,
        allTransitiveDependencies: DailyReportFamily._allTransitiveDependencies,
        date: date,
      );

  DailyReportProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.date,
  }) : super.internal();

  final DateTime date;

  @override
  Override overrideWith(
    FutureOr<DailyReportSummary> Function(DailyReportRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: DailyReportProvider._internal(
        (ref) => create(ref as DailyReportRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        date: date,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<DailyReportSummary> createElement() {
    return _DailyReportProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is DailyReportProvider && other.date == date;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, date.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin DailyReportRef on AutoDisposeFutureProviderRef<DailyReportSummary> {
  /// The parameter `date` of this provider.
  DateTime get date;
}

class _DailyReportProviderElement
    extends AutoDisposeFutureProviderElement<DailyReportSummary>
    with DailyReportRef {
  _DailyReportProviderElement(super.provider);

  @override
  DateTime get date => (origin as DailyReportProvider).date;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
