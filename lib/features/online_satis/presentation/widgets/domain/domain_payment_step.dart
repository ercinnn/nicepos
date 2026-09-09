import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../../data/domain_purchase_repository.dart';
import '../../../data/models/domain_models.dart';

// Ödeme adımı — `domain-purchase-initiate` Edge Function'ını çağırıp iyzico
// Checkout Form'unu (`paymentPageUrl`) yeni bir sekmede/tarayıcıda açar.
// Flutter web'de native webview/iframe embed YOK (`HtmlElementView` kullanmak
// Android derlemesini bozar — bu ekran her iki platformda da çalışıyor) —
// bu yüzden tam sayfa yönlendirme deseni seçildi: kullanıcı ödemeyi iyzico'nun
// kendi sayfasında tamamlar, gerçek sonuç HER ZAMAN sunucu tarafı webhook'tan
// gelir (bu ekranın "dönüş" olayına HİÇ güvenilmez) — bkz. domain_status_tracker.dart.
class DomainPaymentStep extends StatefulWidget {
  final DomainCandidate candidate;
  final DomainRegistrantContact registrant;
  final ValueChanged<String> onInitiated; // purchaseId

  const DomainPaymentStep({
    super.key,
    required this.candidate,
    required this.registrant,
    required this.onInitiated,
  });

  @override
  State<DomainPaymentStep> createState() => _DomainPaymentStepState();
}

class _DomainPaymentStepState extends State<DomainPaymentStep> {
  final _repository = DomainPurchaseRepository();
  bool _loading = false;
  String? _error;

  Future<void> _pay() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _repository.initiate(
        domain: widget.candidate.domain,
        registrant: widget.registrant,
        // Ödeme sonrası iyzico kullanıcıyı buraya döndürür — asıl durum
        // güncellemesi webhook'tan geldiğinden bu adres yalnız bilgilendirme
        // amaçlı, güvene dayalı bir onay DEĞİL.
        callbackUrl: 'https://ercinnn.github.io/nicepos/#/online-satis',
      );
      final url = result.paymentPageUrl;
      if (url != null) {
        await launchUrl(Uri.parse(url), webOnlyWindowName: '_blank');
      }
      widget.onInitiated(result.purchaseId);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1.25 = %25 hizmet bedeli (v1 kararı) — yalnız ÖN İZLEME amaçlı, gerçek
    // tahsilat sunucu tarafında hesaplanır (bkz. supabase/functions/_shared/
    // iyzico.ts SERVICE_FEE_MULTIPLIER — oran değişirse ORADA da güncellenmeli).
    final total = widget.candidate.priceAmount * 1.25;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.candidate.domain,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Toplam: ${total.toStringAsFixed(2)} ${widget.candidate.priceCurrency}/yıl'
          ' (hizmet bedeli dahil)',
          style: const TextStyle(color: AppColors.textMuted),
        ),
        const SizedBox(height: 16),
        if (_error != null) ...[
          Text(_error!, style: const TextStyle(color: AppColors.danger)),
          const SizedBox(height: 12),
        ],
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton(
            onPressed: _loading ? null : _pay,
            child: _loading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Öde ve Satın Al'),
          ),
        ),
      ],
    );
  }
}
