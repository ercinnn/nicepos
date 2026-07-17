// Geçici golden — Geniş Logo (KARAR v1.14.2) etiket-içi hizasını gözle doğrulamak
// için 2×5 A4 önizlemesini 3-4 örnek etiketle render edip worktree köküne
// `wide_label_golden.png` olarak yazar. Tasarım-lideri bu PNG'yi inceleyip hizayı
// onaylayacak; kalıcı bir doğrulama testi değildir.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nice_pos/features/labels/data/models/label_slot.dart';
import 'package:nice_pos/features/labels/presentation/screens/labels_screen.dart';

void main() {
  testWidgets('Geniş Logo 2x5 önizleme golden PNG üretir', (tester) async {
    final now = DateTime(2026, 7, 16);
    final slots = List<LabelSlot?>.filled(10, null);
    slots[0] = LabelSlot(
      barcode: '8690000000017',
      productName: 'Çikolatalı Gofret 40g',
      price: 105,
      createdAt: now,
    );
    slots[1] = LabelSlot(
      barcode: '8690000000024',
      productName: 'Ayçiçek Yağı 5L Premium Kalite Bidon',
      price: 1100,
      createdAt: now,
    );
    slots[2] = LabelSlot(
      barcode: '8690000000031',
      productName: 'Su 0.5L',
      price: 15,
      createdAt: now,
    );
    slots[5] = LabelSlot(
      barcode: '8690000000048',
      productName: 'Toz Deterjan Beyazlar İçin 6kg',
      price: 249.9,
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
              child: buildWideCanvasForGolden(slots),
            ),
          ),
        ),
      ),
    );

    // Gerçek asset görselini decode et (Image.asset async yüklenir).
    final ctx = tester.element(find.byKey(const Key('golden')));
    await tester.runAsync(() async {
      await precacheImage(const AssetImage('genis_logo_figur.png'), ctx);
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const Key('golden')),
    );
    late Uint8List pngBytes;
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2.0);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      pngBytes = data!.buffer.asUint8List();
    });

    File('wide_label_golden.png').writeAsBytesSync(pngBytes);
    expect(pngBytes.lengthInBytes, greaterThan(0));
  });
}
