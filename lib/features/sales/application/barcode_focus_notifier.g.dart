// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'barcode_focus_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$barcodeFocusRequestHash() =>
    r'4c127b29973af0be9d751d80972274d0fc921ea8';

/// Satış tamamlandıktan sonra masaüstü barkod alanına odak istemek için
/// kullanılan decoupled sinyal. `payment_panel` başarı sonrası `requestFocus()`
/// çağırır (tick++); `sales_screen` `_buildDesktop`'ta `ref.listen` ile tick
/// değişince `_barcodeFocusNode.requestFocus()` yapar.
///
/// Yalnızca bir sayaç (tick) tutar — state'in kendisi anlam taşımaz, değişmesi
/// yeterlidir. Mobilde dinleyici kurulmaz; bu yüzden orada odak zorlanmaz.
///
/// Copied from [BarcodeFocusRequest].
@ProviderFor(BarcodeFocusRequest)
final barcodeFocusRequestProvider =
    NotifierProvider<BarcodeFocusRequest, int>.internal(
      BarcodeFocusRequest.new,
      name: r'barcodeFocusRequestProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$barcodeFocusRequestHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$BarcodeFocusRequest = Notifier<int>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
