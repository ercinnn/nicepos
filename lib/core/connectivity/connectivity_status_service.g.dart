// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'connectivity_status_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$connectivityStatusServiceHash() =>
    r'b780fa79127197333ef708a46560bcb45206fe27';

/// Mobil çevrimdışı senkronun PAYLAŞILAN bağlantı tespiti — `ProductSyncService`
/// ve `SaleSyncService`'in her biri KENDİ reachability probe'unu AÇMAZ, ikisi
/// de bu servisi tüketir. Yalnız native/Android'de anlamlıdır (çağıran
/// taraflar `!kIsWeb` ile korur).
///
/// `connectivity_plus` TEK BAŞINA yeterli değildir (dead-zone sorunu, bkz.
/// CLAUDE.md) — her tetikleyici gerçek bir Supabase round-trip ile doğrulanır.
/// Tek fark önceki tasarımdan: prob artık TEK bir yerde yapılır ve sonucu
/// KAYITLI tüm bağımlılara (`registerDependent`) birlikte dağıtılır — bağlantı
/// geldiği an ürün+satış kuyrukları AYRI AYRI gecikmeli değil, BİRLİKTE/anında
/// boşalır.
///
/// Copied from [ConnectivityStatusService].
@ProviderFor(ConnectivityStatusService)
final connectivityStatusServiceProvider =
    NotifierProvider<ConnectivityStatusService, ConnectivityStatus>.internal(
      ConnectivityStatusService.new,
      name: r'connectivityStatusServiceProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$connectivityStatusServiceHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$ConnectivityStatusService = Notifier<ConnectivityStatus>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
