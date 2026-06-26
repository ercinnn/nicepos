import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/cart_item.dart';
import '../models/sale.dart';
import '../models/sale_item.dart';
import '../../../customers/data/models/customer_payment.dart';
import '../../../customers/data/repositories/customer_repository.dart';
import '../../../products/data/repositories/product_repository.dart';

class SalesRepository {
  final SupabaseClient _client = Supabase.instance.client;
  final ProductRepository _productRepository = ProductRepository();
  final CustomerRepository _customerRepository = CustomerRepository();

  Future<List<Sale>> fetchByDate(DateTime date) async {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    // UTC olarak gönderiyoruz: yerel gece yarısı → doğru UTC sınırı (Türkiye UTC+3)
    final rows = await _client
        .from('sales')
        .select('*, customers(name), sale_items(quantity)')
        .gte('sale_date', start.toUtc().toIso8601String())
        .lt('sale_date', end.toUtc().toIso8601String())
        .order('sale_date', ascending: false);
    return (rows as List).map((row) {
      final map = Map<String, dynamic>.from(row as Map);
      final items = map['sale_items'] as List?;
      final totalProducts = items == null
          ? 0
          : items.fold<num>(0, (sum, item) => sum + ((item['quantity'] as num?) ?? 0)).round();
      return Sale.fromMap({...map, 'total_products': totalProducts});
    }).toList();
  }

  Future<Sale> fetchSaleById(String saleId) async {
    final row = await _client
        .from('sales')
        .select('*, customers(name), sale_items(quantity)')
        .eq('id', saleId)
        .single();
    final map = Map<String, dynamic>.from(row);
    final items = map['sale_items'] as List?;
    final totalProducts = items == null
        ? 0
        : items.fold<num>(0, (sum, item) => sum + ((item['quantity'] as num?) ?? 0)).round();
    return Sale.fromMap({...map, 'total_products': totalProducts});
  }

  Future<List<SaleItem>> fetchItems(String saleId) async {
    final rows = await _client.from('sale_items').select().eq('sale_id', saleId);
    return (rows as List).map((row) => SaleItem.fromMap(Map<String, dynamic>.from(row as Map))).toList();
  }

  Future<void> updateSale({
    required String saleId,
    required List<SaleItem> oldItems,
    required List<SaleItem> items,
    required num totalAmount,
    required num discountPercent,
    num discountAmount = 0,
    String discountType = 'percent',
    required num paidAmount,
    required num cashAmount,
    required num cardAmount,
    required num remainingDebt,
  }) async {
    await _client.from('sale_items').delete().eq('sale_id', saleId);

    if (items.isNotEmpty) {
      await _client.from('sale_items').insert(
        items.map((item) => item.toInsertMap(saleId)).toList(),
      );
    }

    await _client.from('sales').update({
      'total_amount': totalAmount,
      'discount_percent': discountPercent,
      'discount_amount': discountAmount,
      'discount_type': discountType,
      'paid_amount': paidAmount,
      'cash_amount': cashAmount,
      'card_amount': cardAmount,
      'remaining_debt': remainingDebt,
    }).eq('id', saleId);

    for (final item in oldItems) {
      if (item.productId != null) {
        await _productRepository.incrementStock(item.productId!, item.quantity);
      }
    }

    for (final item in items) {
      if (item.productId != null) {
        await _productRepository.decrementStock(item.productId!, item.quantity);
      }
    }
  }

  /// Bir satışı tamamen siler ve completeSale'in yan etkilerini geri alır.
  ///
  /// Sıra ve gerekçe:
  /// 1. sale_items'tan ürün/miktar bilgisi okunur (stok iadesi için).
  /// 2. Satılan ürünlerin STOĞU geri eklenir (completeSale decrementStock yapıyordu).
  /// 3. Bu satışa bağlı customer_payments kayıtları (sale_id) silinir.
  ///    completeSale açık hesap satışında sale_id'li bir 'borc' hareketi
  ///    ekliyordu; customer_balances görünümü borcu bu hareketlerden hesapladığı
  ///    için kaydı silmek borcu doğrudan geri alır (ters kayıt eklemeye gerek yok).
  /// 4. sale_items silinir (FK), sonra sales kaydı silinir.
  Future<void> deleteSale(String saleId) async {
    // 1. Stok iadesi için kalemleri oku
    final items = await fetchItems(saleId);

    // 2. Stoğu geri ekle
    for (final item in items) {
      if (item.productId != null) {
        await _productRepository.incrementStock(item.productId!, item.quantity);
      }
    }

    // 3. Satışa bağlı borç/ödeme hareketlerini sil (açık hesap borcunu geri alır)
    await _client.from('customer_payments').delete().eq('sale_id', saleId);

    // 4. Kalemleri, sonra satışı sil (FK sırası)
    await _client.from('sale_items').delete().eq('sale_id', saleId);
    final deleted = await _client.from('sales').delete().eq('id', saleId).select('id');
    if (deleted.isEmpty) throw Exception('Satış silinemedi.');
  }

