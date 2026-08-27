/// Tel İndirim Etiketi — Tel Etiketi ile aynı 4×8=32 ızgara, yalnız her hane
/// eski (çizili) fiyat + kırmızı/büyük yeni (indirimli) fiyat gösterir.
/// İndirim türü % veya ₺ olabilir; hem sayfa geneli (`generalKind`/
/// `generalValue`, bkz. labels_provider.dart LabelTelDiscountSheetState) hem
/// hane-özel (bu haneye `useGeneral=false` verilip `ownKind`/`ownValue`
/// girilerek) ayarlanabilir. `DiscountLabelSlot.effectivePercent`/`newPrice`
/// deseninin %/₺ genellenmiş hali.
enum TelDiscountKind { percent, amount }

class TelDiscountLabelSlot {
  final String barcode;
  final String productName;
  final num oldPrice;
  final DateTime createdAt;

  /// true (varsayılan) → bu hane sayfa geneli %/₺'den etkilenir. false → bu
  /// hane kendi [ownKind]/[ownValue]'sünü kullanır (genel değer değişse bile
  /// etkilenmez).
  final bool useGeneral;
  final TelDiscountKind? ownKind;
  final num? ownValue;

  const TelDiscountLabelSlot({
    required this.barcode,
    required this.productName,
    required this.oldPrice,
    required this.createdAt,
    this.useGeneral = true,
    this.ownKind,
    this.ownValue,
  });

  /// Etkin indirim türü — hane genel değeri kullanıyorsa [generalKind], kendi
  /// türünü girmişse o.
  TelDiscountKind effectiveKind(TelDiscountKind generalKind) =>
      useGeneral ? generalKind : (ownKind ?? generalKind);

  /// Etkin indirim değeri (türe göre % ya da ₺) — hane genel değeri
  /// kullanıyorsa [generalValue], kendi değerini girmişse o.
  num effectiveValue(num generalValue) =>
      useGeneral ? generalValue : (ownValue ?? 0);

  /// İndirimli (yeni) fiyat — % ise 0-100 aralığına kenetlenir, ₺ ise
  /// negatife düşmez (0'da durur).
  num newPrice(TelDiscountKind generalKind, num generalValue) {
    final kind = effectiveKind(generalKind);
    final value = effectiveValue(generalValue);
    if (kind == TelDiscountKind.percent) {
      return oldPrice * (1 - value.clamp(0, 100) / 100);
    }
    final result = oldPrice - value;
    return result < 0 ? 0 : result;
  }

  TelDiscountLabelSlot copyWith({
    String? barcode,
    String? productName,
    num? oldPrice,
    DateTime? createdAt,
  }) {
    return TelDiscountLabelSlot(
      barcode: barcode ?? this.barcode,
      productName: productName ?? this.productName,
      oldPrice: oldPrice ?? this.oldPrice,
      createdAt: createdAt ?? this.createdAt,
      useGeneral: useGeneral,
      ownKind: ownKind,
      ownValue: ownValue,
    );
  }
}
