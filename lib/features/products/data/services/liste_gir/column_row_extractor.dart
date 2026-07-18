import '../../models/liste_gir/column_band.dart';
import '../../models/liste_gir/column_type.dart';
import '../../models/liste_gir/extracted_row.dart';
import '../../models/liste_gir/positioned_text.dart';
import 'tr_number_parser.dart';

/// Sütun bantları + konumlu metin öğelerinden satır listesi çıkarır.
///
/// Saf Dart, tarayıcı/web bağımlılığı yok — pdf.js VE Tesseract çıktısı aynı
/// `PositionedText` şekline dönüştürüldüğü için ikisine karşı da çalışır.
/// Kümeleme sezgiseldir (bkz. plan) — kusurlar önizleme ızgarasında elle
/// düzeltilir, bu yüzden burada "en iyi çaba" yeterlidir.
List<ExtractedRow> extractRows({
  required List<PositionedText> items,
  required List<ColumnBand> bands,
}) {
  if (bands.isEmpty || items.isEmpty) return [];

  // 1) Sınıflandır: her öğe merkez-X'i hangi banda düşüyorsa o tipe atanır.
  final classified = <(ColumnType, PositionedText)>[];
  for (final item in items) {
    for (final band in bands) {
      if (band.contains(item.centerX)) {
        classified.add((band.type, item));
        break;
      }
    }
  }
  if (classified.isEmpty) return [];

  // 2) Satır toleransı: sınıflandırılmış öğelerin medyan yüksekliği * 0.6.
  final heights = classified.map((c) => c.$2.height).toList()..sort();
  final medianHeight = heights[heights.length ~/ 2];
  final rowTolerance = (medianHeight * 0.6).clamp(2.0, 100.0);

  // 3) Tüm sınıflandırılmış öğeleri y'ye göre sırala, tek geçişli açgözlü
  // kümeleme ile satırlara ayır (kümeler birden fazla sütun tipinden öğe
  // içerebilir — bu istenen davranış).
  final sorted = [...classified]..sort((a, b) => a.$2.y.compareTo(b.$2.y));

  final rows = <List<(ColumnType, PositionedText)>>[];
  double clusterAnchorY = sorted.first.$2.y;
  var clusterCount = 0;
  var clusterSumY = 0.0;

  for (final entry in sorted) {
    final y = entry.$2.y;
    if (rows.isEmpty || y - clusterAnchorY > rowTolerance) {
      rows.add([entry]);
      clusterCount = 1;
      clusterSumY = y;
      clusterAnchorY = y;
    } else {
      rows.last.add(entry);
      clusterCount++;
      clusterSumY += y;
      clusterAnchorY = clusterSumY / clusterCount;
    }
  }

  // 4) Her satır kümesinden ExtractedRow inşa et.
  final result = <ExtractedRow>[];
  for (final rowItems in rows) {
    final row = ExtractedRow();
    for (final type in ColumnType.values) {
      final cellItems = rowItems.where((e) => e.$1 == type).map((e) => e.$2).toList()
        ..sort((a, b) => a.x.compareTo(b.x));
      if (cellItems.isEmpty) continue;

      switch (type) {
        case ColumnType.barcode:
          row.barcode = cleanBarcode(cellItems.map((e) => e.text).join());
        case ColumnType.name:
          row.name = _joinNameItems(cellItems);
        case ColumnType.quantity:
          row.quantity = parseTrNumber(cellItems.map((e) => e.text).join());
        case ColumnType.purchasePrice:
          final price = parseTrNumber(cellItems.map((e) => e.text).join());
          row.purchasePrice = price;
          row.rawPurchasePrice = price;
      }
    }
    if (!row.isEmpty) result.add(row);
  }

  return result.where((row) => !_looksLikeNonProduct(row)).toList();
}

// Fatura üst/alt bilgisinde çıkan alıcı adı, firma adı, e-posta gibi ürün
// OLMAYAN metinler — bantlar tam sayfa yüksekliğinde olduğundan (KARAR:
// sütun başına tek dikdörtgen) bu satırlar bazen "Ürün Adı" bandına da
// düşüp sahte satır üretiyordu. Kullanıcının kendi işletme kimliği burada
// sabit bir liste olarak tutuluyor; başka metinler önizleme ızgarasında
// elle silinebilir (satır başına çöp kutusu ikonu zaten var).
const _knownNonProductPhrases = [
  'ERDİNÇ ÇAKALOĞLU',
  'BENİM DİDİM',
];

bool _looksLikeNonProduct(ExtractedRow row) {
  if (row.name.contains('@')) return true;
  final upperName = _trUpper(row.name);
  return _knownNonProductPhrases.any((phrase) => upperName.contains(_trUpper(phrase)));
}

// Türkçe büyük harf katlaması: Dart'ın yerleşik toUpperCase'i i/İ, ı/I
// çiftlerini yanlış katlar (bkz. product_repository.dart'taki aynı desen).
String _trUpper(String s) => s.replaceAll('i', 'İ').replaceAll('ı', 'I').toUpperCase();

/// Ürün adı sütunundaki metin öğelerini birleştirir — YALNIZ aralarında
/// gerçek görsel boşluk varsa (bir sonraki öğe bir öncekinin bittiği yerden
/// belirgin uzaktaysa) araya boşluk eklenir. Bu ayrım şart: bazı PDF
/// üreticileri Türkçe noktalı büyük "İ" harfini farklı bir font alt-kümesiyle
/// (ve dolayısıyla ayrı bir pdf.js metin öğesi olarak, ama aralarında hiç
/// gerçek boşluk olmadan) yazar — kör bir `.join(' ')` bu durumda İ'nin
/// önüne ve arkasına yanlış boşluk sokuyordu.
String _joinNameItems(List<PositionedText> items) {
  if (items.isEmpty) return '';
  final buffer = StringBuffer(items.first.text);
  for (var i = 1; i < items.length; i++) {
    final prev = items[i - 1];
    final cur = items[i];
    final gap = cur.x - (prev.x + prev.width);
    final avgHeight = (prev.height + cur.height) / 2;
    if (avgHeight > 0 && gap > avgHeight * 0.2) buffer.write(' ');
    buffer.write(cur.text);
  }
  return buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Aynı barkodlu satırları birleştirir: adetler toplanır (additive), fiyat
/// alanlarında sıfır olmayan son değer kazanır (boş/sıfır bir öncekini
/// silmez). Barkodu boş satırlar birleştirilmeden ayrı geçer — her biri kendi
/// başına yeni ürün adayı olarak kalır.
List<ExtractedRow> consolidateDuplicateBarcodes(List<ExtractedRow> rows) {
  final byBarcode = <String, ExtractedRow>{};
  final result = <ExtractedRow>[];
  for (final row in rows) {
    if (row.barcode.isEmpty) {
      result.add(row);
      continue;
    }
    final existing = byBarcode[row.barcode];
    if (existing == null) {
      byBarcode[row.barcode] = row;
      result.add(row);
    } else {
      existing.quantity = existing.quantity + row.quantity;
      if (row.purchasePrice != 0) {
        existing.purchasePrice = row.purchasePrice;
        existing.rawPurchasePrice = row.rawPurchasePrice;
      }
      if (row.salePrice != 0) existing.salePrice = row.salePrice;
      if (existing.name.isEmpty && row.name.isNotEmpty) existing.name = row.name;
    }
  }
  return result;
}
