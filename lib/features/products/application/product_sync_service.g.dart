// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'product_sync_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$pendingChangesListHash() =>
    r'2fd21b9b46940f30d2beabd8be52242acea7970b';

/// "Bekleyen Senkronizasyonlar" sheet'i için — `productSyncServiceProvider`'ı
/// da izler ki bir sync döngüsü bittiğinde liste otomatik tazelensin.
///
/// Copied from [pendingChangesList].
@ProviderFor(pendingChangesList)
final pendingChangesListProvider =
    AutoDisposeFutureProvider<List<PendingChange>>.internal(
      pendingChangesList,
      name: r'pendingChangesListProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$pendingChangesListHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef PendingChangesListRef =
    AutoDisposeFutureProviderRef<List<PendingChange>>;
String _$productSyncServiceHash() =>
    r'be70e641dda6d3a9d5e7d7df8898d57788c3ed11';

/// Mobil çevrimdışı ürün ekleme/düzenleme — senkron motoru. Yalnız native/
/// Android'de anlamlıdır (çağıran taraflar `!kIsWeb` ile korur); web'de bu
/// servis hiç tetiklenmez.
///
/// Reachability probe/periyodik timer/connectivity dinleyicisi ARTIK burada
/// DEĞİL — paylaşılan `ConnectivityStatusService`'te (bkz. o dosyanın
/// açıklaması). Bu servis yalnız `registerDependent` ile kaydolur; `syncNow()`
/// SADECE bağlantı doğrulandıktan SONRA (`ConnectivityStatusService.
/// probeAndNotify()` tarafından) çağrılır — kendi prob'unu AÇMAZ.
///
/// Copied from [ProductSyncService].
@ProviderFor(ProductSyncService)
final productSyncServiceProvider =
    NotifierProvider<ProductSyncService, SyncStatus>.internal(
      ProductSyncService.new,
      name: r'productSyncServiceProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$productSyncServiceHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$ProductSyncService = Notifier<SyncStatus>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
