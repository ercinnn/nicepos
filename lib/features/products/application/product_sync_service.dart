import 'dart:async';
import 'dart:io';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/connectivity/connectivity_status_service.dart';
import '../data/local/pending_change_dao.dart';
import '../data/local/product_local_cache_dao.dart';
import '../data/local/reference_cache_dao.dart';
import '../data/models/pending_change.dart';
import '../data/repositories/product_repository.dart';
import 'products_provider.dart';
import 'sync_status.dart';

part 'product_sync_service.g.dart';

/// Mobil çevrimdışı ürün ekleme/düzenleme — senkron motoru. Yalnız native/
/// Android'de anlamlıdır (çağıran taraflar `!kIsWeb` ile korur); web'de bu
/// servis hiç tetiklenmez.
///
/// Reachability probe/periyodik timer/connectivity dinleyicisi ARTIK burada
/// DEĞİL — paylaşılan `ConnectivityStatusService`'te (bkz. o dosyanın
/// açıklaması). Bu servis yalnız `registerDependent` ile kaydolur; `syncNow()`
/// SADECE bağlantı doğrulandıktan SONRA (`ConnectivityStatusService.
/// probeAndNotify()` tarafından) çağrılır — kendi prob'unu AÇMAZ.
@Riverpod(keepAlive: true)
class ProductSyncService extends _$ProductSyncService {
  static const _depKey = 'products';
  bool _isSyncing = false;

  @override
  SyncStatus build() {
    final connectivity = ref.read(connectivityStatusServiceProvider.notifier);
    connectivity.registerDependent(_depKey, syncNow);
    ref.onDispose(() => connectivity.unregisterDependent(_depKey));

    // Paylaşılan servis offline'a düşerse rozet hemen yansıtsın (syncing
    // ortasında değilsek) — `syncNow()` zaten kendi phase'ini yönetir,
    // burada yalnız "henüz hiç syncNow çağrılmadan" durumunu yakalarız.
    // `fireImmediately: true` ŞART: `ConnectivityStatusService`in soğuk
    // açılışta SharedPreferences'tan geri yüklediği "offline" ipucu bu
    // servis kaydolmadan ÖNCE zaten uygulanmış olabilir — yalnız gelecekteki
    // değişiklikleri dinlemek bu durumda kaçırır.
    ref.listen(connectivityStatusServiceProvider, (prev, next) {
      if (next.phase == ConnectivityPhase.offline && state.phase != SyncPhase.syncing) {
        state = state.copyWith(phase: SyncPhase.offline);
      }
    }, fireImmediately: true);

    // Önceki oturumdan kalan bekleyen kayıtlar varsa rozet açılışta doğru
    // sayıyı göstersin diye (henüz sync denemeden).
    _refreshCounts();
    return const SyncStatus();
  }

  Future<void> _refreshCounts() async {
    final all = await ref.read(pendingChangeDaoProvider).fetchAll();
    final pendingCount = all.where((c) => c.status != PendingChangeStatus.failed).length;
    final failedCount = all.where((c) => c.status == PendingChangeStatus.failed).length;
    state = state.copyWith(pendingCount: pendingCount, failedCount: failedCount);
    ref.read(connectivityStatusServiceProvider.notifier).setInterested(_depKey, pendingCount + failedCount > 0);
  }

  /// `product_form_screen.dart` bir ürünü offline kuyruğa aldığında çağırır —
  /// rozeti hemen günceller, sonra paylaşılan servisten TEK bir prob ister
  /// (online ise ürün+satış kuyrukları BİRLİKTE tetiklenir).
  Future<void> notifyLocalQueueChanged() async {
    await _refreshCounts();
    unawaited(ref.read(connectivityStatusServiceProvider.notifier).probeAndNotify());
  }

  String _friendlyError(PostgrestException e) {
    if (e.code == '23505') return 'Bu barkod başka bir üründe kayıtlı.';
    return e.message;
  }

