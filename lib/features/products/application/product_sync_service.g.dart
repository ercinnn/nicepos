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
    r'c7b557d9d24ce85efcf75f0fc6d2667c3eadcc44';

/// Mobil çevrimdışı ürün ekleme/düzenleme — senkron motoru. Yalnız native/
/// Android'de anlamlıdır (çağıran taraflar `!kIsWeb` ile korur); web'de bu
/// servis hiç tetiklenmez.
///
/// `connectivity_plus` TEK BAŞINA yeterli değildir — cihaz Wi-Fi'ye "bağlı"
/// görünüp gerçek internete ulaşamayabilir (dükkanın dead-zone sorunu tam
/// olarak bu). Bu yüzden her tetikleyici gerçek bir Supabase round-trip
/// ("reachability probe") ile doğrulanır; `connectivity_plus` yalnızca
/// "ne zaman tekrar dene" sinyali olarak kullanılır. Aynı ağda sinyal gücü
/// değişimiyle dead-zone'dan normale geçişte arayüz durumu HİÇ değişmediği
/// için (`connectivity_plus` event üretmez), bekleyen kayıt varken periyodik
/// bir prob da çalışır — gerçek kurtarma mekanizması budur.
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
