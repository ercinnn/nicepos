import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nice_pos/features/sales/application/payment_input_notifier.dart';
import 'package:nice_pos/features/sales/data/models/sale.dart';
import 'package:nice_pos/features/sales/presentation/widgets/payment_panel.dart';

/// KARAR v2.3 / design-tokens §6.8(a) regresyonu:
/// **Ana aksiyon ("Satışı Tamamla") asla kaydırma alanında olmaz.**
/// Ölçülen hata: 1366×768'de "Parçalı" seçiliyken panel kendi içinde kayıyor ve
/// buton 145px aşağıda, görünmez kalıyordu. Bu tür render/görünürlük hataları
/// `flutter analyze`'da GÖRÜNMEZ — yalnız widget testi yakalar.
void main() {
  /// Panelin gerçek yerleşimdeki bağlamını kurar ve "Satışı Tamamla"nın
  /// panelin görünür sınırları içinde kaldığını doğrular.
  Future<void> anaAksiyonGorunurMu(WidgetTester tester) async {
    expect(tester.takeException(), isNull);

    final buton = find.text('Satışı Tamamla');
    expect(buton, findsOneWidget, reason: 'Ana aksiyon render edilmeli');

    final panelRect = tester.getRect(find.byType(PaymentPanel));
    final butonRect = tester.getRect(buton);

    // Görünürlük = butonun tamamı panelin kutusunun içinde. Panel kaydırılan
    // içeriğin dışında sabit bir alt bölgeye sahip olduğu için bu her
    // çözünürlükte sağlanmalıdır.
    expect(
      butonRect.bottom,
      lessThanOrEqualTo(panelRect.bottom + 0.5),
      reason: 'Ana aksiyon panelin alt kenarının altına taşmamalı',
    );
    expect(
      butonRect.top,
      greaterThanOrEqualTo(panelRect.top - 0.5),
      reason: 'Ana aksiyon panelin üstünden yukarı kaçmamalı',
    );
  }

  testWidgets(
      'Masaüstü (1366×768) sağ sütununda Parçalı seçiliyken Satışı Tamamla görünür',
      (tester) async {
    tester.view.physicalSize = const Size(1366, 768);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer();
    addTearDown(container.dispose);
    // Parçalı = en uzun içerik (2 input + özet + ana aksiyon) → en dar durum.
    container
        .read(paymentInputProvider.notifier)
        .selectType(PaymentType.parcali, 1250);

    // sales_screen.dart masaüstü sağ sütunu ile aynı bağlam: sabit genişlik +
    // ÜST SINIRLI (loose) yükseklik; panelin altında Hızlı Ürünler paneli.
    // Yükseklik kasten kısa tutuldu — panel kaydırmak ZORUNDA kalsın.
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 420,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 300),
                    child: const PaymentPanel(),
                  ),
                  const Expanded(child: SizedBox()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    // Testin anlamlı olması için panel GERÇEKTEN kaydırmak zorunda kalmalı;
    // aksi hâlde "buton görünür" bulgusu tesadüf olurdu.
    final ortaBolge = tester.state<ScrollableState>(
      find
          .descendant(
            of: find.byType(SingleChildScrollView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(
      ortaBolge.position.maxScrollExtent,
      greaterThan(0),
      reason: 'Orta bölge bu yükseklikte kaydırılabilir olmalı',
    );

    await anaAksiyonGorunurMu(tester);
  });

  testWidgets(
      'Masaüstünde içerik sığıyorsa panel üst sınırına kadar UZAMAZ (içeriği kadar yer kaplar)',
      (tester) async {
    tester.view.physicalSize = const Size(1366, 768);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 420,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 600),
                    child: const PaymentPanel(),
                  ),
                  const Expanded(child: SizedBox()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    // Üst sınır 600 ama içerik çok daha kısa → Hızlı Ürünler paneli alanını
    // kaptırmasın diye panel esneyip üst sınıra yapışmamalı (§6.7(f)).
    expect(tester.getSize(find.byType(PaymentPanel)).height, lessThan(600));
  });

  testWidgets(
      'Mobil ödeme sheet yüksekliğinde Parçalı seçiliyken Satışı Tamamla görünür',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer();
    addTearDown(container.dispose);
    container
        .read(paymentInputProvider.notifier)
        .selectType(PaymentType.parcali, 1250);

    final sheetController = ScrollController();
    addTearDown(sheetController.dispose);

    // Mobil sheet ile aynı bağlam: 0.6 × ekran yüksekliği, panel `Expanded`
    // (tight) alır ve sheet'in controller'ı orta bölgeye bağlanır — ekranda
    // TEK kaydırılabilir vardır (iç içe kaydırma yok).
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: SizedBox(
                height: 640 * 0.6,
                child: Column(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: PaymentPanel(scrollController: sheetController),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await anaAksiyonGorunurMu(tester);

    // İç içe kaydırma olmamalı: sheet artık kendi kaydırmasını açmaz, panelin
    // içinde de yalnız ORTA bölgenin tek kaydırılabilir alanı vardır.
    expect(
      find.byType(SingleChildScrollView),
      findsOneWidget,
      reason: 'Mobil sheet + panel toplamda tek kaydırılabilir alan içermeli',
    );
  });
}
