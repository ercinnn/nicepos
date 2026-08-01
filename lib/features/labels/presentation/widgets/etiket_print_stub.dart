import '../../data/models/label_slot.dart';
import '../../data/models/product_label_item.dart';

/// Web dışı platformlarda yazdırma desteklenmez (buton yalnızca web'de görünür).
/// Bu stub yalnızca mobil/masaüstü derlemelerinin geçmesi için vardır (satış
/// yazdırma emsali).
void printLabelsA4({
  required List<LabelSlot?> slots,
  String? logoDataUrl,
}) {
  // No-op
}

/// Geniş Logo etiketi yazdırma — web dışı platformlarda no-op (KARAR v1.14).
void printWideLabelsA4({
  required List<LabelSlot?> slots,
  required String figurDataUrl,
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
