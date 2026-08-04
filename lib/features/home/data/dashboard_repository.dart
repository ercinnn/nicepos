// `(f1, f2).wait` record-paralel bekleme genişletmesi için (bkz. dashboard
// sorgularının paralelleştirilmesi).
import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Anasayfa dashboard verisini Supabase'den çeken repository.
class DashboardRepository {
  final SupabaseClient _client = Supabase.instance.client;

  // ── Geçmiş yıl aylık toplam cache'i (instance ömürlü) ──────────────────────
  // Cari yıldan ÖNCEKI yılların (y < DateTime.now().year) 12'lik aylık toplam
  // listeleri artık DEĞİŞMEZ → bir kez hesaplanınca bu ÖRNEK içinde saklanır.
  // Anahtar: yıl · değer: 12 elemanlı aylık toplam listesi (0=Ocak..11=Aralık).
  //
  // NOT: Aylık toplama artık sunucuda `sales_monthly_totals` görünümünde yapılır
  // (bkz. supabase/migrations/0010_sales_monthly_totals.sql). İstemci yıl×ay
  // başına tek satır çeker; binlerce `sales` satırını taşımaz.
  //
  // ⚠️ ÖNCEDEN `static` idi (process ömrü boyunca, tüm DashboardRepository
  // örnekleri arasında paylaşılan tek bir cache). Bu, mobilde soğuk açılışta
  // (Supabase oturumu tam oturmadan) İLK sorgu boş/sıfır dönerse, o boş sonucun
  // UYGULAMA KAPATILANA KADAR kalıcı olarak "geçmiş yıl = sıfır" diye
  // dondurulmasına yol açıyordu (`historicalYearlyProvider` autoDispose'a
  // çevrilse bile static cache bu hatayı hayatta tutardı). Artık instance
  // alanı: `historicalYearlyProvider` her yeniden oluştuğunda (dashboard'a her
  // dönüşte) taze bir `DashboardRepository` + boş cache ile başlar — küçük bir
  // tekrar-sorgu maliyeti karşılığında kalıcı-yanlış-veri riski ortadan kalkar.
  final Map<int, List<num>> _pastYearsCache = {};

  // PostgREST numeric alanları (ör. görünümdeki sum) num veya String olarak
  // gelebilir; ikisini de güvenle sayıya çevirir.
  num _asNum(Object? v) {
    if (v is num) return v;
    if (v is String) return num.tryParse(v) ?? 0;
    return 0;
  }

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

  // ── O gün FİİLEN tahsil edilen borç ödemeleri (nakit-esaslı ciro için) ─────
  // Nakit-esaslı günlük ciro tanımı: "o gün kasaya giren para". Bunun iki
  // bileşeni var: (1) o gün yapılan satışların `paid_amount` (peşin) toplamı,
  // (2) o gün gelen borç TAHSİLATLARI. Bu metot 2. bileşeni verir.
  //
  // ⚠️ KRİTİK: `customer_payments` tablosu HEM açık-hesap satışında
  // `completeSale`/`updateSale`'in otomatik eklediği `type='borc'` hareketlerini
  // (borcun kendisi — satış anında ciroya GİRMEYEN kısım), HEM de gerçek
  // tahsilatları (`type='odeme'`) içerir. Nakit-esaslı ciroya YALNIZ gerçek
  // tahsilatlar (`type='odeme'`) girer. `'borc'` hareketleri de POZİTİF `amount`
  // ile saklandığından (bkz. sales_repository.completeSale), sayılırlarsa açık
  // hesabı çifte-pozitif yazıp ciroyu şişirirdi — bu yüzden `.eq('type','odeme')`
  // ile SADECE tahsilatlar toplanır. `'odeme'` tahsilatı hem nakit hem POS
  // kanalını kapsar (ikisi de kasaya giren paradır) → channel filtresi YOK.
  Future<List<Map<String, dynamic>>> _fetchOdemeRows({
    required DateTime start,
    DateTime? end,
  }) async {
    const pageSize = 1000;
    final all = <Map<String, dynamic>>[];
    var from = 0;
    while (true) {
      var filter = _client
          .from('customer_payments')
          .select('amount, payment_date')
          .eq('type', 'odeme')
          .gte('payment_date', start.toUtc().toIso8601String());
      if (end != null) {
        filter = filter.lt('payment_date', end.toUtc().toIso8601String());
      }
      final rows =
          await filter.order('payment_date').range(from, from + pageSize - 1);
      final list =
          (rows as List).map((r) => Map<String, dynamic>.from(r as Map)).toList();
      all.addAll(list);
      if (list.length < pageSize) break;
      from += pageSize;
    }
    return all;
  }

