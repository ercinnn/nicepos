import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../application/product_sync_service.dart';
import '../../application/sync_status.dart';
import 'pending_changes_sheet.dart';

/// Mobil çevrimdışı ürün ekleme/düzenleme — senkron durum rozeti + elle
/// "Şimdi Senkronize Et" butonu. `AppScaffold`'da hem masaüstü-genişlik
/// `_TopBar` hem mobil `AppBar.actions`'a eklenir (`!kIsWeb` guard çağıran
/// tarafta), böylece bir Android tablet yatayda "masaüstü" görünümü render
/// etse bile senkron desteğini kaybetmez (bkz. plan notu — `context.isMobile`
/// DEĞİL yalnız `!kIsWeb` guard).
class SyncStatusBadge extends ConsumerWidget {
  const SyncStatusBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(productSyncServiceProvider);
    final total = status.pendingCount + status.failedCount;

    final (IconData icon, Color color) = switch (status.phase) {
      SyncPhase.syncing => (Icons.cloud_sync_outlined, AppColors.textSecondary),
      SyncPhase.offline => (Icons.cloud_off_outlined, AppColors.danger),
      SyncPhase.idle => total > 0
          ? (Icons.cloud_upload_outlined, AppColors.textSecondary)
          : (Icons.cloud_done_outlined, AppColors.success),
    };

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
          icon: status.phase == SyncPhase.syncing
              ? const SizedBox(
                  width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.sync),
          onPressed: status.phase == SyncPhase.syncing
              ? null
              : () async {
                  await ref.read(productSyncServiceProvider.notifier).syncNow();
                  if (!context.mounted) return;
                  if (ref.read(productSyncServiceProvider).phase == SyncPhase.offline) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(const SnackBar(content: Text('Hâlâ bağlantı yok.')));
                  }
                },
        ),
      ],
    );
  }
}
