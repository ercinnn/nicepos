import 'dart:io';

import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';

import '../../data/models/product.dart';

Future<String?> exportProductsToExcel(List<Product> products) async {
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

  final bytes = workbook.encode();
  if (bytes == null) return null;

  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/urunler.xlsx');
  await file.writeAsBytes(bytes);
  return file.path;
}