  // [start, end) aralığındaki gerçek borç tahsilatlarının (type='odeme') toplamı.
  Future<num> _sumDebtCollections(DateTime start, DateTime end) async {
    final rows = await _fetchOdemeRows(start: start, end: end);
    num total = 0;
    for (final row in rows) {
      total += _asNum(row['amount']);
    }
    return total;
  }

  // ── Bir [start, end) aralığının satış adedi + NAKİT-ESASLI cirosu ────────
  // `fetchTodaySummary`/`fetchYesterdaySummary`/`fetchMonthSummary` üçü de
  // BİREBİR aynı işi farklı aralıkla yapıyordu — ortak gövde buraya alındı.
  //
  // ⚠️ PERFORMANS: iki bağımsız sorgu (satış satırları + borç tahsilatları)
  // artık PARALEL çalışır (`Future.wait`), sıralı DEĞİL. Önceden tahsilat
  // sorgusu satış sorgusu bitmeden başlamıyordu; bu üç provider anasayfada
  // birlikte çalıştığı için gereksiz yere 3 round-trip'lik gecikme ekleniyordu.
  // İkisi arasında veri bağımlılığı yok → paralelleştirme davranışı değiştirmez.
  Future<({int count, num revenue})> _fetchRangeSummary(
    DateTime start,
    DateTime end,
  ) async {
    final (rows, collections) = await (
      _fetchAllRows(
        'paid_amount, sale_items(quantity)',
        start: start,
        end: end,
      ),
      _sumDebtCollections(start, end),
    ).wait;
    num paidFromSales = 0;
    int count = 0;
    for (final row in rows) {
      paidFromSales += (row['paid_amount'] as num? ?? 0);
      for (final item in (row['sale_items'] as List? ?? [])) {
        count += ((item['quantity'] as num?) ?? 0).round();
      }
    }
    return (count: count, revenue: paidFromSales + collections);
  }

