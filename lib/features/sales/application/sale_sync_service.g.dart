// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sale_sync_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$pendingSalesListHash() => r'205e21454ac316813acdf867802a560a28aff3d9';

/// "Bekleyen Senkronizasyonlar" sheet'i için — `saleSyncServiceProvider`'ı
/// da izler ki bir sync döngüsü bittiğinde liste otomatik tazelensin.
///
/// Copied from [pendingSalesList].
@ProviderFor(pendingSalesList)
final pendingSalesListProvider =
    AutoDisposeFutureProvider<List<PendingSale>>.internal(
      pendingSalesList,
      name: r'pendingSalesListProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$pendingSalesListHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef PendingSalesListRef = AutoDisposeFutureProviderRef<List<PendingSale>>;
String _$saleSyncServiceHash() => r'7cb3ca9afff9517b6c86d4c64cf042872be6d92e';

/// Mobil çevrimdışı Nakit/POS satış — senkron motoru. `ProductSyncService`
/// ile birebir aynı iskelet (`SyncStatus` tipini AYNEN paylaşır); reachability
/// probe/periyodik timer KENDİSİNDE DEĞİL, paylaşılan `ConnectivityStatusService`'te
/// — bu servis yalnız `registerDependent` ile kaydolur, `syncNow()` SADECE
/// bağlantı doğrulandıktan SONRA çağrılır.
///
/// Her bekleyen satış `SalesRepository.completeSaleOffline()` ile TEK atomik
/// RPC çağrısıyla gönderilir (bkz. 0027_complete_sale_offline.sql) — kısmi
/// yazım riski yok, id bazlı idempotency retry'ı güvenli kılar.
///
/// Copied from [SaleSyncService].
@ProviderFor(SaleSyncService)
final saleSyncServiceProvider =
    NotifierProvider<SaleSyncService, SyncStatus>.internal(
      SaleSyncService.new,
      name: r'saleSyncServiceProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$saleSyncServiceHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$SaleSyncService = Notifier<SyncStatus>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