  /// YALNIZ `ConnectivityStatusService.probeAndNotify()` (bağlantı zaten
  /// doğrulanmış) tarafından çağrılır. "Şimdi Senkronize Et" butonu da artık
  /// doğrudan bunu değil, paylaşılan servisin `probeAndNotify()`'ını çağırır
  /// (bkz. `sync_status_badge.dart`/`pending_changes_sheet.dart`).
  Future<void> syncNow() async {
    if (_isSyncing) return;
    _isSyncing = true;
    try {
      state = state.copyWith(phase: SyncPhase.syncing);

      final pendingDao = ref.read(pendingChangeDaoProvider);
      final cacheDao = ref.read(productLocalCacheDaoProvider);
      final repo = ref.read(productRepositoryProvider);

      final pending = await pendingDao.fetchPending();
      var connectionLostMidCycle = false;
      var syncedCount = 0;
      // Sınırlı eşzamanlılık: tek tek değil küçük gruplar halinde işlenir —
      // her satır bağımsız (farklı product_id PK), sunucu yazımları arasında
      // çakışma yok, bağlantı dönüşünde çok sayıda bekleyen varken toplam
      // senkron süresi belirgin kısalır.
      const chunkSize = 4;
      for (var i = 0; i < pending.length && !connectionLostMidCycle; i += chunkSize) {
        final chunk = pending.skip(i).take(chunkSize);
        final outcomes = await Future.wait(chunk.map(
            (change) => _processOne(change, repo: repo, pendingDao: pendingDao, cacheDao: cacheDao)));
        for (final outcome in outcomes) {
          if (outcome == _ItemOutcome.synced) syncedCount++;
          if (outcome == _ItemOutcome.connectionLost) connectionLostMidCycle = true;
        }
      }

      if (!connectionLostMidCycle) {
        try {
          final products = await repo.fetchAll();
          await cacheDao.replaceAll(products);
          final groups = await ref.read(productGroupRepositoryProvider).fetchAll();
          await ref.read(referenceCacheDaoProvider).replaceGroups(groups);
          final companies = await ref.read(companyRepositoryProvider).fetchAll();
          await ref.read(referenceCacheDaoProvider).replaceCompanies(companies);
        } catch (_) {
          // Katalog çekme ikincil — kuyruk zaten işlendi, sessizce yoksay,
          // bir sonraki döngüde tekrar denenir.
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
    PendingChange change, {
    required ProductRepository repo,
    required PendingChangeDao pendingDao,
    required ProductLocalCacheDao cacheDao,
  }) async {
    final product = change.toProduct();
    try {
      if (change.operation == PendingChangeOperation.create) {
        await repo.createWithId(product);
        // Sunucu yazımı başarılı oldu — görsel adımı sonra patlarsa bile bir
        // sonraki deneme aynı id ile TEKRAR `createWithId` çağırmasın diye
        // operasyon hemen 'update'ye çevrilir (idempotency).
        await pendingDao.promoteToUpdate(product.id);
      } else {
        await repo.update(product.id, product);
      }
    } on PostgrestException catch (e) {
      // Sunucu YANIT VERDİ — gerçek red (ör. barkod çakışması). Bağlantı
      // sorunu değil, kuyruğun geri kalanı etkilenmemeli.
      await pendingDao.markFailed(change.productId, _friendlyError(e));
      return _ItemOutcome.retryLater;
    } catch (_) {
      // Sunucu hiç yanıt vermedi — bağlantı sync ortasında koptu, kalan
      // satırlara dokunma.
      return _ItemOutcome.connectionLost;
    }

    final imagePath = change.pendingImagePath;
    if (imagePath == null) {
      await pendingDao.markSynced(product.id);
      await cacheDao.markSynced(product);
      return _ItemOutcome.synced;
    }

    try {
      final file = File(imagePath);
      final bytes = await file.readAsBytes();
      final ext = imagePath.contains('.') ? imagePath.split('.').last : 'jpg';
      final url = await repo.uploadImage(product.id, bytes, ext);
      final withImage = product.copyWith(imageUrl: url);
      await repo.update(product.id, withImage);
      await pendingDao.markSynced(product.id);
      await cacheDao.markSynced(withImage);
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Çekirdek satır zaten sunucuda; yalnız görsel adımı başarısız oldu —
      // satır `pending_image_path` ile birlikte kuyrukta kalır, bir sonraki
      // döngü yalnız görseli tekrar dener (çekirdek `update` idempotent).
      await cacheDao.markSynced(product);
      await pendingDao.keepForImageRetry(product.id);
      return _ItemOutcome.retryLater;
    }
    return _ItemOutcome.synced;
  }
}

enum _ItemOutcome { synced, retryLater, connectionLost }

/// "Bekleyen Senkronizasyonlar" sheet'i için — `productSyncServiceProvider`'ı
/// da izler ki bir sync döngüsü bittiğinde liste otomatik tazelensin.
@riverpod
Future<List<PendingChange>> pendingChangesList(PendingChangesListRef ref) {
  ref.watch(productSyncServiceProvider);
  return ref.watch(pendingChangeDaoProvider).fetchAll();
}
