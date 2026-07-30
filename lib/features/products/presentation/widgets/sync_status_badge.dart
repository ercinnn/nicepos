import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/connectivity/connectivity_status_service.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../products/application/product_sync_service.dart';
import '../../../products/application/sync_status.dart';
import '../../../sales/application/sale_sync_service.dart';
import 'pending_changes_sheet.dart';

/// Mobil çevrimdışı ürün+satış senkronu — TEK birleşik durum rozeti + elle
/// "Şimdi Senkronize Et" butonu (`ProductSyncService` + `SaleSyncService`
/// sayaçları/fazları birleştirilir — iki ayrı rozet yerine tek tutarlı
/// yüzey, bkz. plan notu). `AppScaffold`'da hem masaüstü-genişlik `_TopBar`
/// hem mobil `AppBar.actions`'a eklenir (`!kIsWeb` guard çağıran tarafta),
/// böylece bir Android tablet yatayda "masaüstü" görünümü render etse bile
/// senkron desteğini kaybetmez (bkz. plan notu — `context.isMobile` DEĞİL
/// yalnız `!kIsWeb` guard).
class SyncStatusBadge extends ConsumerWidget {
  const SyncStatusBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productStatus = ref.watch(productSyncServiceProvider);
    final saleStatus = ref.watch(saleSyncServiceProvider);
    final total = productStatus.pendingCount +
        productStatus.failedCount +
        saleStatus.pendingCount +
        saleStatus.failedCount;
    final syncing = productStatus.phase == SyncPhase.syncing || saleStatus.phase == SyncPhase.syncing;
    final offline = productStatus.phase == SyncPhase.offline || saleStatus.phase == SyncPhase.offline;

    final (IconData icon, Color color) = syncing
        ? (Icons.cloud_sync_outlined, AppColors.textSecondary)
        : offline
            ? (Icons.cloud_off_outlined, AppColors.danger)
            : total > 0
                ? (Icons.cloud_upload_outlined, AppColors.textSecondary)
                : (Icons.cloud_done_outlined, AppColors.success);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Bekleyen Senkronizasyonlar',
          icon: Badge(
            label: Text('$total'),
            isLabelVisible: total > 0,
            child: Icon(icon, color: color),
          ),
          onPressed: () => showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            builder: (_) => const PendingChangesSheet(),
          ),
        ),
        IconButton(
          tooltip: 'Şimdi Senkronize Et',
          icon: syncing
              ? const SizedBox(
                  width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.sync),
          onPressed: syncing
              ? null
              : () async {
                  // Paylaşılan servis TEK prob yapar, online ise ürün+satış
                  // kuyrukları BİRLİKTE tetiklenir (bkz. connectivity_status_service.dart).
                  await ref.read(connectivityStatusServiceProvider.notifier).probeAndNotify();
                  if (!context.mounted) return;
                  if (ref.read(connectivityStatusServiceProvider).phase == ConnectivityPhase.offline) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(const SnackBar(content: Text('Hâlâ bağlantı yok.')));
                  }
                },
        ),
      ],
    );
  }
}
