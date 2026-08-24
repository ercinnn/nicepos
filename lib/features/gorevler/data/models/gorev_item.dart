/// Görevler (raf kontrolü) sayfası satır modeli — dün satılan bir ürünün
/// toplam satış adedini + (varsa) tamamlanma zamanını taşır. `completedAt`
/// sunucudan gelir (`gorev_tamamlamalar` tablosu) — cihazlar arası paylaşılır.
class GorevItem {
  final String productId;
  final String name;
  final String? barcode;
  final num quantity; // Dün satılan toplam miktar (Σ quantity)
  final DateTime? completedAt; // null = henüz tamamlanmadı

  const GorevItem({
    required this.productId,
    required this.name,
    this.barcode,
    required this.quantity,
    this.completedAt,
  });

  bool get tamamlandi => completedAt != null;
}
