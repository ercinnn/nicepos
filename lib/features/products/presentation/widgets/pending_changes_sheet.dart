import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../application/product_sync_service.dart';
import '../../data/local/pending_change_dao.dart';
import '../../data/local/product_local_cache_dao.dart';
import '../../data/models/pending_change.dart';

/// "Bekleyen Senkronizasyonlar" — `SyncStatusBadge`'e dokununca açılır.
/// Her satır: ürün adı/barkod, işlem türü, hata (varsa) + "Yeniden Dene"/"At".
class PendingChangesSheet extends ConsumerWidget {
  const PendingChangesSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncList = ref.watch(pendingChangesListProvider);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('Bekleyen Senkronizasyonlar',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                TextButton.icon(
                  onPressed: () => ref.read(productSyncServiceProvider.notifier).syncNow(),
                  icon: const Icon(Icons.sync, size: 18),
                  label: const Text('Şimdi Senkronize Et'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Flexible(
              child: asyncList.when(
                data: (items) {
                  if (items.isEmpty) {
                    // Son senkron zamanı gösterilir ki kullanıcı listenin
                    // BOŞ olmasının "kayboldu" değil "zaten senkronize
                    // oldu" anlamına geldiğini anlasın (bkz. plan notu —
                    // arka planda sessizce tamamlanan senkron toast'ı
                    // kaybolduktan sonra bile burası kanıt sağlar).
                    final lastSuccessAt = ref.watch(productSyncServiceProvider).lastSuccessAt;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Column(
                        children: [
                          const Text('Bekleyen kayıt yok.', style: TextStyle(color: AppColors.textMuted)),
                          if (lastSuccessAt != null) ...[
                            const SizedBox(height: 4),
                            Text('Son senkron: ${formatDateTime(lastSuccessAt)}',
                                style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                          ],
                        ],
                      ),
                    );
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, i) => _PendingChangeTile(change: items[i]),
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text('Yüklenemedi: $e', style: const TextStyle(color: AppColors.danger)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PendingChangeTile extends ConsumerWidget {
  final PendingChange change;

  const _PendingChangeTile({required this.change});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final product = change.toProduct();
    final isFailed = change.status == PendingChangeStatus.failed;
    final subtitleParts = [
      product.barcode ?? 'Barkodsuz',
      change.operation == PendingChangeOperation.create ? 'Yeni ürün' : 'Güncelleme',
      if (isFailed && change.lastError != null) change.lastError!,
    ];
    return ListTile(
      title: Text(product.name.isEmpty ? '(isimsiz)' : product.name),
      subtitle: Text(
        subtitleParts.join(' · '),
        style: TextStyle(color: isFailed ? AppColors.danger : AppColors.textSecondary, fontSize: 12),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isFailed)
            IconButton(
              tooltip: 'Yeniden Dene',
              icon: const Icon(Icons.refresh, size: 20),
              onPressed: () async {
                await ref.read(pendingChangeDaoProvider).retry(change.productId);
                ref.invalidate(pendingChangesListProvider);
                unawaited(ref.read(productSyncServiceProvider.notifier).syncNow());
              },
            ),
          IconButton(
            tooltip: 'At',
            icon: const Icon(Icons.delete_outline, size: 20),
            onPressed: () => _confirmDiscard(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDiscard(BuildContext context, WidgetRef ref) async {
    final isCreate = change.operation == PendingChangeOperation.create;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Değişikliği At'),
        content: Text(isCreate
            ? 'Bu ürün hiç kaydedilmedi, atarsanız tamamen silinecek.'
            : 'Bu değişiklik atılacak, ürünün sunucudaki hâli korunacak.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Vazgeç')),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('At'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(pendingChangeDaoProvider).discard(change.productId);
    if (isCreate) {
      await ref.read(productLocalCacheDaoProvider).deleteById(change.productId);
    } else {
      await ref.read(productLocalCacheDaoProvider).markSyncStateSyncedById(change.productId);
    }
    ref.invalidate(pendingChangesListProvider);
    await ref.read(productSyncServiceProvider.notifier).notifyLocalQueueChanged();
  }
}
