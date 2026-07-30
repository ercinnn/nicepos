import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sqflite/sqflite.dart';

import '../../../../core/local_db/app_database.dart';
import '../models/product.dart';

part 'product_local_cache_dao.g.dart';

/// `products_cache` tablosuna erişim — görülen her ürünün yerel aynası.
/// Yalnız native/Android'de kullanılır (çağıran taraf `!kIsWeb` ile korur).
class ProductLocalCacheDao {
  final AppDatabase _appDb;

  ProductLocalCacheDao(this._appDb);

  Product _fromRow(Map<String, dynamic> row) {
    return Product(
      id: row['id'] as String,
      barcode: row['barcode'] as String?,
      name: row['name'] as String,
      stockCode: row['stock_code'] as String?,
      groupId: row['group_id'] as String?,
      groupName: row['group_name'] as String?,
      parentGroupName: row['parent_group_name'] as String?,
      unit: row['unit'] as String? ?? 'Adet',
      originCountry: row['origin_country'] as String?,
      stockQuantity: row['stock_quantity'] as num? ?? 0,
      criticalStock: row['critical_stock'] as num? ?? 0,
      purchasePrice: row['purchase_price'] as num? ?? 0,
      purchasePriceVatIncluded: (row['purchase_price_vat_included'] as int? ?? 1) != 0,
      price1: row['price1'] as num? ?? 0,
      price1VatIncluded: (row['price1_vat_included'] as int? ?? 1) != 0,
      price2: row['price2'] as num? ?? 0,
      price2VatIncluded: (row['price2_vat_included'] as int? ?? 1) != 0,
      vatRate: row['vat_rate'] as num? ?? 20,
      weight: row['weight'] as num?,
      description: row['description'] as String?,
      imageUrl: row['image_url'] as String?,
      quickListOrder: (row['quick_list_order'] as num?)?.toInt(),
      isOnlineActive: (row['is_online_active'] as int? ?? 0) != 0,
      equivalentGroupId: row['equivalent_group_id'] as String?,
    );
  }

  Map<String, dynamic> _toRow(Product p, {required String syncState}) {
    return {
      'id': p.id,
      'barcode': p.barcode,
      'name': p.name,
      'stock_code': p.stockCode,
      'group_id': p.groupId,
      'group_name': p.groupName,
      'parent_group_name': p.parentGroupName,
      'unit': p.unit,
      'origin_country': p.originCountry,
      'stock_quantity': p.stockQuantity,
      'critical_stock': p.criticalStock,
      'purchase_price': p.purchasePrice,
      'purchase_price_vat_included': p.purchasePriceVatIncluded ? 1 : 0,
      'price1': p.price1,
      'price1_vat_included': p.price1VatIncluded ? 1 : 0,
      'price2': p.price2,
      'price2_vat_included': p.price2VatIncluded ? 1 : 0,
      'vat_rate': p.vatRate,
      'weight': p.weight,
      'description': p.description,
      'image_url': p.imageUrl,
      'quick_list_order': p.quickListOrder,
      'is_online_active': p.isOnlineActive ? 1 : 0,
      'equivalent_group_id': p.equivalentGroupId,
      'sync_state': syncState,
      'cached_at': DateTime.now().toIso8601String(),
    };
  }

  // Türkçe küçük harf: önce I→ı, İ→i eşle, sonra toLowerCase() — bu dosyaya
  // özgü kopya (repo konvansiyonu: paylaşılan util yok, bkz.
  // product_repository.dart / product_form_screen.dart'taki aynı desen).
  static String _trLower(String s) =>
      s.replaceAll('I', 'ı').replaceAll('İ', 'i').toLowerCase();

