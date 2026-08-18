/// İndirim Etiketi (bkz. CLAUDE.md "Etiket" bölümü) — sabit 4 hane (A4'te 2×2).
/// Barkod okutulup çözülünce ürün adı + orijinal fiyat (`price1`) doldurulur;
/// indirim yüzdesi kullanıcı tarafından elle girilir. İndirimli fiyat
/// SAKLANMAZ — [newPrice] her zaman `oldPrice` + etkin yüzde üzerinden
/// türetilir (tek doğruluk kaynağı: önizleme = HTML = PDF üçü de bu metodu
/// kullanır, sapma imkânsız).
class DiscountLabelSlot {
  final String barcode;
  final String productName;
  final num oldPrice;

  /// Hane-özel indirim yüzdesi. `null` → hane kendi yüzdesini GİRMEMİŞ, sayfa
  /// geneli varsayılan yüzde (`LabelDiscountSheetState.defaultPercent`)
  /// kullanılır. Girilmişse (0 dahil) o hane İÇİN her zaman bu değer geçerlidir
  /// — genel yüzde değişse bile bu haneyi etkilemez.
  final num? discountPercent;
  final DateTime createdAt;

  const DiscountLabelSlot({
    required this.barcode,
    required this.productName,
    required this.oldPrice,
    required this.discountPercent,
    required this.createdAt,
  });

  /// Etkin indirim yüzdesi — hane kendi yüzdesini girmişse o, girmemişse
  /// [defaultPercent] (sayfa geneli/ana indirim).
  num effectivePercent(num defaultPercent) => discountPercent ?? defaultPercent;

  /// İndirimli (yeni) fiyat — negatif/aşırı yüzdeye karşı 0-100 aralığına
  /// kenetlenir. [defaultPercent] hane kendi yüzdesini girmemişse kullanılır.
  num newPrice(num defaultPercent) =>
      oldPrice * (1 - effectivePercent(defaultPercent).clamp(0, 100) / 100);

  DiscountLabelSlot copyWith({
    String? barcode,
    String? productName,
    num? oldPrice,
    DateTime? createdAt,
  }) {
    return DiscountLabelSlot(
      barcode: barcode ?? this.barcode,
      productName: productName ?? this.productName,
      oldPrice: oldPrice ?? this.oldPrice,
      discountPercent: discountPercent,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// A4 sayfada İndirim Etiketi ızgara sabitleri (2 sütun × 2 satır = 4/sayfa,
/// kullanıcı isteği — çok sayfalı destek YOK).
const int kDiscountCols = 2;
const int kDiscountRows = 2;
const int kDiscountCount = kDiscountCols * kDiscountRows; // 4
