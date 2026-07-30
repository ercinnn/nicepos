import 'dart:convert';

import 'cart_item.dart';
import 'sale.dart';

enum PendingSaleStatus { pending, failed }

/// Senkronu bekleyen TEK bir Nakit/POS satış kaydı (`pending_sales`, `id`
/// PRIMARY KEY — istemcide üretilen uuid). `pending_changes`'in aksine
/// APPEND-ONLY: bir satış offline'da tekrar "düzenlenmez" — `SaleEditScreen`
/// bekleyen bir satışa offline'da hiç erişemez, zaten sync'ten önce sunucuda
/// hiç görünmez.
///
/// `payloadJson` tamamlama ANINDA donmuş halidir — sync anında canlı sepetten
/// YENİDEN üretilmez (sepet tamamlanınca zaten temizlenir).
class PendingSale {
  final String id;
  final String payloadJson;

  /// Yalnız görüntüleme için — gerçek `sale_code` `generate_sale_code` RPC'si
  /// server-only bir sequence kullandığından offline'da üretilemez, SENKRON
  /// anında atanır (bkz. `SaleSyncService`).
  final String localSaleCode;

  final PendingSaleStatus status;
  final int attemptCount;
  final String? lastError;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PendingSale({
    required this.id,
    required this.payloadJson,
    required this.localSaleCode,
    this.status = PendingSaleStatus.pending,
    this.attemptCount = 0,
    this.lastError,
    required this.createdAt,
    required this.updatedAt,
  });

  PendingSalePayload get payload =>
      PendingSalePayload.fromMap(jsonDecode(payloadJson) as Map<String, dynamic>);

  factory PendingSale.fromMap(Map<String, dynamic> map) {
    return PendingSale(
      id: map['id'] as String,
      payloadJson: map['payload_json'] as String,
      localSaleCode: map['local_sale_code'] as String,
      status: PendingSaleStatus.values.byName(map['status'] as String),
      attemptCount: (map['attempt_count'] as num?)?.toInt() ?? 0,
      lastError: map['last_error'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'payload_json': payloadJson,
      'local_sale_code': localSaleCode,
      'status': status.name,
      'attempt_count': attemptCount,
      'last_error': lastError,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  PendingSale copyWith({
    PendingSaleStatus? status,
    int? attemptCount,
    Object? lastError = _unset,
    DateTime? updatedAt,
  }) {
    return PendingSale(
      id: id,
      payloadJson: payloadJson,
      localSaleCode: localSaleCode,
      status: status ?? this.status,
      attemptCount: attemptCount ?? this.attemptCount,
      lastError: identical(lastError, _unset) ? this.lastError : lastError as String?,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

const _unset = Object();

/// Donmuş satış isteği — `SalesRepository.completeSale()` parametrelerinin
/// JSON-serileştirilebilir hali (v1 yalnız Nakit/POS kuyruklandığından
/// `customerId` dolu olsa bile `remainingDebt` her zaman 0'dır — borç
/// hareketi asla yazılmaz, bkz. `SaleSyncService`).
class PendingSalePayload {
  final List<CartItem> items;
  final num discountPercent;
  final num totalAmount;
  final num paidAmount;
  final PaymentType paymentType;
  final num cashAmount;
  final num cardAmount;
  final String? customerId;
  final String? personnel;
  final String? note;

  const PendingSalePayload({
    required this.items,
    required this.discountPercent,
    required this.totalAmount,
    required this.paidAmount,
    required this.paymentType,
    required this.cashAmount,
    required this.cardAmount,
    this.customerId,
    this.personnel,
    this.note,
  });

  factory PendingSalePayload.fromMap(Map<String, dynamic> map) {
    return PendingSalePayload(
      items: (map['items'] as List)
          .map((i) => CartItem.fromMap(Map<String, dynamic>.from(i as Map)))
          .toList(),
      discountPercent: map['discount_percent'] as num? ?? 0,
      totalAmount: map['total_amount'] as num? ?? 0,
      paidAmount: map['paid_amount'] as num? ?? 0,
      paymentType: PaymentTypeX.fromDb(map['payment_type'] as String? ?? 'nakit'),
      cashAmount: map['cash_amount'] as num? ?? 0,
      cardAmount: map['card_amount'] as num? ?? 0,
      customerId: map['customer_id'] as String?,
      personnel: map['personnel'] as String?,
      note: map['note'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'items': items.map((i) => i.toMap()).toList(),
      'discount_percent': discountPercent,
      'total_amount': totalAmount,
      'paid_amount': paidAmount,
      'payment_type': paymentType.dbValue,
      'cash_amount': cashAmount,
      'card_amount': cardAmount,
      'customer_id': customerId,
      'personnel': personnel,
      'note': note,
    };
  }
}
