import 'package:supabase_flutter/supabase_flutter.dart';

/// Anasayfa dashboard verisini Supabase'den çeken repository.
class DashboardRepository {
  final SupabaseClient _client = Supabase.instance.client;

  // ── Geçmiş yıl aylık toplam cache'i (process ömürlü) ──────────────────────
  // Cari yıldan ÖNCEKI yılların (y < DateTime.now().year) 12'lik aylık toplam
  // listeleri artık DEĞİŞMEZ → bir kez hesaplanınca burada saklanır ve tekrar
  // Supabase'den çekilmez. `dashboardRepositoryProvider` autoDispose olduğu için
  // her build'de yeni bir DashboardRepository örneği doğar; bu yüzden cache
  // `static` (örnek düzeyinde değil, sınıf/process düzeyinde) tutulur.
  // Anahtar: yıl · değer: 12 elemanlı aylık toplam listesi (0=Ocak..11=Aralık).
  //
  // İDEAL çözüm sunucu-taraf GROUP BY olurdu (ör. aşağıdaki gibi bir view/RPC),
  // ancak DDL anon key ile uygulanamaz (Supabase SQL Editor gerekir) → bu PR'da
  // tamamen Dart-taraf cache ile çözülür. İleride uygulanabilecek örnek:
  //   create view yearly_monthly_sales as
  //     select extract(year from sale_date)::int  as yil,
  //            extract(month from sale_date)::int as ay,
  //            sum(total_amount)                   as toplam
  //     from sales group by 1, 2;
  static final Map<int, List<num>> _pastYearsCache = {};

  // ── PostgREST 1000 satır limitini aşmak için sayfalı satır çekme ──────────
  // Verilen tarih aralığındaki tüm `sales` satırlarını sayfa sayfa toplar.
  Future<List<Map<String, dynamic>>> _fetchAllRows(
    String columns, {
    required DateTime start,
    DateTime? end,
  }) async {
    const pageSize = 1000;
    final all = <Map<String, dynamic>>[];
    var from = 0;
    while (true) {
      var filter = _client
          .from('sales')
          .select(columns)
          .gte('sale_date', start.toUtc().toIso8601String());
      if (end != null) {
        filter = filter.lt('sale_date', end.toUtc().toIso8601String());
      }
      final rows = await filter.order('sale_date').range(from, from + pageSize - 1);
      final list =
          (rows as List).map((r) => Map<String, dynamic>.from(r as Map)).toList();
      all.addAll(list);
      if (list.length < pageSize) break;
      from += pageSize;
    }
    return all;
  }

