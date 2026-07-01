import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../data/dashboard_repository.dart';

part 'dashboard_provider.g.dart';

/// Dashboard repository provider — her build'de aynı örnek kullanılır.
@riverpod
DashboardRepository dashboardRepository(DashboardRepositoryRef ref) =>
    DashboardRepository();

/// Bugünün satış adedi + tutarı.
@riverpod
Future<({int count, num revenue})> todaySummary(TodaySummaryRef ref) =>
    ref.watch(dashboardRepositoryProvider).fetchTodaySummary();

/// Dünün satış adedi + tutarı (yüzde değişim hesabı için).
@riverpod
Future<({int count, num revenue})> yesterdaySummary(
        YesterdaySummaryRef ref) =>
    ref.watch(dashboardRepositoryProvider).fetchYesterdaySummary();

/// Bu ayın satış adedi + tutarı.
@riverpod
Future<({int count, num revenue})> monthSummary(MonthSummaryRef ref) =>
    ref.watch(dashboardRepositoryProvider).fetchMonthSummary();

/// Geçen ayın toplam satış tutarı.
@riverpod
Future<num> lastMonthRevenue(LastMonthRevenueRef ref) =>
    ref.watch(dashboardRepositoryProvider).fetchLastMonthRevenue();

/// Son [days] günün günlük satış verileri.
@riverpod
Future<List<({DateTime date, num amount})>> dailySales(
        DailySalesRef ref, int days) =>
    ref.watch(dashboardRepositoryProvider).fetchDailySales(days);

/// Son [months] ayın aylık satış verileri.
@riverpod
Future<List<({DateTime date, num amount})>> monthlySales(
        MonthlySalesRef ref, int months) =>
    ref.watch(dashboardRepositoryProvider).fetchMonthlySales(months);

/// Yıllara göre aylık satış verileri (çok-yıl karşılaştırma grafiği).
/// Anahtar: yıl · değer: 12 elemanlı aylık toplam listesi (0=Ocak..11=Aralık).
@riverpod
Future<Map<int, List<num>>> yearlySales(YearlySalesRef ref) =>
    ref.watch(dashboardRepositoryProvider).fetchYearlyMonthlySales();
