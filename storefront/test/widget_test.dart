import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nicepos_storefront/main.dart';

void main() {
  testWidgets('Placeholder ekranı render olur', (WidgetTester tester) async {
    await tester.pumpWidget(const StorefrontApp());

    // Testte dart-define geçilmediğinden Supabase yapılandırılmamış sayılır;
    // yalnız ekranın hatasız render olduğunu doğrular.
    expect(find.byType(Scaffold), findsOneWidget);
  });
}
