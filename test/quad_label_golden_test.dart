// Regresyon testi — Büyük Etiket (2×2 A5, KARAR v1.20/v1.20.1): üst bant
// (kırmızı) artık SABİT yükseklikte olmalı (ürün adı 1 satır da olsa 2 satır da
// olsa bant TOPLAM yüksekliği ASLA değişmez) ve uzun (2 satıra taşan) bir ürün
// adıyla hücre crash/overflow vermeden render edilmelidir. v1.20'nin özgün
// hâlinde bant "içerik kadar esniyordu"; bu + fiyat kutusunun sabit yükseklik
// bütçesi birleşince barkod `Expanded` alanı sıfır/negatif yüksekliğe düşüp
// `barcode` paketinin `assert(height > 0)` kontrolüyle GERÇEK bir Flutter
// çökmesine yol açıyordu (bkz. design/design-tokens.md KARAR v1.20.1). Bu test
// o regresyonu bir daha yakalamak için eklendi — v1.20 turunda böyle bir test
// bulunmadığı için otomatik yakalanamamıştı.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:nice_pos/features/labels/data/models/label_slot.dart';
import 'package:nice_pos/features/labels/presentation/screens/labels_screen.dart';

Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('tr_TR');

  const shortName = 'Su 0.5L';
  // 2 satıra taşan (uzun) ürün adı — QA #7 repro senaryosu ile aynı desen.
  const longName =
      'Cok Uzun Bir Urun Adi Ornegi Iki Satira Tasan Metin AAA';

  Future<Size> pumpAndMeasureTopBand(
    WidgetTester tester,
    String productName,
  ) async {
    final now = DateTime(2026, 7, 22);
    final slots = List<LabelSlot?>.filled(4, null);
    slots[0] = LabelSlot(
      barcode: '8690000000017',
      productName: productName,
      price: 1234.5,
      createdAt: now,
    );
    slots[1] = LabelSlot(
      barcode: '8690000000024',
      productName: 'Ayçiçek Yağı 5L Premium Kalite Bidon Ekonomik Paket',
      price: 1100,
      createdAt: now,
    );

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Colors.white,
          body: Center(child: buildQuadCanvasForGolden(slots)),
        ),
      ),
    );
    await tester.pump();

    return tester.getSize(find.byKey(const Key('quadTopBand')).first);
  }

  testWidgets(
    'uzun (2 satırlık) ürün adıyla crash/overflow olmadan render edilir',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(900, 1250));

      final shortBandSize = await pumpAndMeasureTopBand(tester, shortName);
      expect(tester.takeException(), isNull,
          reason: 'Kısa ürün adıyla hiçbir istisna fırlatılmamalı');

      final longBandSize = await pumpAndMeasureTopBand(tester, longName);
      expect(tester.takeException(), isNull,
          reason:
              '2 satırlık uzun ürün adıyla `barcode` paketinin assert çökmesi '
              'ASLA tetiklenmemeli (KARAR v1.20.1 madde 1+3)');

      // KARAR v1.20.1 madde 1: üst bant SABİT yükseklikte — 1 satırlık ve
      // 2 satırlık ürün adları arasında bandın TOPLAM yüksekliği değişmemeli.
      expect(
        longBandSize.height,
        closeTo(shortBandSize.height, 0.5),
        reason:
            'Üst bant yüksekliği ürün adı uzunluğuna göre değişmemeli (sabit '
            'yükseklik bütçesi)',
      );

      // Barkod alanı normal koşulda sağlıklı (pozitif, savunma eşiğinin çok
      // üstünde) bir yükseklik almalı — madde 1 sayesinde savunma dalına
      // (madde 3) hiç girilmemesi beklenir.
      final barcodeAreaSize =
          tester.getSize(find.byKey(const Key('quadBarcodeArea')).first);
      expect(barcodeAreaSize.height, greaterThan(50));
    },
  );

  testWidgets('Büyük Etiket 2x2 önizleme golden PNG üretir (uzun ad dahil)',
      (tester) async {
    final now = DateTime(2026, 7, 22);
    final slots = List<LabelSlot?>.filled(4, null);
    slots[0] = LabelSlot(
      barcode: '8690000000017',
      productName: longName,
      price: 1234.5,
      createdAt: now,
    );
    slots[1] = LabelSlot(
      barcode: '8690000000024',
      productName: shortName,
      price: 15,
      createdAt: now,
    );

    await tester.binding.setSurfaceSize(const Size(900, 1250));

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Colors.white,
          body: Center(
            child: RepaintBoundary(
              key: const Key('golden'),
              child: buildQuadCanvasForGolden(slots),
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

    File('quad_label_golden.png').writeAsBytesSync(pngBytes);
    expect(pngBytes.lengthInBytes, greaterThan(0));
  });
}
