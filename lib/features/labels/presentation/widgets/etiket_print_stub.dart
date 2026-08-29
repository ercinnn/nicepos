import '../../data/models/discount_label_slot.dart';
import '../../data/models/label_slot.dart';
import '../../data/models/product_label_item.dart';
import '../../data/models/tel_discount_label_slot.dart';

/// Web dışı platformlarda yazdırma desteklenmez (buton yalnızca web'de görünür).
/// Bu stub yalnızca mobil/masaüstü derlemelerinin geçmesi için vardır (satış
/// yazdırma emsali).
void printLabelsA4({
  required List<LabelSlot?> slots,
  String? logoDataUrl,
}) {
  // No-op
}

/// Tel Etiketi yazdırma — web dışı platformlarda no-op (Raf Etiketi'nin
/// `printLabelsA4` no-op'uyla aynı desen).
void printTelLabelsA4({
  required List<LabelSlot?> slots,
  String? logoDataUrl,
}) {
  // No-op
}

/// Tel İndirim Etiketi yazdırma — web dışı platformlarda no-op (Tel
/// Etiketi'nin `printTelLabelsA4` no-op'uyla aynı desen).
void printTelDiscountLabelsA4({
  required List<TelDiscountLabelSlot?> slots,
  String? logoDataUrl,
  required TelDiscountKind generalKind,
  required num generalValue,
}) {
  // No-op
}

/// Geniş Logo etiketi yazdırma — web dışı platformlarda no-op (KARAR v1.14).
void printWideLabelsA4({
  required List<LabelSlot?> slots,
  String? logoDataUrl,
}) {
  // No-op
}

/// Poster (profesyonel ürün listesi) yazdırma — web dışı platformlarda no-op
/// (KARAR v1.23).
void printPosterA4({
  required List<LabelSlot> items,
  required String title,
  bool showBarcode = false,
  String? logoDataUrl,
}) {
  // No-op
}

/// Ürün Etiketi (6×12 = 72/sayfa) yazdırma — web dışı platformlarda no-op
/// (KARAR v1.21).
void printProductLabelsA4({
  required List<ProductLabelItem> items,
}) {
  // No-op
}

/// İndirim Etiketi (2×2 = 4/sayfa) yazdırma — web dışı platformlarda no-op.
void printDiscountLabelsA4({
  required List<DiscountLabelSlot?> slots,
  String? logoDataUrl,
  required num defaultPercent,
  String tagline = '',
}) {
  // No-op
}
