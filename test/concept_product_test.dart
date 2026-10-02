import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nice_pos/features/products/data/models/concept_product.dart';
import 'package:nice_pos/features/products/data/models/product.dart';
import 'package:nice_pos/features/products/presentation/screens/product_form_screen.dart'
    show nextBarcodeCandidate;
import 'package:nice_pos/features/sales/application/sales_cart_notifier.dart';
import 'package:nice_pos/features/sales/data/models/cart_item.dart';
import 'package:nice_pos/features/sales/presentation/widgets/cart_table.dart';

const _vazo = Product(id: 'v', barcode: '10001', name: 'Vazo', price1: 300);
const _papatya = Product(id: 'p', barcode: '20002', name: 'Papatya', price1: 100);
const _okaliptus = Product(id: 'o', barcode: '20003', name: 'Okaliptus', price1: 40);

// Parça toplamı: 1×300 + 2×100 + 5×40 = 700
ConceptProduct _concept({num? price}) => ConceptProduct(
      id: 'c1',
      barcode: 'C261002001',
      name: 'Papatyalı Vazo',
      price: price,
      items: const [
        ConceptProductItem(productId: 'v', quantity: 1, product: _vazo),
        ConceptProductItem(productId: 'p', quantity: 2, product: _papatya),
        ConceptProductItem(productId: 'o', quantity: 5, product: _okaliptus),
      ],
    );

num _sum(List<CartItem> items) => items.fold<num>(0, (s, i) => s + i.total);

void main() {
  group('konsept barkodu', () {
    test('C + YYAAGG öneki ve sıra numarası', () {
      final prefix = conceptBarcodePrefix(DateTime(2026, 10, 2));
      expect(prefix, 'C261002');
      expect(nextBarcodeCandidate(prefix, {}), 'C261002001');
      expect(nextBarcodeCandidate(prefix, {'C261002001'}), 'C261002002');
    });

    test('biçim tanıma', () {
      expect(looksLikeConceptBarcode('C261002001'), isTrue);
      expect(looksLikeConceptBarcode('c261002001'), isTrue);
      expect(looksLikeConceptBarcode('10001'), isFalse);
      expect(looksLikeConceptBarcode('C26100200'), isFalse);
    });
  });

  group('conceptCartLines', () {
    test('fiyatsız konsept: parçalar kendi fiyatıyla, adetleriyle eklenir', () {
      final lines = conceptCartLines(_concept());
      expect(lines.map((l) => (l.productId, l.quantity)).toList(),
          [('v', 1), ('p', 2), ('o', 5)]);
      expect(lines.every((l) => l.discountValue == 0), isTrue);
      expect(lines.every((l) => l.conceptCode == 'C261002001'), isTrue);
      expect(_sum(lines), 700);
    });

    test('konsept fiyatı düşükse fark oransal yüzde iskonto olur', () {
      final lines = conceptCartLines(_concept(price: 560));
      expect(lines.every((l) => l.discountType == DiscountType.percent), isTrue);
      expect(lines.first.discountValue, closeTo(20, 1e-9));
      expect(_sum(lines), closeTo(560, 1e-9));
    });

    test('konsept fiyatı yüksekse birim fiyatlar oranla artar', () {
      final lines = conceptCartLines(_concept(price: 770));
      expect(lines.every((l) => l.discountValue == 0), isTrue);
      expect(lines.first.unitPrice, closeTo(330, 1e-9));
      expect(_sum(lines), closeTo(770, 1e-9));
    });

    test('parça toplamı 0 ise tutar ilk satıra yazılır', () {
      const free = ConceptProduct(id: 'c', barcode: 'C261002002', name: 'X', price: 90, items: [
        ConceptProductItem(productId: 'a', quantity: 3, product: Product(id: 'a', name: 'A')),
        ConceptProductItem(productId: 'b', quantity: 1, product: Product(id: 'b', name: 'B')),
      ]);
      final lines = conceptCartLines(free);
      expect(lines.first.unitPrice, 30);
      expect(_sum(lines), 90);
    });

    test('ürünü okunamayan parça atlanır', () {
      const c = ConceptProduct(id: 'c', barcode: 'C261002003', name: 'X', items: [
        ConceptProductItem(productId: 'v', quantity: 1, product: _vazo),
        ConceptProductItem(productId: 'gone', quantity: 2),
      ]);
      expect(conceptCartLines(c).map((l) => l.productId), ['v']);
    });
  });

  group('SalesCart.addConcept', () {
    test('aynı konsept iki kez okutulunca adetler ikiye katlanır, toplam korunur', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final cart = container.read(salesCartProvider.notifier);

      cart.addConcept(_concept(price: 560));
      cart.addConcept(_concept(price: 560));

      final items = container.read(salesCartProvider).active.items;
      expect(items.length, 3);
      expect(items.map((i) => i.quantity), [2, 4, 10]);
      expect(container.read(salesCartProvider).active.subtotal, closeTo(1120, 1e-9));
    });

    test('tekil ürün okutması konsept satırıyla birleşmez', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final cart = container.read(salesCartProvider.notifier);

      cart.addConcept(_concept(price: 560));
      cart.addProduct(_vazo);
      cart.addProduct(_vazo);

      final items = container.read(salesCartProvider).active.items;
      expect(items.length, 4);
      final single = items.last;
      expect(single.conceptCode, isNull);
      expect(single.quantity, 2);
      expect(single.discountValue, 0);
    });

    test('CartItem.toMap/fromMap konsept kodunu korur (offline kuyruk)', () {
      final line = conceptCartLines(_concept()).first;
      expect(CartItem.fromMap(line.toMap()).conceptCode, 'C261002001');
    });
  });

  group('sepet render', () {
    for (final size in const [Size(360, 800), Size(1280, 800)]) {
      testWidgets('konsept satırları ${size.width.toInt()}px genişlikte taşmadan render olur', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final container = ProviderContainer();
        addTearDown(container.dispose);
        container.read(salesCartProvider.notifier).addConcept(_concept(price: 560));

        await tester.pumpWidget(UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: Scaffold(body: CartTable())),
        ));
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(find.text('Konsept C261002001'), findsNWidgets(3));
      });
    }
  });
}
