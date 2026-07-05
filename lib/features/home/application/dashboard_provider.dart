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
/// keepAlive: oturum boyunca cache'lenir → dashboard'a her dönüşte yeniden
/// çekilmez. Tradeoff: yeni satış eklenince otomatik yenilenmez; gerekirse
/// ileride `ref.invalidate(dailySalesProvider)` ile elle tazelenebilir.
@Riverpod(keepAlive: true)
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
/// keepAlive: oturum boyunca cache'lenir → dashboard'a her dönüşte yeniden
/// çekilmez. Ayrıca geçmiş yıllar `DashboardRepository` içinde process-ömürlü
/// static cache'te tutulur; provider invalidate edilse bile geçmiş yıllar
/// yeniden çekilmez, yalnız cari yıl canlı gelir. Tradeoff: yeni satış eklenince
/// cari yıl otomatik yenilenmez; gerekirse `ref.invalidate(yearlySalesProvider)`.
@Riverpod(keepAlive: true)
Future<Map<int, List<num>>> yearlySales(YearlySalesRef ref) =>
    ref.watch(dashboardRepositoryProvider).fetchYearlyMonthlySales();
