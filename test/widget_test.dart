import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nice_pos/main.dart';

void main() {
  testWidgets('Supabase yapılandırması eksikse uyarı ekranı gösterilir', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: NicePosApp()));
    await tester.pumpAndSettle();

    expect(find.text('Supabase yapılandırması eksik'), findsOneWidget);
  });
}
