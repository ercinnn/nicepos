import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sqflite/sqflite.dart';

import '../../../../core/local_db/app_database.dart';
import '../models/company.dart';
import '../models/product_group.dart';

part 'reference_cache_dao.g.dart';

/// Ürün Grubu dropdown'ı + Firma otomatik tamamlama listesi offline boş
/// kalmasın diye — her başarılı sync döngüsünde toptan yenilenir.
class ReferenceCacheDao {
  final AppDatabase _appDb;

  ReferenceCacheDao(this._appDb);

  Future<List<ProductGroup>> fetchGroups() async {
    final db = await _appDb.database;
    final rows = await db.query('product_groups_cache', orderBy: 'name ASC');
    return rows
        .map((row) => ProductGroup(
              id: row['id'] as String,
              name: row['name'] as String,
              parentGroupId: row['parent_group_id'] as String?,
              parentGroupName: row['parent_group_name'] as String?,
              showOnSalesPage: (row['show_on_sales_page'] as int? ?? 0) != 0,
              showOnPriceList: (row['show_on_price_list'] as int? ?? 0) != 0,
              productCount: (row['product_count'] as num?)?.toInt() ?? 0,
            ))
        .toList();
  }

  Future<List<Company>> fetchCompanies() async {
    final db = await _appDb.database;
    final rows = await db.query('companies_cache', orderBy: 'name ASC');
    return rows
        .map((row) => Company(
              id: row['id'] as String,
              name: row['name'] as String,
              createdAt: row['created_at'] != null ? DateTime.tryParse(row['created_at'] as String) : null,
            ))
        .toList();
  }

  Future<void> replaceGroups(List<ProductGroup> groups) async {
    final db = await _appDb.database;
    await db.transaction((txn) async {
      await txn.delete('product_groups_cache');
      final batch = txn.batch();
      for (final g in groups) {
        batch.insert('product_groups_cache', {
          'id': g.id,
          'name': g.name,
          'parent_group_id': g.parentGroupId,
          'parent_group_name': g.parentGroupName,
          'show_on_sales_page': g.showOnSalesPage ? 1 : 0,
          'show_on_price_list': g.showOnPriceList ? 1 : 0,
          'product_count': g.productCount,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    });
  }

  Future<void> replaceCompanies(List<Company> companies) async {
    final db = await _appDb.database;
    await db.transaction((txn) async {
      await txn.delete('companies_cache');
      final batch = txn.batch();
      for (final c in companies) {
        batch.insert(
          'companies_cache',
          {'id': c.id, 'name': c.name, 'created_at': c.createdAt?.toIso8601String()},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }
}

@Riverpod(keepAlive: true)
ReferenceCacheDao referenceCacheDao(ReferenceCacheDaoRef ref) {
  return ReferenceCacheDao(ref.watch(appDatabaseProvider));
}
