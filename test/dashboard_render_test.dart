import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nice_pos/features/home/application/dashboard_provider.dart';
import 'package:nice_pos/features/home/presentation/widgets/dashboard_section.dart';

void main() {
  testWidgets('DashboardSection masaüstünde hatasız render olur', (tester) async {
    // Masaüstü genişliği (>650) → desktop dalı.
    tester.view.physicalSize = const Size(1280, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final sample = List.generate(
      30,
      (i) => (
        date: DateTime(2026, 6, 1).add(Duration(days: i)),
        amount: (i % 7) * 100.0 as num,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          todaySummaryProvider.overrideWith((ref) => (count: 3, revenue: 1500)),
          yesterdaySummaryProvider
              .overrideWith((ref) => (count: 2, revenue: 1000)),
          monthSummaryProvider.overrideWith((ref) => (count: 40, revenue: 50000)),
          lastMonthRevenueProvider.overrideWith((ref) => 42000),
          dailySalesProvider(30).overrideWith((ref) => sample),
          dailySalesProvider(8).overrideWith((ref) => sample.take(8).toList()),
          dailySalesProvider(15).overrideWith((ref) => sample.take(15).toList()),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: DashboardSection(),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    // Regresyon: dashboard masaüstünde "infinite height" vb. bir render hatası
    // atmamalı ve günlük satış grafiği görünür olmalı.
    expect(tester.takeException(), isNull);
    expect(find.textContaining('Günlük Satış Grafiği'), findsOneWidget);
  });
}
