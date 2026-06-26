enum PaymentType { nakit, pos, acikHesap, parcali }

extension PaymentTypeX on PaymentType {
  String get dbValue {
    switch (this) {
      case PaymentType.nakit: return 'nakit';
      case PaymentType.pos: return 'pos';
      case PaymentType.acikHesap: return 'acik_hesap';
      case PaymentType.parcali: return 'parcali';
    }
  }
  String get label {
    switch (this) {
      case PaymentType.nakit: return 'Nakit';
      case PaymentType.pos: return 'Pos';
      case PaymentType.acikHesap: return 'Açık Hesap';
      case PaymentType.parcali: return 'Parçalı';
    }
  }
  static PaymentType fromDb(String value) {
    switch (value) {
      case 'pos': return PaymentType.pos;
      case 'acik_hesap': return PaymentType.acikHesap;
      case 'parcali': return PaymentType.parcali;
      default: return PaymentType.nakit;
    }
  }
}

class Sale {
  final String id;
  final String saleCode;
  final String? customerId;
  final String? customerName;
  final String branch;
  final num totalAmount;
  final num discountPercent;
  final num discountAmount; // iskontonun kesin TL tutarı
  final String discountType; // 'percent' | 'tl' — kullanıcının girdiği mod
  final num paidAmount;
  final PaymentType paymentType;
  final num cashAmount;
  final num cardAmount;
  final num remainingDebt;
  final String? personnel;
  final String? note;
  final DateTime saleDate;
  final int totalProducts;

  const Sale({
    this.id = '',
    required this.saleCode,
    this.customerId,
    this.customerName,
    this.branch = 'ANA HESAP',
    this.totalAmount = 0,
    this.discountPercent = 0,
    this.discountAmount = 0,
    this.discountType = 'percent',
    this.paidAmount = 0,
    this.paymentType = PaymentType.nakit,
    this.cashAmount = 0,
    this.cardAmount = 0,
    this.remainingDebt = 0,
    this.personnel,
    this.note,
    required this.saleDate,
    this.totalProducts = 0,
  });

  factory Sale.fromMap(Map<String, dynamic> map) {
    final rawCustomer = map['customers'];
    final customer = rawCustomer is Map
        ? Map<String, dynamic>.from(rawCustomer)
        : rawCustomer is List && rawCustomer.isNotEmpty
            ? Map<String, dynamic>.from(rawCustomer.first as Map)
            : null;
    return Sale(
      id: map['id'] as String,
      saleCode: map['sale_code'] as String,
      customerId: map['customer_id'] as String?,
      customerName: customer?['name'] as String?,
      branch: map['branch'] as String? ?? 'ANA HESAP',
      totalAmount: map['total_amount'] as num? ?? 0,
      discountPercent: map['discount_percent'] as num? ?? 0,
      discountAmount: map['discount_amount'] as num? ?? 0,
      discountType: map['discount_type'] as String? ?? 'percent',
      paidAmount: map['paid_amount'] as num? ?? 0,
      paymentType: PaymentTypeX.fromDb(map['payment_type'] as String? ?? 'nakit'),
      cashAmount: map['cash_amount'] as num? ?? 0,
      cardAmount: map['card_amount'] as num? ?? 0,
      remainingDebt: map['remaining_debt'] as num? ?? 0,
      personnel: map['personnel'] as String?,
      note: map['note'] as String?,
      // Supabase UTC timestamp'i yerel saate (Türkiye UTC+3) çeviriyoruz
      saleDate: DateTime.parse(map['sale_date'] as String).toLocal(),
      totalProducts: (map['total_products'] as num?)?.toInt() ?? 0,
    );
  }
}
