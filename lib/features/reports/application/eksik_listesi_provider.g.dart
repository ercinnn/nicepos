// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'eksik_listesi_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$eksikListesiControllerHash() =>
    r'807136db453c86e1450a6c03b1ffd5e950cb8a0d';

/// Eksik Listesi — Ciro Analiz sekmesinde filtrelenip firma bazlı seçilen
/// ürünlerin toplandığı paylaşılan çalışma listesi. `keepAlive: true`
/// (`salesCartProvider`/`labelSheetProvider` ile aynı gerekçe): sekmeler
/// arası geçişte liste kaybolmamalı. Yalnız oturum içi bellek state'i — DB'ye
/// yazılmaz, geçici bir sipariş/eksik listesi taslağıdır.
///
/// Copied from [EksikListesiController].
@ProviderFor(EksikListesiController)
final eksikListesiControllerProvider =
    NotifierProvider<EksikListesiController, List<CiroAnalizRecord>>.internal(
      EksikListesiController.new,
      name: r'eksikListesiControllerProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$eksikListesiControllerHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$EksikListesiController = Notifier<List<CiroAnalizRecord>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
