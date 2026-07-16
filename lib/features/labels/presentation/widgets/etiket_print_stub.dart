import '../../data/models/label_slot.dart';

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
  required String tenteDataUrl,
}) {
  // No-op
}
