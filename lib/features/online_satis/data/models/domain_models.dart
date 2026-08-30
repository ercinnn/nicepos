// Domain satın alma akışının veri modelleri (bkz. Edge Functions:
// supabase/functions/domain-search, domain-check, domain-purchase-initiate).

class DomainCandidate {
  final String domain;
  final bool available;
  final num priceAmount;
  final String priceCurrency;

  const DomainCandidate({
    required this.domain,
    required this.available,
    required this.priceAmount,
    required this.priceCurrency,
  });

  factory DomainCandidate.fromMap(Map<String, dynamic> map) {
    return DomainCandidate(
      domain: map['domain'] as String,
      available: map['available'] as bool? ?? false,
      priceAmount: map['priceAmount'] as num? ?? 0,
      priceCurrency: map['priceCurrency'] as String? ?? 'USD',
    );
  }
}

// Cloudflare Registrar'a giden alanlar (RegistrantContact, Edge Function
// tarafındaki isimlerle BİREBİR aynı) + identityNumber (yalnız iyzico'nun
// KYC şeması için, Cloudflare'e gönderilmez — bkz. domain-purchase-initiate
// Edge Function'ındaki not).
class DomainRegistrantContact {
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final String address;
  final String city;
  final String country;
  final String identityNumber;
  final String? zipCode;

  const DomainRegistrantContact({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.address,
    required this.city,
    required this.country,
    required this.identityNumber,
    this.zipCode,
  });

  Map<String, dynamic> toJson() => {
    'firstName': firstName,
    'lastName': lastName,
    'email': email,
    'phone': phone,
    'address': address,
    'city': city,
    'country': country,
    'identityNumber': identityNumber,
    if (zipCode != null && zipCode!.isNotEmpty) 'zipCode': zipCode,
  };
}

// domain_purchases satırının Flutter karşılığı — yalnız izleme/gösterim için
// gereken alanlar (bkz. 0047 migration).
class DomainPurchase {
  final String id;
  final String domain;
  final String status;
  final bool needsManualReview;
  final String? failureStage;

  const DomainPurchase({
    required this.id,
    required this.domain,
    required this.status,
    required this.needsManualReview,
    this.failureStage,
  });

  factory DomainPurchase.fromMap(Map<String, dynamic> map) {
    return DomainPurchase(
      id: map['id'] as String,
      domain: map['domain'] as String,
      status: map['status'] as String,
      needsManualReview: map['needs_manual_review'] as bool? ?? false,
      failureStage: map['failure_stage'] as String?,
    );
  }

  bool get isTerminal => status == 'connected' || status == 'failed';
}

class DomainPurchaseInitiateResult {
  final String purchaseId;
  final String? checkoutFormContent;
  final String? paymentPageUrl;

  const DomainPurchaseInitiateResult({
    required this.purchaseId,
    this.checkoutFormContent,
    this.paymentPageUrl,
  });
}
