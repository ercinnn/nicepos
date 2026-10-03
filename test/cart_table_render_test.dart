import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nice_pos/core/utils/formatters.dart';
import 'package:nice_pos/features/products/data/models/product.dart';
import 'package:nice_pos/features/sales/application/sales_cart_notifier.dart';
import 'package:nice_pos/features/sales/presentation/widgets/cart_table.dart';

/// CartTable render regresyon testleri.
///
/// YAKALANAN HATA (mobil satış ekranı tamamen kırmızı hata ekranıydı):
/// `_buildMobileList` alt özet satırı şu zinciri kuruyor —
///   LayoutBuilder → SingleChildScrollView(Axis.horizontal)
///                 → ConstrainedBox(minWidth: maxWidth) → Row(... Spacer() ...)
/// Yatay `SingleChildScrollView` çocuğuna SINIRSIZ genişlik verir; `minWidth`
/// yalnız ALT sınır koyduğu için kısıt `312.0 <= w <= Infinity` kalır. İçindeki
/// `Row` bir `Spacer` (flex) taşıdığından Flutter
/// "RenderFlex children have non-zero flex but incoming width constraints are
/// unbounded" fırlatır ve TÜM ekran çöker.
///
/// Düzeltme, masaüstü ikizi `_buildFooter` ile birebir aynı desendir:
/// `ConstrainedBox`'ın çocuğunu `IntrinsicWidth` ile sarmak. `IntrinsicWidth`
/// Row'un doğal genişliğini ölçüp aşağıya SIKI bir genişlik kısıtı geçirir →
/// flex çözülebilir hale gelir.
///
/// Bu testler DÜZELTMEDEN ÖNCE KIRMIZIDIR: `tester.takeException()` yukarıdaki
/// `FlutterError`'ı döndürür ve alt özet satırı (Muhtelif / Ara Toplam) layout
/// edilemediği için `find` beklentileri de düşer. Bu sınıf hataları
/// `flutter analyze`'da GÖRÜNMEZ — yalnız gerçek render yakalar.
void main() {
  /// Sepet widget'ını verilen mantıksal ekran boyutunda pump eder.
  Future<ProviderContainer> pumpCartTable(
    WidgetTester tester, {
    required Size size,
    void Function(SalesCart cart)? setup,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer();
    addTearDown(container.dispose);
    setup?.call(container.read(salesCartProvider.notifier));

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: CartTable())),
      ),
    );
    await tester.pump();
    return container;
  }

  testWidgets('CartTable mobil (360x800) boş sepette hatasız render olur', (
    tester,
  ) async {
    await pumpCartTable(tester, size: const Size(360, 800));

    // Regresyon: unbounded-width + Spacer çökmesi olmamalı.
    expect(tester.takeException(), isNull);

    // Alt özet satırı gerçekten layout edilmiş olmalı (yalnız "exception yok"
    // yetmez — subtree hiç kurulmasa da exception null olabilirdi).
    expect(find.text('Muhtelif'), findsOneWidget);
    expect(find.textContaining('Ara Toplam'), findsOneWidget);
    expect(find.text('Sepet boş'), findsOneWidget);
  });

  testWidgets(
    'CartTable mobil (360x800) dolu sepette + genel iskontoyla hatasız render olur',
    (tester) async {
      // Dolu sepet, alt özet satırının EN GENİŞ halini kurar: "Muhtelif"
      // butonu + Ara Toplam + "İskonto: -₺..." kırılımı. Doğal genişlik
      // 360px'i aşarsa satır yatay kaydırılır; kırpılmaz ve ÇÖKMEZ.
      await pumpCartTable(
        tester,
        size: const Size(360, 800),
        setup: (cart) {
          cart.addMiscItem(1250, note: 'Uzun Ürün Adı Testi');
          cart.addMiscItem(890, note: 'İkinci Kalem');
          cart.setDiscount(15, DiscountType.percent);
        },
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Muhtelif'), findsOneWidget);
      expect(find.textContaining('İskonto:'), findsOneWidget);
    },
  );

  testWidgets(
    'CartTable mobil (360x800): barkod ile birim fiyat birbirine yapışmaz',
    (tester) async {
      // YAKALANAN HATA: barkod + birim fiyat boşluksuz bir Row'daydı; dar
      // ekranda barkod Expanded içinde sessizce kesilip fiyata yapışıyordu
      // ("86910017811₺179,00"). Wrap'e çevrildi: aralarında en az 8px kalır
      // ya da fiyat alt satıra iner.
      await pumpCartTable(
        tester,
        size: const Size(360, 800),
        setup: (cart) => cart.addProduct(const Product(
          id: 'p1',
          barcode: '8691000000002',
          name: 'GRANİT TENCERE SETİ 7 PARÇA',
          price1: 2450,
        )),
      );

      expect(tester.takeException(), isNull);
      final barcode = tester.getRect(find.text('8691000000002'));
      final unitPrice = tester.getRect(find.byWidgetPredicate((w) =>
          w is Text && w.data == formatCurrency(2450) && w.style?.fontSize == 11));
      final sameLineWithGap = unitPrice.left >= barcode.right + 8;
      final wrappedBelow = unitPrice.top >= barcode.bottom;
      expect(sameLineWithGap || wrappedBelow, isTrue,
          reason: 'barkod $barcode, birim fiyat $unitPrice');
    },
  );

  testWidgets('CartTable masaüstünde (1280x800) hatasız render olur', (
    tester,
  ) async {
    // Masaüstü ikizi (_buildFooter) zaten IntrinsicWidth kullanıyor; bu test
    // o güvenlik ağının ileride sökülmesine karşı koruma sağlar.
    await pumpCartTable(
      tester,
      size: const Size(1280, 800),
      setup: (cart) => cart.addMiscItem(500, note: 'Kalem'),
    );

    expect(tester.takeException(), isNull);
    expect(find.textContaining('Ara Toplam'), findsOneWidget);
    expect(find.textContaining('Genel İskonto'), findsOneWidget);
  });
}
