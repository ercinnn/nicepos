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

  /// Hane başı "logo göster" tiki — varsayılan false. Tiksiz haneler etiket
  /// üstünde logo alanını BOŞ bırakır (alan korunur, yalnız görsel basılmaz).
  final bool showLogo;
  final DateTime createdAt;

  const DiscountLabelSlot({
    required this.barcode,
    required this.productName,
    required this.oldPrice,
    required this.discountPercent,
    this.showLogo = false,
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
    bool? showLogo,
    DateTime? createdAt,
  }) {
    return DiscountLabelSlot(
      barcode: barcode ?? this.barcode,
      productName: productName ?? this.productName,
      oldPrice: oldPrice ?? this.oldPrice,
      discountPercent: discountPercent,
      showLogo: showLogo ?? this.showLogo,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// A4 sayfada İndirim Etiketi ızgara sabitleri (2 sütun × 2 satır = 4/sayfa,
/// kullanıcı isteği — çok sayfalı destek YOK).
const int kDiscountCols = 2;
const int kDiscountRows = 2;
const int kDiscountCount = kDiscountCols * kDiscountRows; // 4/sayfa

/// Dolu haneleri (`slots` içindeki trailing boş hane HARİÇ, `whereType` ile
/// otomatik dışlanır) 4'lük A4 sayfalara böler; her sayfa TAM [kDiscountCount]
/// uzunlukta döner (eksik hücreler `null` ile doldurulur) — üç çıktı
/// (önizleme = HTML = PDF) bu fonksiyonu paylaşır, ızgara render kodu
/// (`slots[idx]` doğrudan indexleme) değişmeden çalışmaya devam eder.
List<List<DiscountLabelSlot?>> paginateDiscountSlots(
    List<DiscountLabelSlot?> slots) {
  final filled = slots.whereType<DiscountLabelSlot>().toList();
  if (filled.isEmpty) {
    return [List<DiscountLabelSlot?>.filled(kDiscountCount, null)];
  }
  final pages = <List<DiscountLabelSlot?>>[];
  for (var start = 0; start < filled.length; start += kDiscountCount) {
    final end = (start + kDiscountCount < filled.length)
        ? start + kDiscountCount
        : filled.length;
    final chunk = filled.sublist(start, end);
    pages.add(List<DiscountLabelSlot?>.generate(
        kDiscountCount, (i) => i < chunk.length ? chunk[i] : null));
  }
  return pages;
}
