import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/connectivity/connectivity_status_service.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../sales/application/sale_sync_service.dart';
import '../../../sales/data/local/pending_sale_dao.dart';
import '../../../sales/data/models/pending_sale.dart';
import '../../../sales/data/models/sale.dart' show PaymentTypeX;
import '../../application/product_sync_service.dart';
import '../../data/local/pending_change_dao.dart';
import '../../data/local/product_local_cache_dao.dart';
import '../../data/models/pending_change.dart';

/// "Bekleyen Senkronizasyonlar" — `SyncStatusBadge`'e dokununca açılır.
/// Hem bekleyen ÜRÜN değişikliklerini (`PendingChange`) hem bekleyen Nakit/POS
/// SATIŞLARI (`PendingSale`) TEK listede, oluşturulma zamanına göre sıralı
/// gösterir — iki ayrı sheet yerine tek tutarlı "bekleyenler" yüzeyi.
class PendingChangesSheet extends ConsumerWidget {
  const PendingChangesSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final changesAsync = ref.watch(pendingChangesListProvider);
    final salesAsync = ref.watch(pendingSalesListProvider);
    final loading = (changesAsync.isLoading && !changesAsync.hasValue) ||
        (salesAsync.isLoading && !salesAsync.hasValue);
    final changes = changesAsync.valueOrNull ?? const <PendingChange>[];
    final sales = salesAsync.valueOrNull ?? const <PendingSale>[];
    final entries = [
      ...changes.map(_PendingEntry.product),
      ...sales.map(_PendingEntry.sale),
    ]..sort((a, b) => a.createdAt.compareTo(b.createdAt));

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
                  onPressed: () => ref.read(connectivityStatusServiceProvider.notifier).probeAndNotify(),
                  icon: const Icon(Icons.sync, size: 18),
                  label: const Text('Şimdi Senkronize Et'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Flexible(
              child: loading
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : entries.isEmpty
                      ? _EmptyState(
                          lastSuccessAt: _latestSuccessAt(
                            ref.watch(productSyncServiceProvider).lastSuccessAt,
                            ref.watch(saleSyncServiceProvider).lastSuccessAt,
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          itemCount: entries.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, i) {
                            final entry = entries[i];
                            return entry.kind == _PendingKind.product
                                ? _PendingChangeTile(change: entry.change!)
                                : _PendingSaleTile(sale: entry.sale!);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  DateTime? _latestSuccessAt(DateTime? a, DateTime? b) {
    if (a == null) return b;
    if (b == null) return a;
    return a.isAfter(b) ? a : b;
  }
}

// Son senkron zamanı gösterilir ki kullanıcı listenin BOŞ olmasının
// "kayboldu" değil "zaten senkronize oldu" anlamına geldiğini anlasın (bkz.
// plan notu — arka planda sessizce tamamlanan senkron toast'ı kaybolduktan
// sonra bile burası kanıt sağlar).
class _EmptyState extends StatelessWidget {
  final DateTime? lastSuccessAt;

  const _EmptyState({required this.lastSuccessAt});

  @override
  Widget build(BuildContext context) {
    final at = lastSuccessAt;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          const Text('Bekleyen kayıt yok.', style: TextStyle(color: AppColors.textMuted)),
          if (at != null) ...[
            const SizedBox(height: 4),
            Text('Son senkron: ${formatDateTime(at)}',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ],
        ],
      ),
    );
  }
}

enum _PendingKind { product, sale }

class _PendingEntry {
  final _PendingKind kind;
  final PendingChange? change;
  final PendingSale? sale;

  const _PendingEntry.product(PendingChange c)
      : kind = _PendingKind.product,
        change = c,
        sale = null;

  const _PendingEntry.sale(PendingSale s)
      : kind = _PendingKind.sale,
        change = null,
        sale = s;

  DateTime get createdAt => kind == _PendingKind.product ? change!.createdAt : sale!.createdAt;
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
      leading: const Icon(Icons.inventory_2_outlined, size: 20, color: AppColors.textMuted),
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
                unawaited(ref.read(connectivityStatusServiceProvider.notifier).probeAndNotify());
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

class _PendingSaleTile extends ConsumerWidget {
  final PendingSale sale;

  const _PendingSaleTile({required this.sale});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payload = sale.payload;
    final isFailed = sale.status == PendingSaleStatus.failed;
    final subtitleParts = [
      '${payload.items.length} kalem',
      formatCurrency(payload.totalAmount),
      payload.paymentType.label,
      if (isFailed && sale.lastError != null) sale.lastError!,
    ];
    return ListTile(
      leading: const Icon(Icons.point_of_sale_outlined, size: 20, color: AppColors.textMuted),
      title: Text(sale.localSaleCode),
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
                await ref.read(pendingSaleDaoProvider).retry(sale.id);
                ref.invalidate(pendingSalesListProvider);
                unawaited(ref.read(connectivityStatusServiceProvider.notifier).probeAndNotify());
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Satışı At'),
        content: Text(
          '"${sale.localSaleCode}" satışı hiç sunucuya gönderilmedi, atarsanız tamamen silinecek '
          '(düşürülen stok geri eklenir). Bu işlem geri alınamaz.',
        ),
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

    // Tamamlama anında optimistik olarak düşürülen yerel stok geri eklenir
    // (bkz. payment_panel.dart `_queueOfflineSale`) — aynı metot negatif
    // miktarla çağrılarak artışa çevrilir.
    final cacheDao = ref.read(productLocalCacheDaoProvider);
    for (final item in sale.payload.items) {
      final productId = item.productId;
      if (productId != null) {
        await cacheDao.decrementStockLocally(productId, -item.quantity);
      }
    }

    await ref.read(pendingSaleDaoProvider).discard(sale.id);
    ref.invalidate(pendingSalesListProvider);
    await ref.read(saleSyncServiceProvider.notifier).notifyLocalQueueChanged();
  }
}
