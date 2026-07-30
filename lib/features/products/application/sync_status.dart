enum SyncPhase { idle, syncing, offline }

/// `ProductSyncService`'in UI'ya açtığı durum — `SyncStatusBadge` ve
/// "Bekleyen Senkronizasyonlar" sheet'i bunu izler.
class SyncStatus {
  final SyncPhase phase;
  final int pendingCount;
  final int failedCount;
  final DateTime? lastSuccessAt;

  /// Son `syncNow()` döngüsünde fiilen sunucuya ulaşan (tam `synced`)
  /// kayıt sayısı — arka planda sessizce tamamlanan senkronu kullanıcıya
  /// bildirmek için (bkz. `AppScaffold` toast'ı). Her döngü sonunda AÇIKÇA
  /// yazılır (sıfır dahil), eski değer bir sonraki döngüye sızmaz.
  final int lastSyncedCount;

  const SyncStatus({
    this.phase = SyncPhase.idle,
    this.pendingCount = 0,
    this.failedCount = 0,
    this.lastSuccessAt,
    this.lastSyncedCount = 0,
  });

  SyncStatus copyWith({
    SyncPhase? phase,
    int? pendingCount,
    int? failedCount,
    DateTime? lastSuccessAt,
    int? lastSyncedCount,
  }) {
    return SyncStatus(
      phase: phase ?? this.phase,
      pendingCount: pendingCount ?? this.pendingCount,
      failedCount: failedCount ?? this.failedCount,
      lastSuccessAt: lastSuccessAt ?? this.lastSuccessAt,
      lastSyncedCount: lastSyncedCount ?? this.lastSyncedCount,
    );
  }
}
