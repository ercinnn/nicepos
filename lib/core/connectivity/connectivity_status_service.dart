import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'connectivity_status_service.g.dart';

enum ConnectivityPhase {
  /// Uygulama açılışında henüz hiç prob yapılmadı — "sanki online" gibi
  /// davranılır (mevcut ağ çağrıları normal denenir), yalnız `unknown`
  /// iken _kOfflinePrefKey'den gelen kalıcı ipucu bunu geçici olarak
  /// `offline`'a çevirebilir (bkz. `_restoreCachedPhase`).
  unknown,
  online,
  offline,
}

class ConnectivityStatus {
  final ConnectivityPhase phase;
  final DateTime? lastCheckedAt;

  const ConnectivityStatus({this.phase = ConnectivityPhase.unknown, this.lastCheckedAt});

  ConnectivityStatus copyWith({ConnectivityPhase? phase, DateTime? lastCheckedAt}) {
    return ConnectivityStatus(
      phase: phase ?? this.phase,
      lastCheckedAt: lastCheckedAt ?? this.lastCheckedAt,
    );
  }
}

const _kCachedPhaseKey = 'connectivity_status_last_phase';

/// Mobil çevrimdışı senkronun PAYLAŞILAN bağlantı tespiti — `ProductSyncService`
/// ve `SaleSyncService`'in her biri KENDİ reachability probe'unu AÇMAZ, ikisi
/// de bu servisi tüketir. Yalnız native/Android'de anlamlıdır (çağıran
/// taraflar `!kIsWeb` ile korur).
///
/// `connectivity_plus` TEK BAŞINA yeterli değildir (dead-zone sorunu, bkz.
/// CLAUDE.md) — her tetikleyici gerçek bir Supabase round-trip ile doğrulanır.
/// Tek fark önceki tasarımdan: prob artık TEK bir yerde yapılır ve sonucu
/// KAYITLI tüm bağımlılara (`registerDependent`) birlikte dağıtılır — bağlantı
/// geldiği an ürün+satış kuyrukları AYRI AYRI gecikmeli değil, BİRLİKTE/anında
/// boşalır.
@Riverpod(keepAlive: true)
class ConnectivityStatusService extends _$ConnectivityStatusService {
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  Timer? _periodicTimer;
  Timer? _debounceTimer;
  Future<bool>? _inFlightProbe;

  /// Bekleyen kuyruğu olan senkron motorları burada kayıtlıdır (ör. 'products',
  /// 'sales') — periyodik prob yalnız EN AZ BİR bağımlı "ilgileniyorum"
  /// dediğinde çalışır (boş kuyrukta gereksiz ağ trafiği yapılmaz).
  final Set<String> _interestedKeys = {};

  /// Prob online döndüğünde birlikte tetiklenecek senkron callback'leri.
  final Map<String, Future<void> Function()> _dependents = {};

  @override
  ConnectivityStatus build() {
    _connectivitySub = Connectivity().onConnectivityChanged.listen((_) => _onConnectivityChanged());
    ref.onDispose(() {
      _connectivitySub?.cancel();
      _periodicTimer?.cancel();
      _debounceTimer?.cancel();
    });
    unawaited(_restoreCachedPhase());
    return const ConnectivityStatus();
  }

  /// Soğuk açılışta önceki oturumdan kalan "offline" ipucunu uygular —
  /// gerçek prob henüz dönmediyse (`phase` hâlâ `unknown`) ilk ekranın
  /// 6sn'lik ağ timeout'unu beklemesini önler. Prob sonucu geldiğinde
  /// (ör. `AppScaffold` açılışta tetiklediği ilk senkron denemesiyle)
  /// gerçek değer bunun üzerine yazılır.
  Future<void> _restoreCachedPhase() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_kCachedPhaseKey);
      if (cached == 'offline' && state.phase == ConnectivityPhase.unknown) {
        state = state.copyWith(phase: ConnectivityPhase.offline);
      }
    } catch (_) {
      // SharedPreferences'a erişilemezse sessizce geç — yalnız bir hız
      // optimizasyonu, davranışı bozmaz.
    }
  }

  Future<void> _persistPhase(ConnectivityPhase phase) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kCachedPhaseKey, phase == ConnectivityPhase.offline ? 'offline' : 'online');
    } catch (_) {
      // Kalıcılık ikincil — başarısız olursa yalnız bir sonraki soğuk açılış
      // optimizasyonu kaybedilir, işlevsellik etkilenmez.
    }
  }

  /// `ProductSyncService`/`SaleSyncService` `build()`'lerinde çağırır —
  /// prob online döndüğünde birlikte tetiklenecek senkron fonksiyonunu kaydeder.
  void registerDependent(String key, Future<void> Function() onReachable) {
    _dependents[key] = onReachable;
  }

  void unregisterDependent(String key) {
    _dependents.remove(key);
    _interestedKeys.remove(key);
    if (_interestedKeys.isEmpty) _cancelPeriodicTimer();
  }

  /// Bir bağımlının bekleyen kaydı olup olmadığını bildirir — periyodik prob
  /// yalnız en az bir bağımlı ilgileniyorken çalışır.
  void setInterested(String key, bool interested) {
    if (interested) {
      _interestedKeys.add(key);
      _ensurePeriodicTimer();
    } else {
      _interestedKeys.remove(key);
      if (_interestedKeys.isEmpty) _cancelPeriodicTimer();
    }
  }

  void _onConnectivityChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 2), probeAndNotify);
  }

  void _ensurePeriodicTimer() {
    _periodicTimer ??= Timer.periodic(const Duration(seconds: 25), (_) => probeAndNotify());
  }

  void _cancelPeriodicTimer() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
  }

  /// Tek bir reachability prob'u — eşzamanlı çağrılar (ör. ürün VE satış
  /// senkronu aynı anda `notifyLocalQueueChanged` tetiklerse) AYNI in-flight
  /// future'ı paylaşır, ikinci bir ağ turu açılmaz. Probe timeout'u yalnız
  /// "bir bayt döndü mü" kanıtlamak için 2sn (yazma işlemlerinin 6sn'lik
  /// `kNetworkOpTimeout`'undan kasıtlı kısa, bkz. design notu).
  Future<bool> probeNow() {
    return _inFlightProbe ??= _doProbe().whenComplete(() => _inFlightProbe = null);
  }

  Future<bool> _doProbe() async {
    bool reachable;
    try {
      await Supabase.instance.client
          .from('products')
          .select('id')
          .limit(1)
          .timeout(const Duration(seconds: 2));
      reachable = true;
    } catch (_) {
      reachable = false;
    }
    state = ConnectivityStatus(
      phase: reachable ? ConnectivityPhase.online : ConnectivityPhase.offline,
      lastCheckedAt: DateTime.now(),
    );
    unawaited(_persistPhase(state.phase));
    return reachable;
  }

  /// Periyodik timer, connectivity-changed dinleyicisi VE elle "Şimdi
  /// Senkronize Et" hepsi buraya akar: tek prob yapar, online ise KAYITLI
  /// TÜM bağımlıları (ürün+satış) BİRLİKTE tetikler.
  Future<void> probeAndNotify() async {
    final reachable = await probeNow();
    if (reachable && _dependents.isNotEmpty) {
      await Future.wait(_dependents.values.map((fn) => fn()));
    }
  }
}
