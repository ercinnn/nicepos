// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'labels_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$labelSheetHash() => r'0841c322011ac99e9ca0ac63999bc3c175acb3d7';

/// Etiket sayfası durumunu tutar. `keepAlive` — kullanıcı başka sekmeye geçip
/// dönünce 24 hane + logo korunur (oturum içi kalıcılık; localStorage opsiyonel
/// bonus, KARAR v1.10). Satış sepeti notifier'ıyla aynı desen.
///
/// Copied from [LabelSheet].
@ProviderFor(LabelSheet)
final labelSheetProvider =
    NotifierProvider<LabelSheet, LabelSheetState>.internal(
      LabelSheet.new,
      name: r'labelSheetProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$labelSheetHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$LabelSheet = Notifier<LabelSheetState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
