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
          row.name = cellItems.map((e) => e.text.trim()).where((t) => t.isNotEmpty).join(' ');
        case ColumnType.quantity:
          row.quantity = parseTrNumber(cellItems.map((e) => e.text).join());
        case ColumnType.purchasePrice:
          row.purchasePrice = parseTrNumber(cellItems.map((e) => e.text).join());
      }
    }
    if (!row.isEmpty) result.add(row);
  }

  return result;
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
      if (row.purchasePrice != 0) existing.purchasePrice = row.purchasePrice;
      if (row.salePrice != 0) existing.salePrice = row.salePrice;
      if (existing.name.isEmpty && row.name.isNotEmpty) existing.name = row.name;
    }
  }
  return result;
}
