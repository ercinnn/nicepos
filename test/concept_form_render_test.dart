import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nice_pos/core/utils/formatters.dart';
import 'package:nice_pos/features/products/data/models/concept_product.dart';
import 'package:nice_pos/features/products/data/models/product.dart';
import 'package:nice_pos/features/products/presentation/widgets/concept_form_dialog.dart';
import 'package:nice_pos/features/sales/application/barcode_cache.dart';

/// Supabase'e dokunmayan sahte barkod önbelleği (form açılışta ensureLoaded çağırır).
class _FakeBarcodeCache implements BarcodeCache {
  @override
  Future<void> ensureLoaded() async {}
  @override
  Product? lookup(String barcode) => null;
  @override
  void put(Product product) {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _concept = ConceptProduct(
  id: 'c1',
  barcode: 'C261002001',
  name: 'Papatyalı Vazo Konsepti',
  items: [
    ConceptProductItem(
      productId: 'v',
      quantity: 1,
      discountValue: 10,
      product: Product(id: 'v', barcode: '10001', name: 'Seramik Vazo Büyük Boy Beyaz', price1: 300),
    ),
    ConceptProductItem(
      productId: 'p',
      quantity: 2,
      product: Product(id: 'p', barcode: '20002', name: 'Papatya', price1: 100),
    ),
    ConceptProductItem(
      productId: 'o',
      quantity: 5,
      discountValue: 15,
      discountType: DiscountType.tl,
      product: Product(id: 'o', barcode: '20003', name: 'Okaliptus', price1: 40),
    ),
  ],
);

void main() {
  for (final size in const [Size(360, 800), Size(1280, 800)]) {
    testWidgets('konsept formu ${size.width.toInt()}px genişlikte parça indirimleriyle taşmadan açılır',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(ProviderScope(
        overrides: [barcodeCacheProvider.overrideWithValue(_FakeBarcodeCache())],
        child: const MaterialApp(home: Scaffold(body: ConceptFormDialog(concept: _concept))),
      ));
      await tester.pump();

      expect(tester.takeException(), isNull);
      // 300 + 200 + 200 = 700 brüt; −30 (%10) −15 (₺) = 655
      expect(find.text('Satış fiyatı: ${formatCurrency(655)}'), findsOneWidget);
      expect(find.text('İndirim: -${formatCurrency(45)}'), findsOneWidget);
      expect(find.text('Yok'), findsNWidgets(3));
    });
  }
}
