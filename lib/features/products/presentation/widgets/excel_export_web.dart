import 'dart:js_interop';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:web/web.dart' as web;

import '../../data/models/product.dart';

Future<String?> exportProductsToExcel(List<Product> products) async {
  final bytes = _buildExcel(products);
  if (bytes == null) return null;

  final uint8Array = Uint8List.fromList(bytes).toJS;
  final blob = web.Blob(
    [uint8Array].toJS,
    web.BlobPropertyBag(
      type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    ),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = url
    ..setAttribute('download', 'urunler.xlsx')
    ..click();
  web.URL.revokeObjectURL(url);
  anchor.remove();
  return null; // Web'de indirme otomatik tetiklenir
}

List<int>? _buildExcel(List<Product> products) {
  final workbook = Excel.createExcel();
  final sheetName = workbook.getDefaultSheet() ?? 'Sheet1';
  final sheet = workbook[sheetName];

  sheet.appendRow([
    TextCellValue('Barkod'),
    TextCellValue('Ürün Adı'),
    TextCellValue('Stok'),
    TextCellValue('Birim'),
    TextCellValue('Fiyat 1'),
    TextCellValue('KDV'),
    TextCellValue('Alış Fiyatı'),
    TextCellValue('Üst Ürün Grubu'),
    TextCellValue('Ürün Grubu'),
    TextCellValue('Fiyat 2'),
    TextCellValue('Stok Kodu'),
    TextCellValue('Ürün Detayı'),
    TextCellValue('Kritik Stok'),
    TextCellValue('Menşe'),
  ]);

  for (final p in products) {
    sheet.appendRow([
      TextCellValue(p.barcode ?? ''),
      TextCellValue(p.name),
      DoubleCellValue(p.stockQuantity.toDouble()),
      TextCellValue(p.unit),
      DoubleCellValue(p.price1.toDouble()),
      DoubleCellValue(p.vatRate.toDouble()),
      DoubleCellValue(p.purchasePrice.toDouble()),
      TextCellValue(''),
      TextCellValue(p.groupName ?? ''),
      DoubleCellValue(p.price2.toDouble()),
      TextCellValue(p.stockCode ?? ''),
      TextCellValue(p.description ?? ''),
      DoubleCellValue(p.criticalStock.toDouble()),
      TextCellValue(p.originCountry ?? ''),
    ]);
  }

  return workbook.encode();
}
