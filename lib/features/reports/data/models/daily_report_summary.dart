import '../../../customers/data/models/customer_payment.dart';
import '../../../sales/data/models/sale.dart';

class DailyReportSummary {
  final List<Sale> sales;
  final num cashTotal;
  final num posTotal;
  final num openAccountTotal;
  final num grandTotal;
  final num turnover;
  final num productCost;
  final num profit;
  final List<CustomerPayment> receivedPayments;

  const DailyReportSummary({
    required this.sales,
    required this.cashTotal,
    required this.posTotal,
    required this.openAccountTotal,
    required this.grandTotal,
    required this.turnover,
    required this.productCost,
    required this.profit,
    required this.receivedPayments,
  });

  num get receivedPaymentsTotal =>
      receivedPayments.fold<num>(0, (sum, p) => sum + p.amount);
}