  // ── Bugünün satış adedi ve NAKİT-ESASLI cirosu ───────────────────────────
  // Ciro = o gün fiilen tahsil edilen para:
  //   (1) bugün yapılan satışların `paid_amount` toplamı (peşin kısım; açık
  //       hesabın ödenmemiş kısmı `remaining_debt`'te kalır, otomatik dışlanır),
  // + (2) bugün gelen borç tahsilatları (`customer_payments` type='odeme').
  // Satış ADEDİ tanımı DEĞİŞMEDİ — bugün yapılan satış kalemlerinin miktar toplamı.
  Future<({int count, num revenue})> fetchTodaySummary() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    return _fetchRangeSummary(start, start.add(const Duration(days: 1)));
  }

  // ── Dünün satış adedi ve NAKİT-ESASLI cirosu (hero değişim yüzdesi için) ──
  // Hero'nun "düne göre değişim" göstergesi bugünle AYNI tabana (nakit-esaslı)
  // dayanmalı ki karşılaştırma anlamlı olsun; bu yüzden dün de aynı tanımla
  // hesaplanır (peşin `paid_amount` + o gün gelen borç tahsilatları).
  Future<({int count, num revenue})> fetchYesterdaySummary() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day)
        .subtract(const Duration(days: 1));
    return _fetchRangeSummary(start, start.add(const Duration(days: 1)));
  }

  // ── Bu ayın satış adedi ve NAKİT-ESASLI cirosu ───────────────────────────
  // Ciro = bu ay fiilen kasaya giren para (hero/günlük grafik ile aynı tanım):
  //   (1) bu ay yapılan satışların `paid_amount` toplamı (peşin kısım),
  // + (2) bu ay gelen borç tahsilatları (`customer_payments` type='odeme').
  // Satış ADEDİ tanımı DEĞİŞMEDİ — bu ay yapılan satış kalemlerinin miktar toplamı.
  Future<({int count, num revenue})> fetchMonthSummary() {
    final now = DateTime.now();
    return _fetchRangeSummary(
      DateTime(now.year, now.month, 1),
      DateTime(now.year, now.month + 1, 1),
    );
  }

  // ── Sunucu tarafında NAKİT-ESASLI ciro toplamı — geniş tarih aralıkları ───
  // `sales_revenue_between` RPC'si toplamayı Postgres'te tek sorguda yapar
  // (istemci binlerce satır çekmez). RPC nakit-esaslıdır (bkz.
  // 0025_sales_revenue_cash_basis.sql): aralıktaki satışların `paid_amount`
  // toplamı + aralıkta gelen borç tahsilatları (`customer_payments` type='odeme');
  // `type='borc'` hariç. Hero/günlük grafik/aylık kart ile AYNI tanım → aynı
  // aralık için "günlük toplamı = aylık = yıllık" tutarlılığı korunur.
  Future<num> _fetchRevenueBetween(DateTime start, DateTime end) async {
    final result = await _client.rpc('sales_revenue_between', params: {
      'start_ts': start.toUtc().toIso8601String(),
      'end_ts': end.toUtc().toIso8601String(),
    });
    return _asNum(result);
  }

  // ── Geçen ayın satış tutarını getir ─────────────────────────────────────
  Future<num> fetchLastMonthRevenue() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month - 1, 1);
    final end = DateTime(now.year, now.month, 1);
    return _fetchRevenueBetween(start, end);
  }

  // ── Yıl başından bugüne (YTD) toplam ciro ────────────────────────────────
  // Cari yılın 01 Ocak gününden bugünün sonuna kadar (bugün dahil) toplam ciro.
  // Örn. 17.07.2026 için 01.01.2026 00:00 – 18.07.2026 00:00 aralığı.
  Future<num> fetchYearToDateRevenue() async {
    final now = DateTime.now();
    final start = DateTime(now.year, 1, 1);
    final end = DateTime(now.year, now.month, now.day)
        .add(const Duration(days: 1));
    return _fetchRevenueBetween(start, end);
  }

  // ── Son 365 günlük toplam ciro ───────────────────────────────────────────
  // Bugün dahil son 365 takvim günü: bugünden 364 gün önceki günün başından
  // bugünün sonuna kadar. Örn. 17.07.2026 için 19.07.2025 00:00 – 18.07.2026
  // 00:00 aralığı (365 gün).
  Future<num> fetchLast365DaysRevenue() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = today.subtract(const Duration(days: 364));
    final end = today.add(const Duration(days: 1));
    return _fetchRevenueBetween(start, end);
  }

  // ── Son N günün günlük NAKİT-ESASLI ciro serisini getir ──────────────────
  // Hero "Bugünkü Ciro" ile TUTARLI olması için günlük grafik de nakit-esaslı
  // tanımı kullanır: her gün için (1) o gün yapılan satışların `paid_amount`
  // toplamı + (2) o gün gelen borç tahsilatları (`customer_payments`
  // type='odeme'). Böylece grafikteki bugünkü çubuk hero ile birebir eşleşir.
  Future<List<({DateTime date, num amount})>> fetchDailySales(int days) async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: days - 1));
    // ⚠️ PERFORMANS: iki bağımsız sorgu paralel (bkz. `_fetchRangeSummary`).
    final (saleRows, odemeRows) = await (
      _fetchAllRows('sale_date, paid_amount', start: start),
      _fetchOdemeRows(start: start),
    ).wait;

    // Gün bazında grupla — tüm günleri sıfırla, sonra iki bileşeni de doldur
    final Map<String, num> grouped = {};
    for (var d = 0; d < days; d++) {
      final day = start.add(Duration(days: d));
      final key =
          '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      grouped[key] = 0;
    }
    // (1) satışların peşin (paid_amount) kısmı
    for (final row in saleRows) {
      final dt = DateTime.parse(row['sale_date'] as String).toLocal();
      final key =
          '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
      if (grouped.containsKey(key)) {
        grouped[key] =
            (grouped[key]! + ((row['paid_amount'] as num?) ?? 0));
      }
    }
    // (2) o gün gelen borç tahsilatları (yalnız type='odeme')
    for (final row in odemeRows) {
      final dt = DateTime.parse(row['payment_date'] as String).toLocal();
      final key =
          '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
      if (grouped.containsKey(key)) {
        grouped[key] = (grouped[key]! + _asNum(row['amount']));
      }
    }
    return grouped.entries
        .map((e) => (date: DateTime.parse(e.key), amount: e.value))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  // ── Son N günün günlük satış ADEDİNİ getir (stat kartı sparkline'ı için) ──
  Future<List<({DateTime date, int count})>> fetchDailySalesCount(
      int days) async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: days - 1));
    final rows = await _fetchAllRows('sale_date', start: start);

    final Map<String, int> grouped = {};
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
        grouped[key] = grouped[key]! + 1;
      }
    }
    return grouped.entries
        .map((e) => (date: DateTime.parse(e.key), count: e.value))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  // ── Cari yılın aylık NAKİT-ESASLI ciro tutarları (yalnız bu yıl) ──────────
  // Yıllık karşılaştırma grafiğinin HIZLI ilk çizimi için: yalnız cari yıl
  // (`DateTime.now().year`) `sales_monthly_totals` görünümünden çekilir (yıl
  // başına en fazla 12 satır). Görünüm artık nakit-esaslıdır (peşin paid_amount
  // + o ay gelen type='odeme' tahsilatları; bkz. 0026_sales_monthly_cash_basis.sql)
  // → hero/günlük/aylık kartla aynı taban. Cari yıl değiştikçe CACHE'LENMEZ.
  // Dönüş: `{currentYear: 12'lik aylık toplam listesi}` (0=Ocak..11=Aralık).
  Future<Map<int, List<num>>> fetchCurrentYearMonthly() async {
    final currentYear = DateTime.now().year;
    final rows = await _client
        .from('sales_monthly_totals')
        .select('year, month, total')
        .eq('year', currentYear);
    final list = List<num>.filled(12, 0, growable: false);
    for (final row in (rows as List)) {
      final map = Map<String, dynamic>.from(row as Map);
      final month = _asNum(map['month']).toInt();
      if (month < 1 || month > 12) continue; // güvenlik
      list[month - 1] = _asNum(map['total']);
    }
    return {currentYear: list};
  }

  // ── Geçmiş yılların aylık NAKİT-ESASLI ciro tutarları (y < currentYear) ───
  // startYear..(currentYear-1) arası her yıl için 12 elemanlı aylık toplam
  // listesi döner (index 0=Ocak..11=Aralık). Kaynak: nakit-esaslı
  // `sales_monthly_totals` görünümü (bkz. 0026). Geçmiş yıllar DEĞİŞMEZ → static
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
      // Eksik geçmiş yılların tam aralığı (ilk..son) `sales_monthly_totals`
      // görünümünden tek sorguda çekilir; yalnız gerçekten eksik olan yıllar
      // hesaplanıp cache'lenir.
      final firstMissing = missingPast.first;
      final lastMissing = missingPast.last;
      final rows = await _client
          .from('sales_monthly_totals')
          .select('year, month, total')
          .gte('year', firstMissing)
          .lte('year', lastMissing);
      final Map<int, List<num>> fetched = {
        for (final y in missingPast)
          y: List<num>.filled(12, 0, growable: false),
      };
      for (final row in (rows as List)) {
        final map = Map<String, dynamic>.from(row as Map);
        final y = _asNum(map['year']).toInt();
        final month = _asNum(map['month']).toInt();
        final list = fetched[y];
        if (list == null) continue; // aralıktaki ama eksik-olmayan yıl (güvenlik)
        if (month < 1 || month > 12) continue; // güvenlik
        list[month - 1] = _asNum(map['total']);
      }
      for (final y in missingPast) {
        _pastYearsCache[y] = fetched[y]!;
        grouped[y] = fetched[y]!;
      }
    }

    return grouped;
  }

  // ── Son N ayın aylık NAKİT-ESASLI ciro tutarlarını getir ─────────────────
  // Her ay için nakit-esaslı ciro (peşin `paid_amount` + o ay gelen borç
  // tahsilatları). Kaynak: `sales_monthly_totals` görünümü — `currentYearMonthly`
  // / `historicalYearly` ile AYNI kaynak, dolayısıyla aynı nakit-esaslı tanım.
  //
  // ⚠️ PERFORMANS — TEK sorgu (ölçümle gerekçelendirildi):
  // Bu metot iki kez elden geçti.
  //   1) Başlangıçta `for` döngüsü içinde `await` ile ay başına bir
  //      `sales_revenue_between` RPC'si vardı → 12 round-trip UÇ UCA.
  //   2) Sonra `Future.wait` ile paralelleştirildi → 12 round-trip eşzamanlı.
  //   3) Şimdi tek görünüm sorgusu → 12 round-trip yerine 1.
  // Ölçüm (2026-08-04): Supabase round-trip'i ısınmış hâlde ~550 ms, buna karşılık
  // görünümün SQL maliyeti ~50 ms (ve `sales_revenue_between` ~10 ms). Yani
  // maliyet sorguda değil, İSTEK SAYISINDA. Paralelleştirme duvar saatini
  // düzeltmişti ama 12 isteğin sunucu yükü ve eşzamanlılık baskısı duruyordu;
  // zayıf mobil bağlantıda (dükkân içi sinyal boşlukları) RTT birkaç saniyeye
  // çıktığında bu fark belirginleşir.
  //
  // Görünüm ay bazında YEREL (Europe/Istanbul) yıl/ay ile grupladığı için,
  // RPC'nin yerel ay sınırı aralığıyla birebir aynı sonucu verir (bkz.
  // 0026_sales_monthly_cash_basis.sql) → rakamlar değişmez. Kaydı olmayan aylar
  // görünümde satır olarak GELMEZ; bu aylar 0 ile doldurulur.
  Future<List<({DateTime date, num amount})>> fetchMonthlySales(
      int months) async {
    final now = DateTime.now();
    final monthStarts = <DateTime>[
      for (var i = months - 1; i >= 0; i--) DateTime(now.year, now.month - i, 1),
    ];
    if (monthStarts.isEmpty) return const [];

    // İstenen aralık en fazla iki takvim yılına yayılır (12 ay için); yine de
    // genel olsun diye ilk/son aydan yıl sınırları türetilir.
    final firstYear = monthStarts.first.year;
    final lastYear = monthStarts.last.year;
    final rows = await _client
        .from('sales_monthly_totals')
        .select('year, month, total')
        .gte('year', firstYear)
        .lte('year', lastYear);

    // (yıl, ay) → toplam. Anahtar: yıl * 100 + ay (çakışmasız, sıralanabilir).
    final byYearMonth = <int, num>{};
    for (final row in (rows as List)) {
      final map = Map<String, dynamic>.from(row as Map);
      final y = _asNum(map['year']).toInt();
      final m = _asNum(map['month']).toInt();
      if (m < 1 || m > 12) continue; // güvenlik
      byYearMonth[y * 100 + m] = _asNum(map['total']);
    }

    return [
      for (final d in monthStarts)
        (date: d, amount: byYearMonth[d.year * 100 + d.month] ?? 0),
    ];
  }
}
