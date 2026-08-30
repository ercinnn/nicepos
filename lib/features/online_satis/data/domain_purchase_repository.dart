import 'package:supabase_flutter/supabase_flutter.dart';

import 'models/domain_models.dart';

// Domain arama/satın alma akışının tüm dış çağrıları — gerçek sırlar
// (Cloudflare/iyzico API anahtarları) burada DEĞİL, yalnız Supabase Edge
// Functions içinde yaşar (bkz. supabase/functions/). Bu repository yalnız
// `functions.invoke()` ile o fonksiyonları çağırır; `Authorization` header'ı
// supabase_flutter tarafından mevcut oturumdan otomatik eklenir.
class DomainPurchaseRepository {
  final SupabaseClient _client = Supabase.instance.client;

  Future<List<DomainCandidate>> search(String query) async {
    final res = await _invoke('domain-search', {'query': query});
    final results = (res['results'] as List? ?? []);
    return results
        .map((r) => DomainCandidate.fromMap(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  Future<List<DomainCandidate>> check(List<String> domains) async {
    final res = await _invoke('domain-check', {'domains': domains});
    final results = (res['results'] as List? ?? []);
    return results
        .map((r) => DomainCandidate.fromMap(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  Future<DomainPurchaseInitiateResult> initiate({
    required String domain,
    required DomainRegistrantContact registrant,
    required String callbackUrl,
  }) async {
    final res = await _invoke('domain-purchase-initiate', {
      'domain': domain,
      'registrant': registrant.toJson(),
      'callbackUrl': callbackUrl,
    });
    return DomainPurchaseInitiateResult(
      purchaseId: res['purchaseId'] as String,
      checkoutFormContent: res['checkoutFormContent'] as String?,
      paymentPageUrl: res['paymentPageUrl'] as String?,
    );
  }

  Future<DomainPurchase?> fetchPurchase(String id) async {
    final row = await _client
        .from('domain_purchases')
        .select('id, domain, status, needs_manual_review, failure_stage')
        .eq('id', id)
        .maybeSingle();
    if (row == null) return null;
    return DomainPurchase.fromMap(row);
  }

  Future<Map<String, dynamic>> _invoke(
    String functionName,
    Map<String, dynamic> body,
  ) async {
    try {
      final res = await _client.functions.invoke(functionName, body: body);
      final data = res.data;
      if (data is Map) return Map<String, dynamic>.from(data);
      throw Exception('Beklenmeyen yanıt: $data');
    } on FunctionException catch (e) {
      final details = e.details;
      final message = details is Map && details['error'] != null
          ? details['error'].toString()
          : e.reasonPhrase ?? 'İşlem başarısız oldu.';
      throw DomainPurchaseException(message);
    }
  }
}

class DomainPurchaseException implements Exception {
  final String message;
  const DomainPurchaseException(this.message);

  @override
  String toString() => message;
}
