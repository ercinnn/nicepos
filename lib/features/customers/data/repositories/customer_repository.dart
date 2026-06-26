import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/customer.dart';
import '../models/customer_payment.dart';
import '../../../sales/data/models/sale.dart';

class CustomerRepository {
  final SupabaseClient _client = Supabase.instance.client;

  Future<List<Customer>> fetchAll({String? query, bool onlyWithDebt = false}) async {
    var builder = _client.from('customer_balances').select();
    if (query != null && query.trim().isNotEmpty) {
      builder = builder.ilike('name', '%${query.trim()}%');
    }
    final rows = await builder.order('name').limit(100000);
    var customers = (rows as List).map((row) => Customer.fromMap(Map<String, dynamic>.from(row as Map))).toList();
    if (onlyWithDebt) {
      customers = customers.where((c) => c.remainingDebt > 0).toList();
    }
    return customers;
  }

  Future<Customer?> fetchById(String id) async {
    final row = await _client.from('customer_balances').select().eq('id', id).maybeSingle();
    if (row == null) return null;
    return Customer.fromMap(Map<String, dynamic>.from(row));
  }

  Future<List<Customer>> searchByName(String query) async {
    final rows = await _client.from('customers').select().ilike('name', '%$query%').order('name').limit(20);
    return (rows as List).map((row) => Customer.fromMap(Map<String, dynamic>.from(row as Map))).toList();
  }

  Future<String> create(Customer customer) async {
    final row = await _client.from('customers').insert(customer.toInsertMap()).select('id').single();
    return row['id'] as String;
  }

  Future<void> update(String id, Customer customer) async {
    await _client.from('customers').update(customer.toInsertMap()).eq('id', id);
  }

  Future<void> delete(String id) async {
    await _client.from('customers').delete().eq('id', id);
  }

  Future<List<Sale>> fetchSales(String customerId, {DateTime? from, DateTime? to}) async {
    var builder = _client.from('sales').select('*, customers(name)').eq('customer_id', customerId);
    if (from != null) builder = builder.gte('sale_date', from.toIso8601String());
    if (to != null) builder = builder.lte('sale_date', to.toIso8601String());
    final rows = await builder.order('sale_date', ascending: false);
    return (rows as List).map((row) => Sale.fromMap(Map<String, dynamic>.from(row as Map))).toList();
  }

  Future<List<CustomerPayment>> fetchPayments(String customerId, {CustomerPaymentType? type}) async {
    var builder = _client.from('customer_payments').select().eq('customer_id', customerId);
    if (type != null) builder = builder.eq('type', type.dbValue);
    final rows = await builder.order('payment_date', ascending: false);
    return (rows as List).map((row) => CustomerPayment.fromMap(Map<String, dynamic>.from(row as Map))).toList();
  }

  Future<void> addPayment(CustomerPayment payment) async {
    await _client.from('customer_payments').insert(payment.toInsertMap());
  }

  Future<void> deletePayment(String id) async {
    await _client.from('customer_payments').delete().eq('id', id);
  }

  Future<num> fetchTotalDebt() async {
    final customers = await fetchAll();
    return customers.fold<num>(0, (sum, c) => sum + c.remainingDebt);
  }
}
