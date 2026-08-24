import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/models/gorev_item.dart';
import '../data/repositories/gorevler_repository.dart';

part 'gorevler_provider.g.dart';

/// Bir günlük tarih anahtarı (ör. `2026-08-21`) — hem sunucudaki tamamlanma
/// kaydının `gorev_tarihi` sütunu hem "bugün ilk açılış" cihaz-yerel kontrolü
/// için ortak, gün değişince otomatik sıfırlanan anahtar üretir.
String gorevlerTarihAnahtari([DateTime? tarih]) {
  final d = tarih ?? DateTime.now();
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

@riverpod
GorevlerRepository gorevlerRepository(GorevlerRepositoryRef ref) => GorevlerRepository();

/// Görevler listesi (bekleyen + tamamlanan, `GorevItem.completedAt` ile
/// ayrışır — bkz. ekran). Tamamlanma sunucuda tutulur (`gorev_tamamlamalar`)
/// ki aynı (paylaşılan) kullanıcı başka bir cihazdan girdiğinde aynı durumu
/// görsün. autoDispose (dashboard provider'larıyla aynı KARAR) — sayfaya her
/// dönüşte taze sorgu, kalıcı-yanlış-veri riski yok.
@riverpod
class GorevlerController extends _$GorevlerController {
  @override
  Future<List<GorevItem>> build() async {
    final repo = ref.watch(gorevlerRepositoryProvider);
    final tarih = gorevlerTarihAnahtari();
    final items = await repo.fetchYesterdaySoldProducts();
    final tamamlanan = await repo.fetchCompletions(tarih);
    return [
      for (final i in items)
        GorevItem(
          productId: i.productId,
          name: i.name,
          barcode: i.barcode,
          quantity: i.quantity,
          completedAt: tamamlanan[i.productId],
        ),
    ];
  }

  /// [productId]'yi bugün için tamamlandı işaretler.
  Future<void> tamamla(String productId) async {
    final tarih = gorevlerTarihAnahtari();
    await ref.read(gorevlerRepositoryProvider).completeTask(productId, tarih);
    _guncelle(productId, completedAt: DateTime.now());
  }

  /// [productId]'nin bugünkü tamamlanma işaretini geri alır (Tamamlananlar
  /// sekmesinden tekrar tıklanınca).
  Future<void> geriAl(String productId) async {
    final tarih = gorevlerTarihAnahtari();
    await ref.read(gorevlerRepositoryProvider).uncompleteTask(productId, tarih);
    _guncelle(productId, completedAt: null);
  }

  void _guncelle(String productId, {required DateTime? completedAt}) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData([
      for (final i in current)
        if (i.productId == productId)
          GorevItem(
            productId: i.productId,
            name: i.name,
            barcode: i.barcode,
            quantity: i.quantity,
            completedAt: completedAt,
          )
        else
          i,
    ]);
  }
}
