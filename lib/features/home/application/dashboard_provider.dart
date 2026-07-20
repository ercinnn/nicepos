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

/// Yıl başından bugüne (YTD) toplam ciro — cari yılın 01 Ocak'ından bugüne.
@riverpod
Future<num> yearToDateRevenue(YearToDateRevenueRef ref) =>
    ref.watch(dashboardRepositoryProvider).fetchYearToDateRevenue();

/// Son 365 günlük toplam ciro (bugün dahil son 365 takvim günü).
@riverpod
Future<num> last365DaysRevenue(Last365DaysRevenueRef ref) =>
    ref.watch(dashboardRepositoryProvider).fetchLast365DaysRevenue();

/// Son [days] günün günlük satış verileri.
/// autoDispose (ÖNCEDEN keepAlive'dı — bkz. aşağıdaki not): dashboard'a her
/// dönüşte yeniden çekilir.
///
/// NOT (mobil bug düzeltmesi): bu provider + `currentYearMonthly` +
/// `historicalYearly` üçü ÖNCEDEN `keepAlive: true` idi — diğer tüm dashboard
/// provider'ları (stat kartları) autoDispose. Android'de uygulama soğuk
/// açılışında (Supabase oturumu/token henüz tam oturmamışken) bu üçünün İLK
/// sorgusu boş/sıfır sonuç dönerse, keepAlive bu kötü sonucu SÜREÇ ÖMRÜ
/// BOYUNCA kalıcı olarak dondurur — kullanıcı anasayfayı tekrar ziyaret etse
/// bile tazelenmez (autoDispose stat kartları ise her ziyarette kendiliğinden
/// düzelir). Web'de bu sorun gözlenmemesi muhtemelen daha hızlı/istikrarlı
/// bağlantı + daha sık sayfa yenilemesiyle örtüşüyor olmasından kaynaklanıyor.
/// Düzeltme: bu üçü de autoDispose'a çevrildi — küçük bir performans
/// maliyetiyle (her ziyarette yeniden sorgu) kalıcı-yanlış-veri riski ortadan
/// kaldırıldı. Finansal rakamlar gösteren bir ekranda doğruluk önceliklidir.
@riverpod
Future<List<({DateTime date, num amount})>> dailySales(
        DailySalesRef ref, int days) =>
    ref.watch(dashboardRepositoryProvider).fetchDailySales(days);

/// Son [days] günün günlük satış ADEDİ verileri (stat kartı sparkline'ı için).
@riverpod
Future<List<({DateTime date, int count})>> dailySalesCount(
        DailySalesCountRef ref, int days) =>
    ref.watch(dashboardRepositoryProvider).fetchDailySalesCount(days);

/// Son [months] ayın aylık satış verileri.
@riverpod
Future<List<({DateTime date, num amount})>> monthlySales(
        MonthlySalesRef ref, int months) =>
    ref.watch(dashboardRepositoryProvider).fetchMonthlySales(months);

/// Cari yılın aylık satış verileri (çok-yıl karşılaştırma grafiğinin HIZLI ilk
/// çizimi için). Anahtar: yıl · değer: 12 elemanlı aylık toplam listesi.
/// Küçük aralık sorgusu → grafik cari yıl çizgisini hemen gösterebilsin diye
/// geçmiş yıllardan ayrıldı.
/// autoDispose (ÖNCEDEN keepAlive'dı) — bkz. `dailySales` üzerindeki not:
/// mobilde soğuk açılışta oluşabilecek geçici bir boş/sıfır sonucun kalıcı
/// cache'lenmesini önlemek için dashboard'a her dönüşte yeniden çekilir.
@riverpod
Future<Map<int, List<num>>> currentYearMonthly(CurrentYearMonthlyRef ref) =>
    ref.watch(dashboardRepositoryProvider).fetchCurrentYearMonthly();

/// Geçmiş yılların (y < cari yıl) aylık satış verileri — grafiğe ARKADAN dolar.
/// Anahtar: yıl · değer: 12 elemanlı aylık toplam listesi (0=Ocak..11=Aralık).
/// autoDispose (ÖNCEDEN keepAlive'dı) — bkz. `dailySales` üzerindeki not.
/// `DashboardRepository._pastYearsCache` de artık STATIC değil, instance
/// alanı (bkz. repository) — provider yeniden oluştuğunda cache de sıfırdan
/// başlar, böylece kötü/boş bir ilk sonuç geçmiş yılları kalıcı olarak
/// "sıfır" diye dondurmaz. Geçmiş yıllar gerçekten değişmez, ama küçük bir
/// tekrar-sorgu maliyeti kalıcı-yanlış-veri riskinden daha ucuzdur.
@riverpod
Future<Map<int, List<num>>> historicalYearly(HistoricalYearlyRef ref) =>
    ref.watch(dashboardRepositoryProvider).fetchHistoricalYearlyMonthly();
