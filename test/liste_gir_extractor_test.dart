import 'package:flutter_test/flutter_test.dart';
import 'package:nice_pos/features/products/data/models/liste_gir/column_band.dart';
import 'package:nice_pos/features/products/data/models/liste_gir/column_type.dart';
import 'package:nice_pos/features/products/data/models/liste_gir/extracted_row.dart';
import 'package:nice_pos/features/products/data/models/liste_gir/positioned_text.dart';
import 'package:nice_pos/features/products/data/services/liste_gir/column_row_extractor.dart';
import 'package:nice_pos/features/products/data/services/liste_gir/tr_number_parser.dart';

void main() {
  group('parseTrNumber', () {
    test('binlik + ondalık ayraç birlikte', () {
      expect(parseTrNumber('1.234,56'), 1234.56);
    });
    test('yalnız ondalık virgül', () {
      expect(parseTrNumber('90,00'), 90.0);
    });
    test('yalnız tam sayı', () {
      expect(parseTrNumber('25'), 25);
    });
    test('boş metin', () {
      expect(parseTrNumber(''), 0);
    });
  });

  group('cleanBarcode', () {
    test('boşluk/ayraç temizler', () {
      expect(cleanBarcode('8698268 810145'), '8698268810145');
    });
  });

  group('extractRows', () {
    // liste01.PDF'teki gerçek bir satırın yaklaşık düzenini simüle eder:
    // "Y-240   50 CM KROM AYAKKABI ÇEKECEĞİ   1234567891781   90,00"
    test('tek satır, 4 sütun (barkod+ad+adet+alış) doğru ayrıştırılır', () {
      final bands = [
        ColumnBand(type: ColumnType.name, left: 0, right: 200),
        ColumnBand(type: ColumnType.barcode, left: 200, right: 320),
        ColumnBand(type: ColumnType.quantity, left: 320, right: 380),
        ColumnBand(type: ColumnType.purchasePrice, left: 380, right: 440),
      ];
      final items = [
        const PositionedText(text: '50 CM KROM AYAKKABI', x: 10, y: 100, width: 150, height: 12),
        const PositionedText(text: 'ÇEKECEĞİ', x: 165, y: 100, width: 30, height: 12),
        const PositionedText(text: '1234567891781', x: 205, y: 101, width: 100, height: 12),
        const PositionedText(text: '12', x: 325, y: 100, width: 20, height: 12),
        const PositionedText(text: '90,00', x: 385, y: 100, width: 40, height: 12),
      ];

      final rows = extractRows(items: items, bands: bands);

      expect(rows, hasLength(1));
      final row = rows.single;
      expect(row.name, '50 CM KROM AYAKKABI ÇEKECEĞİ');
      expect(row.barcode, '1234567891781');
      expect(row.quantity, 12);
      expect(row.purchasePrice, 90.0);
    });

    test('iki satır y-konumuna göre ayrı kümelenir', () {
      final bands = [
        ColumnBand(type: ColumnType.name, left: 0, right: 200),
        ColumnBand(type: ColumnType.quantity, left: 200, right: 260),
      ];
      final items = [
        const PositionedText(text: 'ÜRÜN A', x: 10, y: 100, width: 60, height: 12),
        const PositionedText(text: '5', x: 210, y: 101, width: 10, height: 12),
        const PositionedText(text: 'ÜRÜN B', x: 10, y: 130, width: 60, height: 12),
        const PositionedText(text: '7', x: 210, y: 131, width: 10, height: 12),
      ];

      final rows = extractRows(items: items, bands: bands);

      expect(rows, hasLength(2));
      expect(rows[0].name, 'ÜRÜN A');
      expect(rows[0].quantity, 5);
      expect(rows[1].name, 'ÜRÜN B');
      expect(rows[1].quantity, 7);
    });

    test('bant dışına düşen metin yok sayılır', () {
      final bands = [
        ColumnBand(type: ColumnType.name, left: 0, right: 100),
      ];
      final items = [
        const PositionedText(text: 'BAŞLIK SATIRI DIŞARIDA', x: 500, y: 10, width: 100, height: 12),
        const PositionedText(text: 'ÜRÜN', x: 10, y: 100, width: 40, height: 12),
      ];

      final rows = extractRows(items: items, bands: bands);

      expect(rows, hasLength(1));
      expect(rows.single.name, 'ÜRÜN');
    });

    test('barkod bandı yoksa diğer sütunlar yine çıkar (liste02 senaryosu)', () {
      final bands = [
        ColumnBand(type: ColumnType.name, left: 0, right: 200),
        ColumnBand(type: ColumnType.quantity, left: 200, right: 260),
        ColumnBand(type: ColumnType.purchasePrice, left: 260, right: 320),
      ];
      final items = [
        const PositionedText(text: 'EGE YEMEK KAŞIĞI', x: 10, y: 100, width: 150, height: 12),
        const PositionedText(text: '4', x: 210, y: 100, width: 10, height: 12),
        const PositionedText(text: '437,00', x: 265, y: 100, width: 40, height: 12),
      ];

      final rows = extractRows(items: items, bands: bands);

      expect(rows, hasLength(1));
      expect(rows.single.barcode, '');
      expect(rows.single.name, 'EGE YEMEK KAŞIĞI');
      expect(rows.single.quantity, 4);
      expect(rows.single.purchasePrice, 437.0);
    });

    test('boş girdi listesi boş sonuç döner', () {
      expect(extractRows(items: [], bands: [ColumnBand(type: ColumnType.name, left: 0, right: 10)]), isEmpty);
      expect(extractRows(items: [const PositionedText(text: 'x', x: 0, y: 0, width: 1, height: 1)], bands: []), isEmpty);
    });
  });

  group('consolidateDuplicateBarcodes', () {
    test('aynı barkodlu satırlar toplanır, fiyat son sıfır-olmayan değeri alır', () {
      final rows = [
        ExtractedRow(barcode: '111', name: 'A', quantity: 5, purchasePrice: 10, salePrice: 15),
        ExtractedRow(barcode: '111', name: '', quantity: 3, purchasePrice: 12, salePrice: 0),
        ExtractedRow(barcode: '222', name: 'B', quantity: 1, purchasePrice: 20, salePrice: 25),
      ];

      final result = consolidateDuplicateBarcodes(rows);

      expect(result, hasLength(2));
      final merged = result.firstWhere((r) => r.barcode == '111');
      expect(merged.quantity, 8);
      expect(merged.purchasePrice, 12);
      expect(merged.salePrice, 15); // 0 yeni değer eskisini silmedi
      expect(merged.name, 'A');
    });

    test('barkodu boş satırlar birleştirilmeden ayrı kalır', () {
      final rows = [
        ExtractedRow(barcode: '', name: 'A', quantity: 1),
        ExtractedRow(barcode: '', name: 'B', quantity: 1),
      ];
      expect(consolidateDuplicateBarcodes(rows), hasLength(2));
    });
  });
}
