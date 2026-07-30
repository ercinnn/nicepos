import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
/// `connectivity_plus` TEK BAŞINA yeterli değildir — cihaz Wi-Fi'ye "bağlı"
/// görünüp gerçek internete ulaşamayabilir (dükkanın dead-zone sorunu tam
/// olarak bu). Bu yüzden her tetikleyici gerçek bir Supabase round-trip
/// ("reachability probe") ile doğrulanır; `connectivity_plus` yalnızca
/// "ne zaman tekrar dene" sinyali olarak kullanılır. Aynı ağda sinyal gücü
/// değişimiyle dead-zone'dan normale geçişte arayüz durumu HİÇ değişmediği
/// için (`connectivity_plus` event üretmez), bekleyen kayıt varken periyodik
/// bir prob da çalışır — gerçek kurtarma mekanizması budur.
@Riverpod(keepAlive: true)
class ProductSyncService extends _$ProductSyncService {
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  Timer? _periodicTimer;
  Timer? _debounceTimer;
  bool _isSyncing = false;

  @override
  SyncStatus build() {
    _connectivitySub = Connectivity().onConnectivityChanged.listen((_) => _onConnectivityChanged());
    ref.onDispose(() {
      _connectivitySub?.cancel();
      _periodicTimer?.cancel();
      _debounceTimer?.cancel();
    });
    // Önceki oturumdan kalan bekleyen kayıtlar varsa rozet açılışta doğru
    // sayıyı göstersin diye (henüz sync denemeden).
    _refreshCounts();
    return const SyncStatus();
  }

  void _onConnectivityChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 2), syncNow);
  }

  void _ensurePeriodicTimer() {
    _periodicTimer ??= Timer.periodic(const Duration(seconds: 25), (_) => syncNow());
  }

  void _cancelPeriodicTimer() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
  }

  Future<void> _refreshCounts() async {
    final all = await ref.read(pendingChangeDaoProvider).fetchAll();
    final pendingCount = all.where((c) => c.status != PendingChangeStatus.failed).length;
    final failedCount = all.where((c) => c.status == PendingChangeStatus.failed).length;
    state = state.copyWith(pendingCount: pendingCount, failedCount: failedCount);
    if (pendingCount + failedCount > 0) {
      _ensurePeriodicTimer();
    } else {
      _cancelPeriodicTimer();
    }
  }

  /// `product_form_screen.dart` bir ürünü offline kuyruğa aldığında çağırır —
  /// rozeti hemen günceller, periyodik prob'u başlatır ve (belki bağlantı
  /// aslında vardır diye) bir deneme daha yapar.
  Future<void> notifyLocalQueueChanged() async {
    await _refreshCounts();
    unawaited(syncNow());
  }

  Future<bool> _probeReachable() async {
    try {
      await Supabase.instance.client
          .from('products')
          .select('id')
          .limit(1)
          .timeout(const Duration(seconds: 4));
      return true;
    } catch (_) {
      return false;
    }
  }

  String _friendlyError(PostgrestException e) {
    if (e.code == '23505') return 'Bu barkod başka bir üründe kayıtlı.';
    return e.message;
  }

  /// Elle "Şimdi Senkronize Et" ve tüm otomatik tetikleyiciler buraya akar.
  Future<void> syncNow() async {
    if (_isSyncing) return;
    _isSyncing = true;
    try {
      final reachable = await _probeReachable();
      if (!reachable) {
        state = state.copyWith(phase: SyncPhase.offline);
        return;
      }
      state = state.copyWith(phase: SyncPhase.syncing);

      final pendingDao = ref.read(pendingChangeDaoProvider);
      final cacheDao = ref.read(productLocalCacheDaoProvider);
      final repo = ref.read(productRepositoryProvider);

      final pending = await pendingDao.fetchPending();
      var connectionLostMidCycle = false;
      var syncedCount = 0;
      for (final change in pending) {
        final outcome = await _processOne(change, repo: repo, pendingDao: pendingDao, cacheDao: cacheDao);
        if (outcome == _ItemOutcome.synced) syncedCount++;
        if (outcome == _ItemOutcome.connectionLost) {
          connectionLostMidCycle = true;
          break;
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

/// `synced` = satır tamamen bitti (kuyruktan silindi); `retryLater` = kalıcı
/// red (PostgrestException) VEYA yalnız görsel adımı başarısız olup satır
/// bir sonraki döngü için kuyrukta kaldı; `connectionLost` = bağlantı
/// ortasında koptu, döngü hemen durur.
enum _ItemOutcome { synced, retryLater, connectionLost }

/// "Bekleyen Senkronizasyonlar" sheet'i için — `productSyncServiceProvider`'ı
/// da izler ki bir sync döngüsü bittiğinde liste otomatik tazelensin.
@riverpod
Future<List<PendingChange>> pendingChangesList(PendingChangesListRef ref) {
  ref.watch(productSyncServiceProvider);
  return ref.watch(pendingChangeDaoProvider).fetchAll();
}
