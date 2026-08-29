import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sqflite/sqflite.dart';

part 'app_database.g.dart';

/// Mobil çevrimdışı ürün ekleme/düzenleme için yerel SQLite veritabanı.
/// Yalnız native/Android'de açılır (`!kIsWeb` — çağıran taraflar sorumlu,
/// bu dosya web'de import edilirse `sqflite` zaten platform desteği vermez).
///
/// Tablolar:
/// - `products_cache`: görülen her ürünün yerel aynası + senkron durumu.
/// - `pending_changes`: senkronu bekleyen ekleme/güncelleme kuyruğu
///   (`product_id` PRIMARY KEY — aynı ürüne art arda offline düzenleme ayrı
///   log satırları değil, TEK satırın üzerine yazılır).
/// - `pending_sales` (v2): senkronu bekleyen Nakit/POS satış kuyruğu — `id`
///   PRIMARY KEY (istemcide üretilen uuid), APPEND-ONLY (`pending_changes`'in
///   aksine bir satış offline'da tekrar "düzenlenmez").
/// - `product_groups_cache` / `companies_cache`: Ürün Grubu dropdown'ı ve
///   Firma otomatik tamamlama listesi offline boş kalmasın diye.
/// - `sync_meta`: basit key/value (ör. `last_catalog_sync_at`).
class AppDatabase {
  static const _dbName = 'nice_pos_offline.db';
  static const _dbVersion = 2;

  Database? _db;

  Future<void> _createPendingSalesTable(Database db) async {
    await db.execute('''
      CREATE TABLE pending_sales (
        id TEXT PRIMARY KEY,
        payload_json TEXT NOT NULL,
        local_sale_code TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'pending',
        attempt_count INTEGER NOT NULL DEFAULT 0,
        last_error TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
  }

  Future<Database> get database async {
    final existing = _db;
    if (existing != null) return existing;
    final dir = await getApplicationSupportDirectory();
    // Yalnız Android'de açılır (çağıran taraf `!kIsWeb` ile korur) — ayırıcı
    // hep '/' olduğundan `path` paketine ayrı bağımlılık eklemeye gerek yok.
    final path = '${dir.path}/$_dbName';
    final db = await openDatabase(
      path,
      version: _dbVersion,
      // v1'den v2'ye: mevcut kurulumlardaki `pending_changes`/`products_cache`
      // verisi KORUNARAK yalnız yeni `pending_sales` tablosu eklenir.
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createPendingSalesTable(db);
        }
      },
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE products_cache (
            id TEXT PRIMARY KEY,
            barcode TEXT,
            name TEXT NOT NULL,
            stock_code TEXT,
            group_id TEXT,
            group_name TEXT,
            parent_group_name TEXT,
            unit TEXT NOT NULL DEFAULT 'Adet',
            origin_country TEXT,
            stock_quantity REAL NOT NULL DEFAULT 0,
            critical_stock REAL NOT NULL DEFAULT 0,
            purchase_price REAL NOT NULL DEFAULT 0,
            purchase_price_vat_included INTEGER NOT NULL DEFAULT 1,
            price1 REAL NOT NULL DEFAULT 0,
            price1_vat_included INTEGER NOT NULL DEFAULT 1,
            price2 REAL NOT NULL DEFAULT 0,
            price2_vat_included INTEGER NOT NULL DEFAULT 1,
            vat_rate REAL NOT NULL DEFAULT 20,
            weight REAL,
            description TEXT,
            image_url TEXT,
            quick_list_order INTEGER,
            is_online_active INTEGER NOT NULL DEFAULT 0,
            equivalent_group_id TEXT,
            sync_state TEXT NOT NULL DEFAULT 'synced',
            cached_at TEXT NOT NULL
          )
        ''');
        await db.execute('CREATE INDEX idx_products_cache_barcode ON products_cache(barcode)');
        await db.execute('CREATE INDEX idx_products_cache_name ON products_cache(name)');

        await db.execute('''
          CREATE TABLE pending_changes (
            product_id TEXT PRIMARY KEY,
            operation TEXT NOT NULL,
            payload_json TEXT NOT NULL,
            pending_image_path TEXT,
            status TEXT NOT NULL DEFAULT 'pending',
            attempt_count INTEGER NOT NULL DEFAULT 0,
            last_error TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');

        await _createPendingSalesTable(db);

        await db.execute('''
          CREATE TABLE product_groups_cache (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            parent_group_id TEXT,
            parent_group_name TEXT,
            show_on_sales_page INTEGER NOT NULL DEFAULT 0,
            show_on_price_list INTEGER NOT NULL DEFAULT 0,
            product_count INTEGER NOT NULL DEFAULT 0
          )
        ''');

        await db.execute('''
          CREATE TABLE companies_cache (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            created_at TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE sync_meta (
            key TEXT PRIMARY KEY,
            value TEXT
          )
        ''');
      },
    );
    _db = db;
    return db;
  }

  /// Çapraz-kiracı sızıntısını önler (yaşanmış hata — bkz. `auth_provider.dart`
  /// `ensureTenantProvisioned`): aynı cihazda önce BAŞKA bir kiracı oturum
  /// açmışsa, bu SAF önbellek tabloları (RLS'e hiç uğramaz, `tenant_id`
  /// TAŞIMAZ) eski kiracının ürün/grup/firma verisini tutmaya devam eder —
  /// barkod okutma o eski ürünü sepete ekleyebilir. Yalnız GERÇEK bir yeni
  /// girişte çağrılır. `pending_sales`/`pending_changes` (henüz senkron
  /// olmamış GERÇEK kullanıcı işi) ve `sync_meta` kasıtlı olarak DOKUNULMAZ —
  /// veri kaybı riski, çapraz-kiracı okuma sızıntısından daha büyük bir zarar
  /// olurdu.
  Future<void> clearTenantScopedCaches() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('products_cache');
      await txn.delete('product_groups_cache');
      await txn.delete('companies_cache');
    });
  }
}

@Riverpod(keepAlive: true)
AppDatabase appDatabase(AppDatabaseRef ref) => AppDatabase();
