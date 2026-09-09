import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../../data/domain_purchase_repository.dart';
import '../../../data/models/domain_models.dart';

// Satın alma sonrası durum izleme — bu depoda Supabase Realtime hiç
// kullanılmıyor (v1'de yeni bir desen açmamak için basit `Timer`-tabanlı
// polling tercih edildi, bkz. plan §4). `domain_purchases` satırı
// webhook/cron tarafından güncellenirken burada 3sn'de bir okunur.
class DomainStatusTracker extends StatefulWidget {
  final String purchaseId;
  final VoidCallback onDone;

  const DomainStatusTracker({
    super.key,
    required this.purchaseId,
    required this.onDone,
  });

  @override
  State<DomainStatusTracker> createState() => _DomainStatusTrackerState();
}

const _statusLabels = {
  'payment_pending': 'Ödeme bekleniyor',
  'paid': 'Ödeme alındı',
  'registering': 'Domain kaydediliyor',
  'registered': 'Domain kaydedildi',
  'connecting_dns': 'Mağazanıza bağlanıyor',
  'connected': 'Bağlandı',
  'failed': 'Bir sorun oluştu',
};

class _DomainStatusTrackerState extends State<DomainStatusTracker> {
  final _repository = DomainPurchaseRepository();
  Timer? _timer;
  DomainPurchase? _purchase;
  String? _error;

  @override
  void initState() {
    super.initState();
    _poll();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _poll());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _poll() async {
    try {
      final purchase = await _repository.fetchPurchase(widget.purchaseId);
      if (!mounted) return;
      setState(() => _purchase = purchase);
      if (purchase != null && purchase.isTerminal) {
        _timer?.cancel();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final purchase = _purchase;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Satın Alma Durumu',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        if (_error != null)
          Text(_error!, style: const TextStyle(color: AppColors.danger))
        else if (purchase == null)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else ...[
          Row(
            children: [
              if (purchase.status == 'connected')
                const Icon(Icons.check_circle, color: AppColors.success)
              else if (purchase.status == 'failed')
                const Icon(Icons.error, color: AppColors.danger)
              else
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              const SizedBox(width: 10),
              Text(
                _statusLabels[purchase.status] ?? purchase.status,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          if (purchase.status == 'failed') ...[
            const SizedBox(height: 12),
            const Text(
              'Bir sorun oluştu. Kısa süre içinde sizinle iletişime geçeceğiz.',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ],
          if (purchase.status == 'connected') ...[
            const SizedBox(height: 12),
            Text(
              '${purchase.domain} artık mağazanıza bağlı.',
              style: const TextStyle(color: AppColors.textMuted),
            ),
          ],
          const SizedBox(height: 20),
          if (purchase.isTerminal)
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: widget.onDone,
                child: const Text('Kapat'),
              ),
            ),
        ],
      ],
    );
  }
}
