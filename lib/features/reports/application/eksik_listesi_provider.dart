import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/models/ciro_analiz_record.dart';

part 'eksik_listesi_provider.g.dart';

/// Eksik Listesi — Ciro Analiz sekmesinde filtrelenip firma bazlı seçilen
/// ürünlerin toplandığı paylaşılan çalışma listesi. `keepAlive: true`
/// (`salesCartProvider`/`labelSheetProvider` ile aynı gerekçe): sekmeler
/// arası geçişte liste kaybolmamalı. Yalnız oturum içi bellek state'i — DB'ye
/// yazılmaz, geçici bir sipariş/eksik listesi taslağıdır.
@Riverpod(keepAlive: true)
class EksikListesiController extends _$EksikListesiController {
  @override
  List<CiroAnalizRecord> build() => [];

  /// Verilen kayıtları listeye ekler; `productId` zaten varsa üzerine yazar
  /// (aynı ürün birden fazla filtre turunda tekrar eklenirse güncel veriyle
  /// örtüşür, çift satır oluşmaz).
  void addAll(Iterable<CiroAnalizRecord> records) {
    final byId = {for (final r in state) r.productId: r};
    for (final r in records) {
      byId[r.productId] = r;
    }
    state = byId.values.toList();
  }

  void remove(String productId) {
    state = state.where((r) => r.productId != productId).toList();
  }

  void clear() {
    state = [];
  }
}
