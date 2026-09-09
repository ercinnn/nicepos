import 'package:flutter_test/flutter_test.dart';
import 'package:nice_pos/features/labels/data/models/label_pool_item.dart';
import 'package:nice_pos/features/labels/data/models/label_slot.dart';

LabelPoolItem _item({
  String barcode = '260814001',
  String name = 'Test Ürün',
  num? price = 10,
  required int quantity,
  int kontrol = 0,
}) {
  return LabelPoolItem(
    id: barcode,
    labelType: kLabelPoolTypeRaf,
    barcode: barcode,
    productName: name,
    price: price,
    quantity: quantity,
    kontrol: kontrol,
    createdAt: DateTime(2026, 8, 14),
  );
}

void main() {
  group('paginateLabelPoolItems', () {
    test('kalem yoksa tek boş sayfa döner', () {
      final pages = paginateLabelPoolItems([], 24);
      expect(pages.length, 1);
      expect(pages.single, List<LabelSlot?>.filled(24, null));
    });

    test('36 kalem (24 kapasiteyle) 24+12 olarak 2 sayfaya bölünür (kullanıcı örneği)', () {
      final pages = paginateLabelPoolItems([_item(quantity: 36)], 24);
      expect(pages.length, 2);
      expect(pages[0].where((s) => s != null).length, 24);
      expect(pages[1].where((s) => s != null).length, 12);
    });

    test('tam kapasiteye bölünen adet fazladan boş sayfa açmaz', () {
      final pages = paginateLabelPoolItems([_item(quantity: 48)], 24);
      expect(pages.length, 2);
      expect(pages[0].where((s) => s != null).length, 24);
      expect(pages[1].where((s) => s != null).length, 24);
    });

    test('birden fazla kalem adet sırasıyla akar (DB eklenme sırası korunur)', () {
      final pages = paginateLabelPoolItems(
        [
          _item(barcode: 'A', quantity: 3),
          _item(barcode: 'B', quantity: 1),
          _item(barcode: 'C', quantity: 3),
        ],
        24,
      );
      final flat = pages.expand((p) => p).where((s) => s != null).map((s) => s!.barcode).toList();
      expect(flat, ['A', 'A', 'A', 'B', 'C', 'C', 'C']);
    });

    test("'urun' tipinde price null ise LabelSlot.price 0'a düşer", () {
      final pages = paginateLabelPoolItems([_item(price: null, quantity: 1)], 24);
      expect(pages.single.firstWhere((s) => s != null)!.price, 0);
    });
  });
}
