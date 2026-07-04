import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'barcode_focus_notifier.g.dart';

/// Satış tamamlandıktan sonra masaüstü barkod alanına odak istemek için
/// kullanılan decoupled sinyal. `payment_panel` başarı sonrası `requestFocus()`
/// çağırır (tick++); `sales_screen` `_buildDesktop`'ta `ref.listen` ile tick
/// değişince `_barcodeFocusNode.requestFocus()` yapar.
///
/// Yalnızca bir sayaç (tick) tutar — state'in kendisi anlam taşımaz, değişmesi
/// yeterlidir. Mobilde dinleyici kurulmaz; bu yüzden orada odak zorlanmaz.
@Riverpod(keepAlive: true)
class BarcodeFocusRequest extends _$BarcodeFocusRequest {
  @override
  int build() => 0;

  void requestFocus() => state = state + 1;
}
