class Customer {
  final String id;
  final String name;
  final int? paymentTermDays;
  final String? phone;
  final String? address;
  final String? note;
  final num creditLimit;
  final String? taxOffice;
  final String? taxNumber;
  final int purchaseCount;
  final num openAccountTotal;
  final num paidTotal;
  final num remainingDebt;
  final DateTime? lastPaymentDate;

  const Customer({
    this.id = '',
    required this.name,
    this.paymentTermDays,
    this.phone,
    this.address,
    this.note,
    this.creditLimit = 0,
    this.taxOffice,
    this.taxNumber,
    this.purchaseCount = 0,
    this.openAccountTotal = 0,
    this.paidTotal = 0,
    this.remainingDebt = 0,
    this.lastPaymentDate,
  });

  factory Customer.fromMap(Map<String, dynamic> map) {
    return Customer(
      id: map['id'] as String,
      name: map['name'] as String,
      paymentTermDays: (map['payment_term_days'] as num?)?.toInt(),
      phone: map['phone'] as String?,
      address: map['address'] as String?,
      note: map['note'] as String?,
      creditLimit: map['credit_limit'] as num? ?? 0,
      taxOffice: map['tax_office'] as String?,
      taxNumber: map['tax_number'] as String?,
      purchaseCount: (map['purchase_count'] as num?)?.toInt() ?? 0,
      openAccountTotal: map['open_account_total'] as num? ?? 0,
      paidTotal: map['paid_total'] as num? ?? 0,
      remainingDebt: map['remaining_debt'] as num? ?? 0,
      lastPaymentDate: map['last_payment_date'] == null
          ? null
          : DateTime.parse(map['last_payment_date'] as String),
    );
  }

  Map<String, dynamic> toInsertMap() {
    return {
      'name': name,
      'payment_term_days': paymentTermDays,
      'phone': phone,
      'address': address,
      'note': note,
      'credit_limit': creditLimit,
      'tax_office': taxOffice,
      'tax_number': taxNumber,
    };
  }
}
