import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../customers/data/models/customer_payment.dart';
import '../../../sales/data/models/sale.dart';
import '../models/best_seller_record.dart';
import '../models/daily_report_summary.dart';
import '../models/product_sale_record.dart';

class ReportRepository {
  final SupabaseClient _client = Supabase.instance.client;

  Future<DailyReportSummary> fetchDailyReport(DateTime date) async {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    return _fetchSummary(start, end);
  }

  Future<DailyReportSummary> fetchDateRangeReport(DateTime start, DateTime end) async {
    final startDay = DateTime(start.year, start.month, start.day);
    final endDay = DateTime(end.year, end.month, end.day).add(const Duration(days: 1));
    return _fetchSummary(startDay, endDay);
  }

  // Rapor özetinin iki bağımsız veri kaynağı (satışlar · tahsilatlar) ayrı
  // sayfalı çekimlerdir. Bir sayfa dizisi kendi içinde sıralı olmak ZORUNDA
  // (bir sonraki `range` bir öncekinin dolu gelmesine bağlı), ama iki DİZİ
  // birbirinden bağımsız → `_fetchSummary` bunları paralel başlatır.
  Future<List<Map<String, dynamic>>> _fetchSalesRows(
      DateTime start, DateTime end) async {
    const pageSize = 1000;
    final salesRows = <Map<String, dynamic>>[];
    var salesFrom = 0;
    while (true) {
      final page = await _client
          .from('sales')
          .select('*, customers(name), sale_items(quantity, total, product_id, products(purchase_price))')
          .gte('sale_date', start.toUtc().toIso8601String())
          .lt('sale_date', end.toUtc().toIso8601String())
          .order('sale_date', ascending: false)
          .range(salesFrom, salesFrom + pageSize - 1);
      final list = (page as List)
          .map((r) => Map<String, dynamic>.from(r as Map))
          .toList();
      salesRows.addAll(list);
      if (list.length < pageSize) break;
      salesFrom += pageSize;
    }
    return salesRows;
  }

  Future<List<Map<String, dynamic>>> _fetchPaymentRows(
      DateTime start, DateTime end) async {
    const pageSize = 1000;
    final paymentRows = <Map<String, dynamic>>[];
    var paymentFrom = 0;
    while (true) {
      final page = await _client
          .from('customer_payments')
          .select('*, customers(name)')
          .eq('type', 'odeme')
          .gte('payment_date', start.toUtc().toIso8601String())
          .lt('payment_date', end.toUtc().toIso8601String())
          .order('payment_date', ascending: false)
          .range(paymentFrom, paymentFrom + pageSize - 1);
      final list = (page as List)
          .map((r) => Map<String, dynamic>.from(r as Map))
          .toList();
      paymentRows.addAll(list);
      if (list.length < pageSize) break;
      paymentFrom += pageSize;
    }
    return paymentRows;
  }

  Future<DailyReportSummary> _fetchSummary(DateTime start, DateTime end) async {
    // UTC olarak gönderiyoruz: yerel gece yarısı → doğru UTC sınırı (Türkiye UTC+3)
    // ⚠️ PERFORMANS: iki sayfalı çekim PARALEL (önceden satışlar tamamen
    // bitmeden tahsilatlar başlamıyordu).
    final (salesRows, paymentRows) = await (
      _fetchSalesRows(start, end),
      _fetchPaymentRows(start, end),
    ).wait;

    num cashTotal = 0;
    num posTotal = 0;
    num openAccountTotal = 0;
    num turnover = 0;
    num productCost = 0;
    final sales = <Sale>[];

    for (final map in salesRows) {
      final items = (map['sale_items'] as List?) ?? [];
      var totalProducts = 0;
      for (final item in items) {
        final itemMap = Map<String, dynamic>.from(item as Map);
        final quantity = (itemMap['quantity'] as num?) ?? 0;
        totalProducts += quantity.round();
        final rawProduct = itemMap['products'];
        final product = rawProduct is Map
            ? Map<String, dynamic>.from(rawProduct)
            : rawProduct is List && rawProduct.isNotEmpty
                ? Map<String, dynamic>.from(rawProduct.first as Map)
                : null;
        final purchasePrice = (product?['purchase_price'] as num?) ?? 0;
        productCost += purchasePrice * quantity;
      }
      final cashAmount = (map['cash_amount'] as num?) ?? 0;
      final cardAmount = (map['card_amount'] as num?) ?? 0;
      final remainingDebt = (map['remaining_debt'] as num?) ?? 0;
      final totalAmount = (map['total_amount'] as num?) ?? 0;
      cashTotal += cashAmount;
      posTotal += cardAmount;
      openAccountTotal += remainingDebt;
      turnover += totalAmount;
      sales.add(Sale.fromMap({...map, 'total_products': totalProducts}));
    }

    final receivedPayments = paymentRows
        .map((row) => CustomerPayment.fromMap(row))
        .toList();

    return DailyReportSummary(
      sales: sales,
      cashTotal: cashTotal,
      posTotal: posTotal,
      openAccountTotal: openAccountTotal,
      grandTotal: cashTotal + posTotal + openAccountTotal,
      turnover: turnover,
      productCost: productCost,
      profit: turnover - productCost,
      receivedPayments: receivedPayments,
    );
  }

