import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/imported_sale_row.dart';

/// Eski satış raporu (xlsx) içe aktarımı için repository.
///
/// Tekrar çalıştırmaya dayanıklıdır: `sales.sale_code` benzersiz olduğundan
/// daha önce aktarılmış satış kodları atlanır (aynı dosya iki kez yüklenirse
/// mükerrer kayıt oluşmaz).
class SalesImportRepository {
  final SupabaseClient _client = Supabase.instance.client;

  // İsim → müşteri id önbelleği (tek import oturumu boyunca).
  final Map<String, String> _customerCache = {};

  /// Verilen satış kodlarından veritabanında zaten var olanları döndürür.
  Future<Set<String>> existingSaleCodes(List<String> codes) async {
    final existing = <String>{};
    const chunkSize = 200;
    for (var i = 0; i < codes.length; i += chunkSize) {
      final end = (i + chunkSize) > codes.length ? codes.length : i + chunkSize;
      final chunk = codes.sublist(i, end);
      final rows =
          await _client.from('sales').select('sale_code').inFilter('sale_code', chunk);
      for (final r in (rows as List)) {
        final code = (r as Map)['sale_code'] as String?;
        if (code != null) existing.add(code);
      }
    }
    return existing;
  }

  /// İsme göre müşteri bulur; yoksa oluşturur. Müşteri id'sini döndürür.
  Future<String> _findOrCreateCustomer(String name) async {
    final key = name.trim();
    final cached = _customerCache[key];
    if (cached != null) return cached;

    final found =
        await _client.from('customers').select('id').eq('name', key).maybeSingle();
    String id;
    if (found != null) {
      id = found['id'] as String;
    } else {
      final created =
          await _client.from('customers').insert({'name': key}).select('id').single();
      id = created['id'] as String;
    }
    _customerCache[key] = id;
    return id;
  }

  /// Tek bir eski satışı yazar: yalnızca `sales` kaydı.
  ///
  /// - Ürün kalemi (`sale_items`) **yazılmaz** (eski rapor ürün kırılımı içermez).
  /// - Ödeme yalnızca nakit/pos; borç (`customer_payments`) **oluşturulmaz**
  ///   (geçmiş borçlar müşteri sayfasından elle girilir).
  /// - İadelerde tutar/nakit/kart negatiftir (raporlardan düşülür).
  /// - Müşteri adı varsa ilgili müşteri bulunur/oluşturulur ve satışa bağlanır.
  Future<void> importSale(ImportedSaleRow row) async {
    String? customerId;
    if (row.customerName != null && row.customerName!.isNotEmpty) {
      customerId = await _findOrCreateCustomer(row.customerName!);
    }

    await _client.from('sales').insert({
      'sale_code': row.saleCode,
      'customer_id': customerId,
      'branch': row.branch,
      'total_amount': row.totalAmount,
      'discount_percent': row.discountPercent,
      'discount_amount': row.discountAmount,
      'discount_type': 'percent',
      'paid_amount': row.paidAmount,
      'payment_type': row.paymentTypeDb, // yalnızca 'nakit' | 'pos'
      'cash_amount': row.cashAmount,
      'card_amount': row.cardAmount,
      'remaining_debt': 0,
      'personnel': row.personnel ?? 'Yönetici',
      'note': row.note,
      // Yerel saat .toUtc() ile yazılır (uygulamanın tarih konvansiyonu)
      'sale_date': row.saleDate.toUtc().toIso8601String(),
    });
  }
}
