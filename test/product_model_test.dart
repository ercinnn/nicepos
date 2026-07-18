import 'package:flutter_test/flutter_test.dart';
import 'package:nice_pos/features/products/data/models/product.dart';

void main() {
  group('Product.toInsertMap', () {
    test('ürün adı büyük harfe çevrilir (kaynak fark etmeksizin)', () {
      const product = Product(name: 'kırmızı kalem');
      expect(product.toInsertMap()['name'], 'KIRMIZI KALEM');
    });

    test('Türkçe i/İ, ı/I ayrımı doğru katlanır', () {
      const product = Product(name: 'iğne ipliği');
      expect(product.toInsertMap()['name'], 'İĞNE İPLİĞİ');
    });

    test('zaten büyük harfli ad değişmeden kalır', () {
      const product = Product(name: 'BÜYÜK ÜRÜN ADI');
      expect(product.toInsertMap()['name'], 'BÜYÜK ÜRÜN ADI');
    });
  });
}
