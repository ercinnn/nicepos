import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/connectivity/connectivity_status_service.dart';
import '../../products/application/sync_status.dart';
import '../data/local/pending_sale_dao.dart';
import '../data/models/pending_sale.dart';
import '../data/repositories/sales_repository.dart';
import 'sales_cart_notifier.dart';

part 'sale_sync_service.g.dart';

/// Mobil çevrimdışı Nakit/POS satış — senkron motoru. `ProductSyncService`
/// ile birebir aynı iskelet (`SyncStatus` tipini AYNEN paylaşır); reachability
/// probe/periyodik timer KENDİSİNDE DEĞİL, paylaşılan `ConnectivityStatusService`'te
/// — bu servis yalnız `registerDependent` ile kaydolur, `syncNow()` SADECE
/// bağlantı doğrulandıktan SONRA çağrılır.
///
/// Her bekleyen satış `SalesRepository.completeSaleOffline()` ile TEK atomik
/// RPC çağrısıyla gönderilir (bkz. 0027_complete_sale_offline.sql) — kısmi
/// yazım riski yok, id bazlı idempotency retry'ı güvenli kılar.
@Riverpod(keepAlive: true)
class SaleSyncService extends _$SaleSyncService {
  static const _depKey = 'sales';
  bool _isSyncing = false;

  @override
  SyncStatus build() {
    final connectivity = ref.read(connectivityStatusServiceProvider.notifier);
    connectivity.registerDependent(_depKey, syncNow);
    ref.onDispose(() => connectivity.unregisterDependent(_depKey));

    // `fireImmediately: true` ŞART — bkz. product_sync_service.dart'taki aynı
    // desenin notu (soğuk açılışta SharedPreferences ipucu bu servis
    // kaydolmadan önce zaten uygulanmış olabilir).
    ref.listen(connectivityStatusServiceProvider, (prev, next) {
      if (next.phase == ConnectivityPhase.offline && state.phase != SyncPhase.syncing) {
        state = state.copyWith(phase: SyncPhase.offline);
      }
    }, fireImmediately: true);

    _refreshCounts();
    return const SyncStatus();
  }

  Future<void> _refreshCounts() async {
    final all = await ref.read(pendingSaleDaoProvider).fetchAll();
    final pendingCount = all.where((s) => s.status != PendingSaleStatus.failed).length;
    final failedCount = all.where((s) => s.status == PendingSaleStatus.failed).length;
    state = state.copyWith(pendingCount: pendingCount, failedCount: failedCount);
    ref.read(connectivityStatusServiceProvider.notifier).setInterested(_depKey, pendingCount + failedCount > 0);
  }

  /// `payment_panel.dart` bir satışı offline kuyruğa aldığında çağırır.
  Future<void> notifyLocalQueueChanged() async {
    await _refreshCounts();
    unawaited(ref.read(connectivityStatusServiceProvider.notifier).probeAndNotify());
  }

  String _friendlyError(PostgrestException e) => e.message;

  /// YALNIZ `ConnectivityStatusService.probeAndNotify()` tarafından çağrılır.
  Future<void> syncNow() async {
    if (_isSyncing) return;
    _isSyncing = true;
    try {
      state = state.copyWith(phase: SyncPhase.syncing);

      final pendingDao = ref.read(pendingSaleDaoProvider);
      final repo = ref.read(salesRepositoryProvider);

      final pending = await pendingDao.fetchPending();
      var connectionLostMidCycle = false;
      var syncedCount = 0;
      // Sınırlı eşzamanlılık: her satış tek bir atomik RPC çağrısı, farklı
      // id'ler üzerinde bağımsız — paralel çağrı güvenli.
      const chunkSize = 4;
      for (var i = 0; i < pending.length && !connectionLostMidCycle; i += chunkSize) {
        final chunk = pending.skip(i).take(chunkSize);
        final outcomes = await Future.wait(chunk.map((sale) => _processOne(sale, repo: repo, pendingDao: pendingDao)));
        for (final outcome in outcomes) {
          if (outcome == _ItemOutcome.synced) syncedCount++;
          if (outcome == _ItemOutcome.connectionLost) connectionLostMidCycle = true;
        }
      }

      await _refreshCounts();
      state = state.copyWith(
        phase: connectionLostMidCycle ? SyncPhase.offline : SyncPhase.idle,
        lastSuccessAt: connectionLostMidCycle ? state.lastSuccessAt : DateTime.now(),
        lastSyncedCount: syncedCount,
      );
    } finally {
      _isSyncing = false;
    }
  }

  Future<_ItemOutcome> _processOne(
    PendingSale sale, {
    required SalesRepository repo,
    required PendingSaleDao pendingDao,
  }) async {
    final payload = sale.payload;
    try {
      final saleCode = await repo.generateSaleCode();
      await repo.completeSaleOffline(
        id: sale.id,
        saleCode: saleCode,
        items: payload.items,
        discountPercent: payload.discountPercent,
        totalAmount: payload.totalAmount,
        paidAmount: payload.paidAmount,
        paymentType: payload.paymentType,
        cashAmount: payload.cashAmount,
        cardAmount: payload.cardAmount,
        saleDate: sale.createdAt,
        customerId: payload.customerId,
        personnel: payload.personnel,
        note: payload.note,
      );
    } on PostgrestException catch (e) {
      await pendingDao.markFailed(sale.id, _friendlyError(e));
      return _ItemOutcome.retryLater;
    } catch (_) {
      return _ItemOutcome.connectionLost;
    }

    await pendingDao.markSynced(sale.id);
    return _ItemOutcome.synced;
  }
}

enum _ItemOutcome { synced, retryLater, connectionLost }

/// "Bekleyen Senkronizasyonlar" sheet'i için — `saleSyncServiceProvider`'ı
/// da izler ki bir sync döngüsü bittiğinde liste otomatik tazelensin.
@riverpod
Future<List<PendingSale>> pendingSalesList(PendingSalesListRef ref) {
  ref.watch(saleSyncServiceProvider);
  return ref.watch(pendingSaleDaoProvider).fetchAll();
}
