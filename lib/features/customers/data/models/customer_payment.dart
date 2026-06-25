enum CustomerPaymentType { odeme, borc }

extension CustomerPaymentTypeX on CustomerPaymentType {
  String get dbValue => this == CustomerPaymentType.odeme ? 'odeme' : 'borc';
  String get label => this == CustomerPaymentType.odeme ? 'Ödeme' : 'Borç';
  static CustomerPaymentType fromDb(String value) =>
      value == 'odeme' ? CustomerPaymentType.odeme : CustomerPaymentType.borc;
}

class CustomerPayment {
  final String id;
  final String customerId;
  final String? customerName;
  final String? saleId;
  final CustomerPaymentType type;
  final num amount;
  final String? note;
  final DateTime paymentDate;

  const CustomerPayment({
    this.id = '',
    required this.customerId,
    this.customerName,
    this.saleId,
    required this.type,
    required this.amount,
    this.note,
    required this.paymentDate,
  });

  factory CustomerPayment.fromMap(Map<String, dynamic> map) {
    final rawCustomer = map['customers'];
    final customer = rawCustomer is Map
        ? Map<String, dynamic>.from(rawCustomer)
        : rawCustomer is List && rawCustomer.isNotEmpty
            ? Map<String, dynamic>.from(rawCustomer.first as Map)
            : null;
    return CustomerPayment(
      id: map['id'] as String,
      customerId: map['customer_id'] as String,
      customerName: customer?['name'] as String?,
      saleId: map['sale_id'] as String?,
      type: CustomerPaymentTypeX.fromDb(map['type'] as String),
      amount: map['amount'] as num? ?? 0,
      note: map['note'] as String?,
      // Supabase UTC timestamp'i yerel saate (Türkiye UTC+3) çeviriyoruz
      paymentDate: DateTime.parse(map['payment_date'] as String).toLocal(),
    );
  }

  Map<String, dynamic> toInsertMap() {
    return {
      'customer_id': customerId,
      'sale_id': saleId,
      'type': type.dbValue,
      'amount': amount,
      'note': note,
      // UTC olarak gönderiyoruz — Supabase timestamptz alanı UTC saklar
      'payment_date': paymentDate.toUtc().toIso8601String(),
    };
  }
}
