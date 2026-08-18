/// İndirim Etiketi (bkz. CLAUDE.md "Etiket" bölümü) — sabit 4 hane (A4'te 2×2).
/// Barkod okutulup çözülünce ürün adı + orijinal fiyat (`price1`) doldurulur;
/// indirim yüzdesi kullanıcı tarafından elle girilir. İndirimli fiyat
/// SAKLANMAZ — [newPrice] her zaman `oldPrice` + `discountPercent` üzerinden
/// türetilir (tek doğruluk kaynağı: önizleme = HTML = PDF üçü de bu getter'ı
/// kullanır, sapma imkânsız).
class DiscountLabelSlot {
  final String barcode;
  final String productName;
  final num oldPrice;
  final num discountPercent;
  final DateTime createdAt;

  const DiscountLabelSlot({
    required this.barcode,
    required this.productName,
    required this.oldPrice,
    required this.discountPercent,
    required this.createdAt,
  });

  /// İndirimli (yeni) fiyat — negatif/aşırı yüzdeye karşı 0-100 aralığına
  /// kenetlenir.
  num get newPrice => oldPrice * (1 - discountPercent.clamp(0, 100) / 100);

  DiscountLabelSlot copyWith({
    String? barcode,
    String? productName,
    num? oldPrice,
    num? discountPercent,
    DateTime? createdAt,
  }) {
    return DiscountLabelSlot(
      barcode: barcode ?? this.barcode,
      productName: productName ?? this.productName,
      oldPrice: oldPrice ?? this.oldPrice,
      discountPercent: discountPercent ?? this.discountPercent,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// A4 sayfada İndirim Etiketi ızgara sabitleri (2 sütun × 2 satır = 4/sayfa,
/// kullanıcı isteği — çok sayfalı destek YOK).
const int kDiscountCols = 2;
const int kDiscountRows = 2;
const int kDiscountCount = kDiscountCols * kDiscountRows; // 4
