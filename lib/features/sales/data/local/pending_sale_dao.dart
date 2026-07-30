import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sqflite/sqflite.dart';

import '../../../../core/local_db/app_database.dart';
import '../models/pending_sale.dart';

part 'pending_sale_dao.g.dart';

/// `pending_sales` kuyruğuna erişim — `pending_change_dao.dart` ile aynı
/// desen, TEK fark: APPEND-ONLY (bir satış offline'da tekrar düzenlenmez,
/// her satır kalıcı olarak kendi kimliğiyle kalır).
class PendingSaleDao {
  final AppDatabase _appDb;

  PendingSaleDao(this._appDb);

  Future<void> insert(PendingSale sale) async {
    final db = await _appDb.database;
    await db.insert('pending_sales', sale.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Sync döngüsünün işleyeceği satırlar — `failed` satırlar OTOMATİK
  /// tekrar denenmez (kullanıcı "Bekleyenler"den elle "Yeniden Dene" demeli).
  Future<List<PendingSale>> fetchPending() async {
    final db = await _appDb.database;
    final rows = await db.query('pending_sales', where: "status = 'pending'", orderBy: 'created_at ASC');
    return rows.map(PendingSale.fromMap).toList();
  }

  /// "Bekleyen Senkronizasyonlar" sheet'i için — pending + failed hepsi.
  Future<List<PendingSale>> fetchAll() async {
    final db = await _appDb.database;
    final rows = await db.query('pending_sales', orderBy: 'created_at ASC');
    return rows.map(PendingSale.fromMap).toList();
  }

  Future<int> countPendingAndFailed() async {
    final db = await _appDb.database;
    final result =
        await db.rawQuery("SELECT COUNT(*) AS c FROM pending_sales WHERE status IN ('pending','failed')");
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> markFailed(String id, String error) async {
    final db = await _appDb.database;
    await db.rawUpdate(
      "UPDATE pending_sales SET status = 'failed', attempt_count = attempt_count + 1, "
      "last_error = ?, updated_at = ? WHERE id = ?",
      [error, DateTime.now().toIso8601String(), id],
    );
  }

  /// Tam başarı — satır tamamen silinir.
  Future<void> markSynced(String id) async {
    final db = await _appDb.database;
    await db.delete('pending_sales', where: 'id = ?', whereArgs: [id]);
  }

  /// "Bekleyenler" sheet'inde kullanıcı "Yeniden Dene" der — `failed` →
  /// `pending`, hata/deneme sayısı sıfırlanır ki taze bir şans verilsin.
  Future<void> retry(String id) async {
    final db = await _appDb.database;
    await db.update(
      'pending_sales',
      {'status': PendingSaleStatus.pending.name, 'last_error': null, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> discard(String id) async {
    final db = await _appDb.database;
    await db.delete('pending_sales', where: 'id = ?', whereArgs: [id]);
  }
}

@Riverpod(keepAlive: true)
PendingSaleDao pendingSaleDao(PendingSaleDaoRef ref) {
  return PendingSaleDao(ref.watch(appDatabaseProvider));
}
