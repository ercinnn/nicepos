import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'help_mode_provider.g.dart';

// ─── Yardım Modu (KARAR) ────────────────────────────────────────────────────
// Uygulama genelinde tek bir açık/kapalı anahtar. AÇIKKEN, `HelpHotspot` ile
// sarılmış her öğeye dokunmak normal aksiyonunu TETİKLEMEZ — yalnızca o
// öğenin ne işe yaradığını anlatan bir balon gösterir (bkz. help_hotspot.dart).
// keepAlive: ekranlar arası geçişte mod sıfırlanmamalı (kullanıcı Satış'ta
// açtıysa Ürünler'e geçince de açık kalsın — sonraki ekranlara yayılacak).
@Riverpod(keepAlive: true)
class HelpMode extends _$HelpMode {
  @override
  bool build() => false;

  void toggle() => state = !state;

  void disable() => state = false;
}
