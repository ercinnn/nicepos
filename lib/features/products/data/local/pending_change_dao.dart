import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sqflite/sqflite.dart';

import '../../../../core/local_db/app_database.dart';
import '../models/pending_change.dart';

part 'pending_change_dao.g.dart';

/// `pending_changes` kuyruğuna erişim. `product_id` PRIMARY KEY — bir ürüne
/// art arda offline yapılan düzenlemeler tek satırın üzerine yazılır.
class PendingChangeDao {
  final AppDatabase _appDb;

  PendingChangeDao(this._appDb);

  Future<void> upsert(PendingChange change) async {
    final db = await _appDb.database;
    await db.insert('pending_changes', change.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Sync döngüsünün işleyeceği satırlar — `syncing` durumundaki hiçbir şey
  /// olmamalı (döngü tek seferde tek instance çalışır, `_isSyncing` koruması
  /// ile), `pending` sırayla işlenir; `failed` satırlar OTOMATİK tekrar
  /// denenmez (kullanıcı "Bekleyenler"den elle "Yeniden Dene" demeli).
  Future<List<PendingChange>> fetchPending() async {
    final db = await _appDb.database;
    final rows = await db.query('pending_changes', where: "status = 'pending'", orderBy: 'created_at ASC');
    return rows.map(PendingChange.fromMap).toList();
  }

  /// "Bekleyen Senkronizasyonlar" sheet'i için — pending + failed hepsi.
  Future<List<PendingChange>> fetchAll() async {
    final db = await _appDb.database;
    final rows = await db.query('pending_changes', orderBy: 'created_at ASC');
    return rows.map(PendingChange.fromMap).toList();
  }

  Future<int> countPendingAndFailed() async {
    final db = await _appDb.database;
    final result = await db.rawQuery(
        "SELECT COUNT(*) AS c FROM pending_changes WHERE status IN ('pending','failed')");
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Bir `create` satırının sunucu yazımı başarılı olduktan hemen sonra
  /// çağrılır (görsel adımı henüz bitmemiş olsa bile) — aksi halde bir
  /// sonraki deneme aynı id ile tekrar `createWithId` çağırıp sunucuda
  /// primary-key ihlaline çarpar.
  Future<void> promoteToUpdate(String productId) async {
    final db = await _appDb.database;
    await db.update(
      'pending_changes',
      {'operation': PendingChangeOperation.update.name, 'updated_at': DateTime.now().toIso8601String()},
      where: 'product_id = ?',
      whereArgs: [productId],
    );
  }

  Future<void> markFailed(String productId, String error) async {
    final db = await _appDb.database;
    await db.rawUpdate(
      "UPDATE pending_changes SET status = 'failed', attempt_count = attempt_count + 1, "
      "last_error = ?, updated_at = ? WHERE product_id = ?",
      [error, DateTime.now().toIso8601String(), productId],
    );
  }

  /// Tam başarı — satır tamamen silinir.
  Future<void> markSynced(String productId) async {
    final db = await _appDb.database;
    await db.delete('pending_changes', where: 'product_id = ?', whereArgs: [productId]);
  }

  /// Yalnız görsel adımı başarısız oldu — çekirdek satır zaten senkron oldu
  /// (`promoteToUpdate` ile `operation='update'`), `pending_image_path` aynı
  /// kalır ki bir sonraki döngü yalnız görseli tekrar dener.
  Future<void> keepForImageRetry(String productId) async {
    final db = await _appDb.database;
    await db.update(
      'pending_changes',
      {'status': PendingChangeStatus.pending.name, 'updated_at': DateTime.now().toIso8601String()},
      where: 'product_id = ?',
      whereArgs: [productId],
    );
  }

  /// "Bekleyenler" sheet'inde kullanıcı "Yeniden Dene" der — `failed` →
  /// `pending`, hata/attempt sıfırlanır ki taze bir şans verilsin.
  Future<void> retry(String productId) async {
    final db = await _appDb.database;
    await db.update(
      'pending_changes',
      {
        'status': PendingChangeStatus.pending.name,
        'last_error': null,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'product_id = ?',
      whereArgs: [productId],
    );
  }

  Future<void> discard(String productId) async {
    final db = await _appDb.database;
    await db.delete('pending_changes', where: 'product_id = ?', whereArgs: [productId]);
  }
}

@Riverpod(keepAlive: true)
PendingChangeDao pendingChangeDao(PendingChangeDaoRef ref) {
  return PendingChangeDao(ref.watch(appDatabaseProvider));
}