  /// Ürünler listesi ekranının offline fallback'i — `group_id` doluysa SQL
  /// ile daraltır (birebir eşleşme, harf duyarlılığı sorun değil), sonra
  /// ad/barkod/stok kodu üzerinde Türkçe-duyarlı bir "içerir" filtresi Dart
  /// tarafında uygulanır (SQLite `LIKE` yalnız ASCII harfleri katlar, Türkçe
  /// İ/i-I/ı çiftlerinde yanlış eşleşir). `name ASC` sıralı döner.
  Future<List<Product>> searchCached({String? query, String? groupId}) async {
    final db = await _appDb.database;
    final rows = await db.query(
      'products_cache',
      where: (groupId != null && groupId.isNotEmpty) ? 'group_id = ?' : null,
      whereArgs: (groupId != null && groupId.isNotEmpty) ? [groupId] : null,
      orderBy: 'name ASC',
    );
    var products = rows.map(_fromRow).toList();
    final q = query?.trim();
    if (q != null && q.isNotEmpty) {
      final needle = _trLower(q);
      products = products.where((p) {
        return _trLower(p.name).contains(needle) ||
            (p.barcode != null && _trLower(p.barcode!).contains(needle)) ||
            (p.stockCode != null && _trLower(p.stockCode!).contains(needle));
      }).toList();
    }
    return products;
  }

  Future<Product?> fetchById(String id) async {
    final db = await _appDb.database;
    final rows = await db.query('products_cache', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return _fromRow(rows.first);
  }

  Future<Product?> fetchByBarcode(String barcode) async {
    final db = await _appDb.database;
    final rows = await db.query('products_cache', where: 'barcode = ?', whereArgs: [barcode], limit: 1);
    if (rows.isEmpty) return null;
    return _fromRow(rows.first);
  }

  /// Tek bir ürünü yerelde yazar/günceller (offline optimistic upsert veya
  /// başarılı bir online yükleme sonrası fırsatçı önbellekleme için).
  Future<void> upsert(Product product, {required String syncState}) async {
    final db = await _appDb.database;
    await db.insert('products_cache', _toRow(product, syncState: syncState),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> markSynced(Product product) => upsert(product, syncState: 'synced');

  /// `EquivalentBarcodeSection`'ı offline'da kapatmak için — bu ürünün yerel
  /// satırı `pending_create`/`pending_update` durumundaysa `true` döner.
  Future<bool> isPendingSync(String id) async {
    final db = await _appDb.database;
    final rows = await db.query('products_cache',
        columns: ['sync_state'], where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return false;
    return rows.first['sync_state'] != 'synced';
  }

  /// "Bekleyenler" sheet'inde bir `create` kaydı atılırken çağrılır — ürün
  /// hiç var olmadığından yerel aynası da tamamen silinir.
  Future<void> deleteById(String id) async {
    final db = await _appDb.database;
    await db.delete('products_cache', where: 'id = ?', whereArgs: [id]);
  }

  /// "Bekleyenler" sheet'inde bir `update` kaydı atılırken çağrılır — satır
  /// verisine dokunmadan `sync_state='synced'` yapar (yerel değerler geçici
  /// olarak eski/yanlış kalabilir, bir sonraki `replaceAll` pull'u düzeltir).
  Future<void> markSyncStateSyncedById(String id) async {
    final db = await _appDb.database;
    await db.update('products_cache', {'sync_state': 'synced'}, where: 'id = ?', whereArgs: [id]);
  }

  /// Taze bir sunucu kataloğu ile toptan değiştirir — YALNIZ `sync_state='synced'`
  /// satırları silinir, hâlâ `pending_create`/`pending_update` durumundaki yerel
  /// satırlara DOKUNULMAZ (sync döngüsü sırasında gelen bir pull, henüz push
  /// edilmemiş yerel bir düzenlemeyi ezmesin diye).
  Future<void> replaceAll(List<Product> products) async {
    final db = await _appDb.database;
    await db.transaction((txn) async {
      await txn.delete('products_cache', where: "sync_state = 'synced'");
      final batch = txn.batch();
      for (final p in products) {
        batch.insert('products_cache', _toRow(p, syncState: 'synced'),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    });
  }
}

@Riverpod(keepAlive: true)
ProductLocalCacheDao productLocalCacheDao(ProductLocalCacheDaoRef ref) {
  return ProductLocalCacheDao(ref.watch(appDatabaseProvider));
}
