// Regresyon testi — Ürün Etiketi (6×12 = 72/A4, KARAR v1.21 / v1.21.1): sıkı
// 17mm iç yükseklik bütçesinde (2 satır ad + SABİT 7mm barkod + barkod no) bir
// hücre, 2 satıra taşan uzun bir ürün adıyla crash/overflow vermeden render
// edilmeli. Barkod bandı artık ESNEK değil, SABİT 7mm (KARAR v1.21.1) —
// aşağıdaki test bunu doğrular. v1.20.1 dersi: barkod alanına sıfır/negatif
// yükseklik düşerse `barcode` paketinin `assert(height > 0)` kontrolü GERÇEK bir
// Flutter çökmesine yol açar; bu yüzden savunma eşiği (yükseklik altındaysa HİÇ
// render edilmez) korunur. Bu test hem o çökmeyi hem 7mm sabitini yakalar.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nice_pos/features/labels/data/models/product_label_item.dart';
import 'package:nice_pos/features/labels/presentation/screens/labels_screen.dart';

void main() {
  // 2 satıra taşan (uzun) ürün adı — sıkı bütçe repro senaryosu.
  const longName =
      'Cok Uzun Bir Urun Adi Ornegi Iki Satira Tasan Metin Ekstra Kelimeler AAA';
  const shortName = 'Su 0.5L';

  List<ProductLabelItem?> buildPage() {
    final slots = List<ProductLabelItem?>.filled(kProductLabelPerPage, null);
    slots[0] = const ProductLabelItem(
      barcode: '8690000000017',
      productName: longName,
      quantity: 1,
    );
    slots[1] = const ProductLabelItem(
      barcode: '8690000000024',
      productName: shortName,
      quantity: 1,
    );
    // Son hücre de dolu (ızgara sınırında da render kontrolü).
    slots[kProductLabelPerPage - 1] = const ProductLabelItem(
      barcode: '8690000000031',
      productName: 'Aycicek Yagi 5L Premium Kalite Bidon Ekonomik Paket',
      quantity: 1,
    );
    return slots;
  }

  testWidgets(
    'uzun (2 satırlık) ürün adıyla crash/overflow olmadan render edilir',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(900, 1250));

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            backgroundColor: Colors.white,
            body: Center(child: buildProductLabelPageForGolden(buildPage())),
          ),
        ),
      );
      await tester.pump();

      // Ne barkod `assert` çökmesi ne de RenderFlex/paragraph overflow olmalı.
      expect(tester.takeException(), isNull,
          reason:
              '2 satırlık uzun ürün adıyla hiçbir istisna/overflow olmamalı '
              '(KARAR v1.21 sıkı bütçe + v1.20.1 savunma deseni)');
    },
  );

  testWidgets(
    'barkod bandı SABİT 7mm yükseklikte (KARAR v1.21.1, esnek değil)',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(900, 1250));

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            backgroundColor: Colors.white,
            body: Center(child: buildProductLabelPageForGolden(buildPage())),
          ),
        ),
      );
      await tester.pump();

      // 7mm @96dpi = 7 * 3.7795 ≈ 26.46px. Golden tuval FittedBox olmadan
      // native ölçekte render edilir → bant tam sabit yükseklikte olmalı.
      const expected7mmPx = 7 * 3.7795;
      final areas = find.byKey(const Key('prodBarcodeArea'));
      // Dolu hücre sayısı kadar (bu sayfada 3) barkod bandı bulunmalı.
      expect(areas, findsWidgets);
      for (final el in areas.evaluate()) {
        final size = tester.getSize(find.byWidget(el.widget));
        expect(size.height, closeTo(expected7mmPx, 0.5),
            reason: 'Barkod bandı SABİT 7mm olmalı (esnek Expanded değil)');
      }
    },
  );

  testWidgets('Ürün Etiketi 6×12 önizleme golden PNG üretir (uzun ad dahil)',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1250));

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Colors.white,
          body: Center(
            child: RepaintBoundary(
              key: const Key('golden'),
              child: buildProductLabelPageForGolden(buildPage()),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);

    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const Key('golden')),
    );
    late Uint8List pngBytes;
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2.0);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      pngBytes = data!.buffer.asUint8List();
    });

    File('product_label_golden.png').writeAsBytesSync(pngBytes);
    expect(pngBytes.lengthInBytes, greaterThan(0));
  });

  test('paginateProductLabels: 72 sınırında çok-sayfaya taşar', () {
    // 100 etiket → 2 sayfa (72 + 28). Tek kalem, adet 100.
    final pages = paginateProductLabels(const [
      ProductLabelItem(
          barcode: '8690000000017', productName: 'X', quantity: 100),
    ]);
    expect(pages.length, 2);
    expect(pages[0].where((s) => s != null).length, 72);
    expect(pages[1].where((s) => s != null).length, 28);

    // Boş → tek boş sayfa (önizleme için).
    final empty = paginateProductLabels(const []);
    expect(empty.length, 1);
    expect(empty[0].every((s) => s == null), isTrue);

    // Tam 72 → tek sayfa (taşma yok).
    final exact = paginateProductLabels(const [
      ProductLabelItem(
          barcode: '8690000000017', productName: 'X', quantity: 72),
    ]);
    expect(exact.length, 1);
    expect(exact[0].where((s) => s != null).length, 72);
  });
}
