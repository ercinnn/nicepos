import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../customers/data/models/customer_payment.dart';
import '../../../sales/data/models/sale.dart';
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

  Future<DailyReportSummary> _fetchSummary(DateTime start, DateTime end) async {
    // UTC olarak gönderiyoruz: yerel gece yarısı → doğru UTC sınırı (Türkiye UTC+3)
    final salesRows = await _client
        .from('sales')
        .select('*, customers(name), sale_items(quantity, total, product_id, products(purchase_price))')
        .gte('sale_date', start.toUtc().toIso8601String())
        .lt('sale_date', end.toUtc().toIso8601String())
        .order('sale_date', ascending: false);

    num cashTotal = 0;
    num posTotal = 0;
    num openAccountTotal = 0;
    num turnover = 0;
    num productCost = 0;
    final sales = <Sale>[];

    for (final row in (salesRows as List)) {
      final map = Map<String, dynamic>.from(row as Map);
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

    // UTC olarak gönderiyoruz: yerel gece yarısı → doğru UTC sınırı (Türkiye UTC+3)
    final paymentRows = await _client
        .from('customer_payments')
        .select('*, customers(name)')
        .eq('type', 'odeme')
        .gte('payment_date', start.toUtc().toIso8601String())
        .lt('payment_date', end.toUtc().toIso8601String())
        .order('payment_date', ascending: false);

    final receivedPayments = (paymentRows as List)
        .map((row) => CustomerPayment.fromMap(Map<String, dynamic>.from(row as Map)))
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
