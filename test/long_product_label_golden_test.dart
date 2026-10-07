// Regresyon testi — Uzun Ürün Etiketi (A4 yatay, 2×12 = 24/sayfa): 148.5 ×
// 15.83mm hücrede (1.5mm iç pay → ~12.8mm iç yükseklik) yan yana düzen —
// solda 2 satıra taşan uzun ürün adı, sağda SABİT 8mm barkod + barkod no —
// crash/overflow vermeden render edilmeli. v1.20.1 dersi: barkod alanına
// sıfır/negatif yükseklik düşerse `barcode` paketinin `assert(height > 0)`
// kontrolü gerçek bir çökmeye yol açar; savunma eşiği korunur.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nice_pos/features/labels/data/label_pdf.dart';
import 'package:nice_pos/features/labels/data/models/product_label_item.dart';
import 'package:nice_pos/features/labels/presentation/screens/labels_screen.dart';

void main() {
  const longName =
      'Cok Uzun Bir Urun Adi Ornegi Iki Satira Tasan Metin Ekstra Kelimeler '
      'Daha Da Uzun Olsun Diye Eklenen Kelimeler AAA';

  List<ProductLabelItem?> buildPage() {
    final slots =
        List<ProductLabelItem?>.filled(kLongProductLabelPerPage, null);
    slots[0] = const ProductLabelItem(
      barcode: '8690000000017',
      productName: longName,
      quantity: 1,
    );
    slots[1] = const ProductLabelItem(
      barcode: '8690000000024',
      productName: 'Su 0.5L',
      quantity: 1,
    );
    slots[kLongProductLabelPerPage - 1] = const ProductLabelItem(
      barcode: 'C261002001',
      productName: 'Aycicek Yagi 5L Premium Kalite Bidon Ekonomik Paket',
      quantity: 1,
    );
    return slots;
  }

  Future<void> pumpPage(WidgetTester tester, {Key? boundaryKey}) async {
    await tester.binding.setSurfaceSize(const Size(1250, 900));
    final page = buildLongProductLabelPageForGolden(buildPage());
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Colors.white,
          body: Center(
            child: boundaryKey == null
                ? page
                : RepaintBoundary(key: boundaryKey, child: page),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('uzun ürün adıyla crash/overflow olmadan render edilir',
      (tester) async {
    await pumpPage(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('barkod bandı SABİT 8mm yükseklikte', (tester) async {
    await pumpPage(tester);
    const expected8mmPx = 8 * 3.7795;
    final areas = find.byKey(const Key('longProdBarcodeArea'));
    expect(areas, findsNWidgets(3));
    for (final el in areas.evaluate()) {
      final size = tester.getSize(find.byWidget(el.widget));
      expect(size.height, closeTo(expected8mmPx, 0.5));
    }
  });

  testWidgets(
      'yerleşim: 5 + 48 + 14 + 76.5 + 5 mm, barkod tüm etiketlerde aynı '
      'hizada başlar', (tester) async {
    await pumpPage(tester);
    const mm = 3.7795;
    // Kullanıcı ölçüsü: barkod 76.5mm (sabitlerden türetilen değerle aynı).
    expect(
      148.5 - 2 * kLongLabelSideMarginMm - kLongLabelNameWidthMm - kLongLabelGapMm,
      76.5,
    );
    const expectedBarcodeW = 76.5 * mm; // ≈289px
    final areas = find.byKey(const Key('longProdBarcodeArea'));
    final rects = [
      for (final el in areas.evaluate()) tester.getRect(find.byWidget(el.widget)),
    ];
    for (final r in rects) {
      // Kesim kılavuzu (0.5px kenarlık) payı için tolerans.
      expect(r.width, closeTo(expectedBarcodeW, 2));
    }
    // 3 dolu hücre: 0 (sol sütun, uzun ad), 1 ve 23 (sağ sütun, kısa ve
    // uzun ad). Ad uzunluğundan bağımsız → yalnız 2 farklı başlangıç x'i
    // (sütun başına bir) olmalı.
    final distinctLefts = rects.map((r) => r.left.roundToDouble()).toSet();
    expect(distinctLefts.length, 2);
  });

  testWidgets('Uzun Ürün Etiketi 2×12 önizleme golden PNG üretir',
      (tester) async {
    await pumpPage(tester, boundaryKey: const Key('golden'));
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

    File('long_product_label_golden.png').writeAsBytesSync(pngBytes);
    expect(pngBytes.lengthInBytes, greaterThan(0));
  });

  // PDF yolu önizlemeden AYRI kod yoludur (pw.* barkod `height > 0` assert'i
  // yalnız gerçek PDF üretiminde patlar) — 30 etiketlik (2 sayfa) gerçek PDF
  // üretimi istisnasız tamamlanmalı.
  test('buildLongProductLabelsPdf çok-sayfalı PDF üretir', () async {
    final bytes = await buildLongProductLabelsPdf(items: const [
      ProductLabelItem(
          barcode: '8690000000017', productName: longName, quantity: 29),
      ProductLabelItem(
          barcode: 'C261002001', productName: 'Konsept Set', quantity: 1),
    ]);
    expect(bytes.lengthInBytes, greaterThan(0));
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });

  test('wrapLongProductName: ≤20 karakter, kelime bölünmez', () {
    // 20 karaktere sığan kısım ilk satırda, sığmayan kelime alta geçer.
    expect(
      wrapLongProductName('Çelik Tencere Seti 24 cm 3 Parça'),
      ['ÇELIK TENCERE SETI', '24 CM 3 PARÇA'],
    );
    // Tam 20 karakter tek satırda kalır.
    expect(wrapLongProductName('aaaaaaaaa bbbbbbbbbb'), [
      'AAAAAAAAA BBBBBBBBBB',
    ]);
    // 21 karakter olacaksa kelime alta geçer (satır 20'den kısa kalsa da).
    expect(wrapLongProductName('aaaaaaaaaa bbbbbbbbbb'), [
      'AAAAAAAAAA',
      'BBBBBBBBBB',
    ]);
    // 20'den uzun tek kelime bölünmez, kendi satırında durur.
    expect(wrapLongProductName('Su Süperkalitelimükemmelürün 5L'), [
      'SU',
      'SÜPERKALITELIMÜKEMMELÜRÜN',
      '5L',
    ]);
    // Fazla boşluklar yok sayılır; her satır ≤20 (tek uzun kelime hariç).
    for (final line in wrapLongProductName('  Bir   iki  üç dört beş altı yedi sekiz dokuz on  ')) {
      expect(line.length, lessThanOrEqualTo(20));
      expect(line.trim(), line);
    }
  });

  test('paginateProductLabels(perPage: 24): 24 sınırında çok-sayfaya taşar',
      () {
    final pages = paginateProductLabels(
      const [
        ProductLabelItem(
            barcode: '8690000000017', productName: 'X', quantity: 30),
      ],
      perPage: kLongProductLabelPerPage,
    );
    expect(pages.length, 2);
    expect(pages[0].length, 24);
    expect(pages[0].where((s) => s != null).length, 24);
    expect(pages[1].where((s) => s != null).length, 6);

    final empty =
        paginateProductLabels(const [], perPage: kLongProductLabelPerPage);
    expect(empty.length, 1);
    expect(empty[0].length, 24);
    expect(empty[0].every((s) => s == null), isTrue);
  });
}
