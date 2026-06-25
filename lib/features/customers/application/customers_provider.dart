import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../data/models/customer.dart';
import '../data/models/customer_payment.dart';
import '../data/repositories/customer_repository.dart';
import '../../sales/data/models/sale.dart';

part 'customers_provider.g.dart';

@Riverpod(keepAlive: true)
CustomerRepository customerRepository(CustomerRepositoryRef ref) => CustomerRepository();

class CustomersQuery {
  final String? query;
  final bool onlyWithDebt;

  const CustomersQuery({this.query, this.onlyWithDebt = false});

  @override
  bool operator ==(Object other) =>
      other is CustomersQuery && other.query == query && other.onlyWithDebt == onlyWithDebt;

  @override
  int get hashCode => Object.hash(query, onlyWithDebt);
}

@riverpod
Future<List<Customer>> customers(CustomersRef ref, CustomersQuery q) {
  return ref.watch(customerRepositoryProvider).fetchAll(
        query: q.query,
        onlyWithDebt: q.onlyWithDebt,
      );
}

@riverpod
Future<Customer?> customerById(CustomerByIdRef ref, String id) {
  return ref.watch(customerRepositoryProvider).fetchById(id);
}

@riverpod
Future<num> totalCustomerDebt(TotalCustomerDebtRef ref) {
  return ref.watch(customerRepositoryProvider).fetchTotalDebt();
}

class CustomerSalesQuery {
  final String customerId;
  final DateTime? from;
  final DateTime? to;

  const CustomerSalesQuery({required this.customerId, this.from, this.to});

  @override
  bool operator ==(Object other) =>
      other is CustomerSalesQuery &&
      other.customerId == customerId &&
      other.from == from &&
      other.to == to;

  @override
  int get hashCode => Object.hash(customerId, from, to);
}

@riverpod
Future<List<Sale>> customerSales(CustomerSalesRef ref, CustomerSalesQuery q) {
  return ref.watch(customerRepositoryProvider).fetchSales(q.customerId, from: q.from, to: q.to);
}

@riverpod
Future<List<CustomerPayment>> customerPayments(CustomerPaymentsRef ref, String customerId) {
  return ref.watch(customerRepositoryProvider).fetchPayments(customerId);
}