  /// En Çok Satanlar raporu (design-tokens §5, KARAR v1.6).
  ///
  /// Seçili tarih aralığında satılan ürünleri, satılan **toplam adede göre
  /// azalan** sırayla döndürür. Yalnızca güncel satış fiyatı (`price1`) verilen
  /// [minPrice] eşiğine eşit/büyük olan ürünler listelenir.
  ///
  /// Aggregation (Dart tarafı): `product_id`'ye göre grupla → adet = Σ quantity,
  /// son satış tarihi = max(sale_date). Birim fiyat = ürünün güncel `price1`'i.
  Future<List<BestSellerRecord>> fetchBestSellers({
    required DateTime start,
    required DateTime end,
    required num minPrice,
  }) async {
    // Yerel gece yarısı sınırları → UTC (Türkiye UTC+3). Bitiş günü dahil edilir.
    final startDay = DateTime(start.year, start.month, start.day);
    final endDay =
        DateTime(end.year, end.month, end.day).add(const Duration(days: 1));

    // PostgREST 1000 satır limitini aşmak için sayfalı çekim.
    // sales!inner: yalnızca aralıktaki satışlara ait kalemleri getirir
    // (gömülü kaynak filtresi ana satırları da kısıtlasın diye inner join).
    const pageSize = 1000;
    final rows = <Map<String, dynamic>>[];
    var from = 0;
    while (true) {
      final page = await _client
          .from('sale_items')
          .select(
              'quantity, product_id, sales!inner(sale_date), products(name, barcode, price1)')
          .gte('sales.sale_date', startDay.toUtc().toIso8601String())
          .lt('sales.sale_date', endDay.toUtc().toIso8601String())
          .order('product_id')
          .range(from, from + pageSize - 1);
      final list = (page as List)
          .map((r) => Map<String, dynamic>.from(r as Map))
          .toList();
      rows.addAll(list);
      if (list.length < pageSize) break;
      from += pageSize;
    }

    // product_id → toplam adet + son satış tarihi + ürün bilgisi.
    final agg = <String, _BestSellerAgg>{};
    for (final row in rows) {
      final productId = row['product_id'] as String?;
      if (productId == null) continue;

      final rawProduct = row['products'];
      final product = rawProduct is Map
          ? Map<String, dynamic>.from(rawProduct)
          : rawProduct is List && rawProduct.isNotEmpty
              ? Map<String, dynamic>.from(rawProduct.first as Map)
              : null;
      if (product == null) continue; // silinmiş ürün → atla

      final rawSale = row['sales'];
      final sale = rawSale is Map
          ? Map<String, dynamic>.from(rawSale)
          : rawSale is List && rawSale.isNotEmpty
              ? Map<String, dynamic>.from(rawSale.first as Map)
              : null;
      if (sale == null) continue;

      // Supabase UTC timestamp → yerel saat (Türkiye UTC+3).
      final saleDate = DateTime.parse(sale['sale_date'] as String).toLocal();
      final quantity = (row['quantity'] as num?) ?? 0;

      final existing = agg[productId];
      if (existing == null) {
        agg[productId] = _BestSellerAgg(
          name: (product['name'] as String?) ?? '-',
          barcode: product['barcode'] as String?,
          price1: (product['price1'] as num?) ?? 0,
          quantity: quantity,
          lastSaleDate: saleDate,
        );
      } else {
        existing.quantity += quantity;
        if (saleDate.isAfter(existing.lastSaleDate)) {
          existing.lastSaleDate = saleDate;
        }
      }
    }

    // Fiyat filtresi (güncel price1 ≥ minPrice) + adet azalan sıralama.
    final records = agg.entries
        .where((e) => e.value.price1 >= minPrice)
        .map((e) => BestSellerRecord(
              productId: e.key,
              name: e.value.name,
              barcode: e.value.barcode,
              price1: e.value.price1,
              quantity: e.value.quantity,
              lastSaleDate: e.value.lastSaleDate,
            ))
        .toList();
    records.sort((a, b) => b.quantity.compareTo(a.quantity));
    return records;
  }

  Future<List<ProductSaleRecord>> fetchProductSalesHistory(String productId) async {
    final rows = await _client
        .from('sale_items')
        .select('quantity, unit_price, total, sales(id, sale_code, sale_date, customers(name))')
        .eq('product_id', productId)
        .limit(2000);

    final records = <ProductSaleRecord>[];
    for (final row in (rows as List)) {
      final itemMap = Map<String, dynamic>.from(row as Map);

      final rawSale = itemMap['sales'];
      final saleMap = rawSale is Map
          ? Map<String, dynamic>.from(rawSale)
          : rawSale is List && rawSale.isNotEmpty
              ? Map<String, dynamic>.from(rawSale.first as Map)
              : null;
      if (saleMap == null) continue;

      final rawCustomer = saleMap['customers'];
      final customerMap = rawCustomer is Map
          ? Map<String, dynamic>.from(rawCustomer)
          : rawCustomer is List && rawCustomer.isNotEmpty
              ? Map<String, dynamic>.from(rawCustomer.first as Map)
              : null;

      records.add(ProductSaleRecord(
        saleId: saleMap['id'] as String,
        saleCode: saleMap['sale_code'] as String,
        // Supabase UTC timestamp'i yerel saate (Türkiye UTC+3) çeviriyoruz
        saleDate: DateTime.parse(saleMap['sale_date'] as String).toLocal(),
        quantity: itemMap['quantity'] as num? ?? 0,
        unitPrice: itemMap['unit_price'] as num? ?? 0,
        total: itemMap['total'] as num? ?? 0,
        customerName: customerMap?['name'] as String?,
      ));
    }

    records.sort((a, b) => b.saleDate.compareTo(a.saleDate));
    return records;
  }
}

/// En Çok Satanlar aggregation'ı için değişebilir (mutable) ara birikim kabı.
class _BestSellerAgg {
  final String name;
  final String? barcode;
  final num price1;
  num quantity;
  DateTime lastSaleDate;

  _BestSellerAgg({
    required this.name,
    required this.barcode,
    required this.price1,
    required this.quantity,
    required this.lastSaleDate,
  });
}
