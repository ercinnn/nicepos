// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'gorevler_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$gorevlerRepositoryHash() =>
    r'13debdbbbbdc4667738b0105f224b38725e44cd2';

/// See also [gorevlerRepository].
@ProviderFor(gorevlerRepository)
final gorevlerRepositoryProvider =
    AutoDisposeProvider<GorevlerRepository>.internal(
      gorevlerRepository,
      name: r'gorevlerRepositoryProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$gorevlerRepositoryHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef GorevlerRepositoryRef = AutoDisposeProviderRef<GorevlerRepository>;
String _$gorevlerControllerHash() =>
    r'99dc32b322f7ee0f4a915479bfd5ec0022ac1618';

/// Görevler listesi (bekleyen + tamamlanan, `GorevItem.completedAt` ile
/// ayrışır — bkz. ekran). Tamamlanma sunucuda tutulur (`gorev_tamamlamalar`)
/// ki aynı (paylaşılan) kullanıcı başka bir cihazdan girdiğinde aynı durumu
/// görsün. autoDispose (dashboard provider'larıyla aynı KARAR) — sayfaya her
/// dönüşte taze sorgu, kalıcı-yanlış-veri riski yok.
///
/// Copied from [GorevlerController].
@ProviderFor(GorevlerController)
final gorevlerControllerProvider =
    AutoDisposeAsyncNotifierProvider<
      GorevlerController,
      List<GorevItem>
    >.internal(
      GorevlerController.new,
      name: r'gorevlerControllerProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$gorevlerControllerHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$GorevlerController = AutoDisposeAsyncNotifier<List<GorevItem>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