  // ── Bugünün satış adedi ve tutarını getir ────────────────────────────────
  Future<({int count, num revenue})> fetchTodaySummary() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    final rows = await _fetchAllRows(
      'total_amount, sale_items(quantity)',
      start: start,
      end: end,
    );
    num revenue = 0;
    int count = 0;
    for (final row in rows) {
      revenue += (row['total_amount'] as num? ?? 0);
      for (final item in (row['sale_items'] as List? ?? [])) {
        count += ((item['quantity'] as num?) ?? 0).round();
      }
    }
    return (count: count, revenue: revenue);
  }

  // ── Dünün satış adedi ve tutarını getir (değişim yüzdesi için) ───────────
  Future<({int count, num revenue})> fetchYesterdaySummary() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day)
        .subtract(const Duration(days: 1));
    final end = start.add(const Duration(days: 1));
    final rows = await _fetchAllRows(
      'total_amount, sale_items(quantity)',
      start: start,
      end: end,
    );
    num revenue = 0;
    int count = 0;
    for (final row in rows) {
      revenue += (row['total_amount'] as num? ?? 0);
      for (final item in (row['sale_items'] as List? ?? [])) {
        count += ((item['quantity'] as num?) ?? 0).round();
      }
    }
    return (count: count, revenue: revenue);
  }

  // ── Bu ayın satış adedi ve tutarını getir ────────────────────────────────
  Future<({int count, num revenue})> fetchMonthSummary() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 1);
    final rows = await _fetchAllRows(
      'total_amount, sale_items(quantity)',
      start: start,
      end: end,
    );
    num revenue = 0;
    int count = 0;
    for (final row in rows) {
      revenue += (row['total_amount'] as num? ?? 0);
      for (final item in (row['sale_items'] as List? ?? [])) {
        count += ((item['quantity'] as num?) ?? 0).round();
      }
    }
    return (count: count, revenue: revenue);
  }

  // ── Geçen ayın satış tutarını getir ─────────────────────────────────────
  Future<num> fetchLastMonthRevenue() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month - 1, 1);
    final end = DateTime(now.year, now.month, 1);
    final rows = await _fetchAllRows(
      'total_amount',
      start: start,
      end: end,
    );
    return rows.fold<num>(
      0,
      (sum, row) => sum + ((row['total_amount'] as num?) ?? 0),
    );
  }

  // ── Son N günün günlük satış tutarlarını getir ───────────────────────────
  Future<List<({DateTime date, num amount})>> fetchDailySales(int days) async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: days - 1));
    final rows = await _fetchAllRows(
      'sale_date, total_amount',
      start: start,
    );

    // Gün bazında grupla — tüm günleri sıfırla, sonra doldur
    final Map<String, num> grouped = {};
    for (var d = 0; d < days; d++) {
      final day = start.add(Duration(days: d));
      final key =
          '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      grouped[key] = 0;
    }
    for (final row in rows) {
      final dt = DateTime.parse(row['sale_date'] as String).toLocal();
      final key =
          '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
      if (grouped.containsKey(key)) {
        grouped[key] =
            (grouped[key]! + ((row['total_amount'] as num?) ?? 0));
      }
    }
    return grouped.entries
        .map((e) => (date: DateTime.parse(e.key), amount: e.value))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  // ── Cari yılın aylık satış tutarları (yalnız bu yıl) ──────────────────────
  // Yıllık karşılaştırma grafiğinin HIZLI ilk çizimi için: yalnız cari yıl
  // (`DateTime.now().year`) küçük aralık sorgusuyla çekilir. Cari yıl satış
  // eklendikçe değiştiği için CACHE'LENMEZ (geçmiş yıllardan farklı olarak).
  // Dönüş: `{currentYear: 12'lik aylık toplam listesi}` (0=Ocak..11=Aralık).
  Future<Map<int, List<num>>> fetchCurrentYearMonthly() async {
    final currentYear = DateTime.now().year;
    final rows = await _fetchAllRows(
      'sale_date, total_amount',
      start: DateTime(currentYear, 1, 1),
      end: DateTime(currentYear + 1, 1, 1),
    );
    final list = List<num>.filled(12, 0, growable: false);
    for (final row in rows) {
      final dt = DateTime.parse(row['sale_date'] as String).toLocal();
      if (dt.year != currentYear) continue; // aralık dışı (güvenlik)
      list[dt.month - 1] += ((row['total_amount'] as num?) ?? 0);
    }
    return {currentYear: list};
  }

  // ── Geçmiş yılların aylık satış tutarları (yalnız y < currentYear) ────────
  // startYear..(currentYear-1) arası her yıl için 12 elemanlı aylık toplam
  // listesi döner (index 0=Ocak..11=Aralık). Geçmiş yıllar DEĞİŞMEZ → static
  // `_pastYearsCache` ile oturum ömrü boyunca en fazla bir kez çekilir: cache'te
  // olanlar doğrudan alınır, eksikler tek toplu sorguyla çekilip cache'lenir.
  // Cari yıl bilinçli olarak DIŞARIDA bırakılır (bkz. fetchCurrentYearMonthly).
  Future<Map<int, List<num>>> fetchHistoricalYearlyMonthly({
    int startYear = 2021,
  }) async {
    final currentYear = DateTime.now().year;
    final Map<int, List<num>> grouped = {};

    final missingPast = <int>[]; // artan sırada dolar
    for (var y = startYear; y < currentYear; y++) {
      final cached = _pastYearsCache[y];
      if (cached != null) {
        grouped[y] = cached;
      } else {
        missingPast.add(y);
      }
    }

    if (missingPast.isNotEmpty) {
      // Eksik geçmiş yılların tam aralığı (ilk..son) tek sorguda çekilir;
      // yalnız gerçekten eksik olan yıllar hesaplanıp cache'lenir.
      final firstMissing = missingPast.first;
      final lastMissing = missingPast.last;
      final rows = await _fetchAllRows(
        'sale_date, total_amount',
        start: DateTime(firstMissing, 1, 1),
        end: DateTime(lastMissing + 1, 1, 1),
      );
      final Map<int, List<num>> fetched = {
        for (final y in missingPast)
          y: List<num>.filled(12, 0, growable: false),
      };
      for (final row in rows) {
        final dt = DateTime.parse(row['sale_date'] as String).toLocal();
        final list = fetched[dt.year];
        if (list == null) continue; // aralıktaki ama eksik-olmayan yıl (güvenlik)
        list[dt.month - 1] += ((row['total_amount'] as num?) ?? 0);
      }
      for (final y in missingPast) {
        _pastYearsCache[y] = fetched[y]!;
        grouped[y] = fetched[y]!;
      }
    }

    return grouped;
  }

  // ── Son N ayın aylık satış tutarlarını getir ─────────────────────────────
  Future<List<({DateTime date, num amount})>> fetchMonthlySales(
      int months) async {
    final now = DateTime.now();
    final results = <({DateTime date, num amount})>[];
    for (var i = months - 1; i >= 0; i--) {
      final monthDate = DateTime(now.year, now.month - i, 1);
      final nextMonth = DateTime(monthDate.year, monthDate.month + 1, 1);
      final rows = await _fetchAllRows(
        'total_amount',
        start: monthDate,
        end: nextMonth,
      );
      final total = rows.fold<num>(
        0,
        (sum, row) => sum + ((row['total_amount'] as num?) ?? 0),
      );
      results.add((date: monthDate, amount: total));
    }
    return results;
  }
}
