import 'dart:convert';

import 'product.dart';

enum PendingChangeOperation { create, update }

enum PendingChangeStatus { pending, syncing, failed }

/// Senkronu bekleyen TEK bir ürün ekleme/güncelleme kaydı. `pending_changes`
/// tablosunda `product_id` PRIMARY KEY olduğundan bir ürüne offline art arda
/// yapılan düzenlemeler ayrı satırlar değil, aynı satırın üzerine yazılır.
///
/// `payloadJson` kaydetme ANINDA donmuş bir map'tir (`{'id':..., ...toInsertMap()}`)
/// — sync anında canlı bir `Product`'tan YENİDEN üretilmez, aksi halde
/// `toInsertMap()`'in içine gömdüğü `updated_at` sync zamanını yansıtır,
/// asıl offline düzenleme zamanını değil.
class PendingChange {
  final String productId;
  final PendingChangeOperation operation;
  final String payloadJson;
  final String? pendingImagePath;
  final PendingChangeStatus status;
  final int attemptCount;
  final String? lastError;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PendingChange({
    required this.productId,
    required this.operation,
    required this.payloadJson,
    this.pendingImagePath,
    this.status = PendingChangeStatus.pending,
    this.attemptCount = 0,
    this.lastError,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Donmuş payload'dan `Product`'ı yeniden kurar (id dahil — `toInsertMap()`
  /// id içermez, payload kaydedilirken üstüne eklenmiştir).
  Product toProduct() => Product.fromMap(jsonDecode(payloadJson) as Map<String, dynamic>);

  factory PendingChange.fromMap(Map<String, dynamic> map) {
    return PendingChange(
      productId: map['product_id'] as String,
      operation: PendingChangeOperation.values.byName(map['operation'] as String),
      payloadJson: map['payload_json'] as String,
      pendingImagePath: map['pending_image_path'] as String?,
      status: PendingChangeStatus.values.byName(map['status'] as String),
      attemptCount: (map['attempt_count'] as num?)?.toInt() ?? 0,
      lastError: map['last_error'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'product_id': productId,
      'operation': operation.name,
      'payload_json': payloadJson,
      'pending_image_path': pendingImagePath,
      'status': status.name,
      'attempt_count': attemptCount,
      'last_error': lastError,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  PendingChange copyWith({
    PendingChangeOperation? operation,
    String? payloadJson,
    Object? pendingImagePath = _unset,
    PendingChangeStatus? status,
    int? attemptCount,
    Object? lastError = _unset,
    DateTime? updatedAt,
  }) {
    return PendingChange(
      productId: productId,
      operation: operation ?? this.operation,
      payloadJson: payloadJson ?? this.payloadJson,
      pendingImagePath:
          identical(pendingImagePath, _unset) ? this.pendingImagePath : pendingImagePath as String?,
      status: status ?? this.status,
      attemptCount: attemptCount ?? this.attemptCount,
      lastError: identical(lastError, _unset) ? this.lastError : lastError as String?,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

const _unset = Object();