  Future<String> completeSale({
    required List<CartItem> items,
    required num discountPercent,
    required num totalAmount,
    required num paidAmount,
    required PaymentType paymentType,
    required num cashAmount,
    required num cardAmount,
    String? customerId,
    String? personnel,
    String? note,
  }) async {
    final saleCodeResult = await _client.rpc('generate_sale_code');
    final saleCode = saleCodeResult as String;
    final remainingDebt = (totalAmount - cashAmount - cardAmount).clamp(0, double.infinity);
    // İskontonun kesin TL tutarı: brüt (kalem toplamları) − net toplam.
    final subtotal = items.fold<num>(0, (sum, item) => sum + item.total);
    final discountAmount = (subtotal - totalAmount).clamp(0, double.infinity);

    final saleRow = await _client.from('sales').insert({
      'sale_code': saleCode,
      'customer_id': customerId,
      'total_amount': totalAmount,
      'discount_percent': discountPercent,
      'discount_amount': discountAmount,
      'discount_type': 'percent',
      'paid_amount': paidAmount,
      'payment_type': paymentType.dbValue,
      'cash_amount': cashAmount,
      'card_amount': cardAmount,
      'remaining_debt': remainingDebt,
      'personnel': personnel ?? 'Yönetici',
      'note': note,
      // Türkiye saatiyle kaydedilsin diye UTC olarak gönderiyoruz
      'sale_date': DateTime.now().toUtc().toIso8601String(),
    }).select('id').single();

    final saleId = saleRow['id'] as String;

    if (items.isNotEmpty) {
      await _client.from('sale_items').insert(
        items.map((item) => SaleItem(
          productId: item.productId,
          productName: item.productName,
          quantity: item.quantity,
          unitPrice: item.unitPrice,
          discountValue: item.discountAmount,
          total: item.total,
        ).toInsertMap(saleId)).toList(),
      );
    }

    for (final item in items) {
      if (item.productId != null) {
        await _productRepository.decrementStock(item.productId!, item.quantity);
      }
    }

    if (customerId != null && remainingDebt > 0) {
      await _customerRepository.addPayment(CustomerPayment(
        customerId: customerId,
        saleId: saleId,
        type: CustomerPaymentType.borc,
        amount: remainingDebt,
        note: 'Satış: $saleCode',
        paymentDate: DateTime.now(),
      ));
    }

    return saleCode;
  }

  Future<String> completeReturn({
    required List<CartItem> items,
    required num totalAmount,
    required PaymentType paymentType,
    String? customerId,
    String? note,
  }) async {
    final saleCodeResult = await _client.rpc('generate_sale_code');
    final saleCode = saleCodeResult as String;

    final saleRow = await _client.from('sales').insert({
      'sale_code': saleCode,
      'customer_id': customerId,
      'total_amount': -totalAmount,
      'discount_percent': 0,
      'discount_amount': 0,
      'discount_type': 'percent',
      'paid_amount': -totalAmount,
      'payment_type': paymentType.dbValue,
      'cash_amount': paymentType == PaymentType.nakit ? -totalAmount : 0,
      'card_amount': paymentType == PaymentType.pos ? -totalAmount : 0,
      'remaining_debt': 0,
      'personnel': 'Yönetici',
      'note': '[İADE]${note != null && note.isNotEmpty ? ' $note' : ''}',
      // Türkiye saatiyle kaydedilsin diye UTC olarak gönderiyoruz
      'sale_date': DateTime.now().toUtc().toIso8601String(),
    }).select('id').single();

    final saleId = saleRow['id'] as String;

    if (items.isNotEmpty) {
      await _client.from('sale_items').insert(
        items.map((item) => SaleItem(
          productId: item.productId,
          productName: item.productName,
          quantity: item.quantity,
          unitPrice: item.unitPrice,
          discountValue: 0,
          total: item.total,
        ).toInsertMap(saleId)).toList(),
      );
    }

    for (final item in items) {
      if (item.productId != null) {
        await _productRepository.incrementStock(item.productId!, item.quantity);
      }
    }

    return saleCode;
  }
}
