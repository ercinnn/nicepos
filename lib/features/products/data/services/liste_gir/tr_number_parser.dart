/// Türkçe binlik/ondalık ayraç belirsizliğini çözerek sayı ayrıştırır.
///
/// `products_list_screen.dart`'taki basit `_parseNum` (yalnız `,`→`.` çevirir)
/// gerçek tedarikçi listelerindeki `"1.234,56"` gibi binlik ayraçlı değerleri
/// bozar — bu yüzden Liste Gir için ayrı, daha kapsamlı bir ayrıştırıcı var.
///
/// Kural: hem `.` hem `,` varsa `.`=binlik, `,`=ondalık kabul edilir
/// (`"1.234,56"` → `1234.56`). Yalnız `,` varsa ondalık ayraç. Aksi halde
/// (yalnız `.` veya hiçbiri) doğrudan `double.parse`.
num parseTrNumber(String raw) {
  final cleaned = raw.trim().replaceAll(RegExp(r'[^0-9.,\-]'), '');
  if (cleaned.isEmpty) return 0;

  final hasDot = cleaned.contains('.');
  final hasComma = cleaned.contains(',');

  String normalized;
  if (hasDot && hasComma) {
    normalized = cleaned.replaceAll('.', '').replaceAll(',', '.');
  } else if (hasComma) {
    normalized = cleaned.replaceAll(',', '.');
  } else {
    normalized = cleaned;
  }

  return num.tryParse(normalized) ?? 0;
}

/// Barkod sütunundan gelen metni sadece rakamlara indirger (barkodlar hep
/// sayısaldır; OCR/pdf.js ara boşluk veya ayraç sızdırabilir).
String cleanBarcode(String raw) => raw.replaceAll(RegExp(r'[^0-9]'), '');
