import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/product.dart';
import '../models/product_filters.dart';
import '../models/equivalent_aggregate.dart';

class ProductRepository {
  final SupabaseClient _client = Supabase.instance.client;

  // Sıralanabilir sütunlar — Ürünler tablosu başlıklarına dokununca (bkz.
  // products_list_screen.dart `_dbColumnFor`). Beyaz liste: hem PostgREST
  // `.order()` çağrısında hem RPC'nin CASE tabanlı ORDER BY'ında kullanılan
  // gerçek `products` sütun adları — rastgele bir dize asla doğrudan sorguya
  // enjekte edilmez.
  static const sortableColumns = {
    'name', 'barcode', 'stock_quantity', 'critical_stock', 'vat_rate', 'purchase_price', 'price1', 'price2',
  };

  // Türkçe büyük harf: önce i→İ, ı→I eşle, sonra toUpperCase().
  // Dart'ın yerleşik toUpperCase'i Türkçe değildir; noktalı/noktasız i'yi yanlış katlar.
  static String _trUpper(String s) =>
      s.replaceAll('i', 'İ').replaceAll('ı', 'I').toUpperCase();

  // Türkçe küçük harf: önce I→ı, İ→i eşle, sonra toLowerCase().
  static String _trLower(String s) =>
      s.replaceAll('I', 'ı').replaceAll('İ', 'i').toLowerCase();

  // Arama için PostgREST .or() filtre dizesini kurar.
  // ilike ASCII'de harf-duyarsızdır ama Türkçe İ/i, I/ı çiftlerinde yanlış
  // eşleşir; bu yüzden sorguyu {ham, Türkçe-büyük, Türkçe-küçük} varyantlarıyla
  // genişletip name/barcode/stock_code üzerinde OR'larız. Stored değer büyük
  // harfliyse büyük varyant, küçük saklıysa küçük varyant ilike ile yakalar.
  static String _buildSearchOr(String q) {
    // .or() virgülle ayrılır; sorgudaki , ( ) filtre sözdizimini bozar →
    // davranışı değiştirmeden bu karakterleri boşlukla sadeleştir.
    final safe = q.replaceAll(RegExp(r'[,()]'), ' ').trim();
    final variants = <String>{safe, _trUpper(safe), _trLower(safe)};
    return variants
        .expand((v) => [
              'name.ilike.%$v%',
              'barcode.ilike.%$v%',
              'stock_code.ilike.%$v%',
            ])
        .join(',');
  }

  // Sütun bazlı filtreler (Ürünler tablosu başlık ikonları) — `product_groups`
  // embed'i üzerinde ilike ile filtreleme PostgREST'in desteklediği bir
  // özellik (embedded resource filter, tek/iki seviye — canlı API'ye karşı
  // doğrulandı); embed edilmiş bir alana filtre uygulamak üst seviye satırları
  // da daraltır (implicit inner join davranışı).
  // NOT: PostgrestFilterBuilder immutable — her .ilike()/.gte()/.lte() çağrısı
  // YENİ bir builder döndürür (bkz. postgrest paketi `_copyWith`), `this`'i
  // mutasyona uğratmaz. Bu yüzden güncellenmiş builder'ı geri DÖNDÜRMEK
  // zorunlu; çağıran taraf `builder = _applyColumnFilters(builder, filters)`
  // ile atamalı — aksi halde filtreler sessizce kaybolur.
  PostgrestFilterBuilder<T> _applyColumnFilters<T>(PostgrestFilterBuilder<T> builder, ProductFilters filters) {
    // Barkod "içerir" değil BİREBİR eşleşme (kullanıcı isteği: "002" yazınca
    // yalnız barkodu tam "002" olan ürün gelsin).
    if (filters.barcode != null) builder = builder.eq('barcode', filters.barcode!);
    if (filters.stockCode != null) builder = builder.ilike('stock_code', '%${filters.stockCode}%');
    if (filters.unit != null) builder = builder.ilike('unit', '%${filters.unit}%');
    if (filters.groupName != null) builder = builder.ilike('product_groups.name', '%${filters.groupName}%');
    if (filters.parentGroupName != null) {
      builder = builder.ilike('product_groups.parent_group.name', '%${filters.parentGroupName}%');
    }
    if (filters.stockMin != null) builder = builder.gte('stock_quantity', filters.stockMin!);
    if (filters.stockMax != null) builder = builder.lte('stock_quantity', filters.stockMax!);
    if (filters.criticalStockMin != null) builder = builder.gte('critical_stock', filters.criticalStockMin!);
    if (filters.criticalStockMax != null) builder = builder.lte('critical_stock', filters.criticalStockMax!);
    if (filters.vatMin != null) builder = builder.gte('vat_rate', filters.vatMin!);
    if (filters.vatMax != null) builder = builder.lte('vat_rate', filters.vatMax!);
    if (filters.purchaseMin != null) builder = builder.gte('purchase_price', filters.purchaseMin!);
    if (filters.purchaseMax != null) builder = builder.lte('purchase_price', filters.purchaseMax!);
    if (filters.price1Min != null) builder = builder.gte('price1', filters.price1Min!);
    if (filters.price1Max != null) builder = builder.lte('price1', filters.price1Max!);
    if (filters.price2Min != null) builder = builder.gte('price2', filters.price2Min!);
    if (filters.price2Max != null) builder = builder.lte('price2', filters.price2Max!);
    return builder;
  }

  // "Durum" (Çok Satan/Tükendi/Pasif/Boş) `products` tablosunda bir sütun
  // DEĞİL — `product_status` view'ından hesaplanır (bkz. 0016_product_status.sql)
  // ve view'ın `products`'a tanımlı bir FK'si olmadığından PostgREST embed
  // filtresi desteklemiyor. İLK sürüm önce eşleşen id'leri ayrı bir sorguyla
  // çekip ana sorguya `inFilter('id', ids)` olarak ekliyordu — ama "Pasif" gibi
  // çok sayıda ürünü kapsayan bir durumda bu id listesi URL'yi aşırı uzatıp
  // "Bad Request (400)" hatası veriyordu (canlıda gözlemlendi). Bu yüzden durum
  // filtresi aktifken TÜM sorgu (arama+grup+sütun filtreleri+durum+sayfalama)
  // tek bir RPC çağrısında sunucuda birleştirilir (bkz. 0017_search_products_rpc.sql)
  // — id listesi asla istemciye/URL'ye geri dönmez. Durum filtresi YOKSA eski
  // (daha basit, iyi test edilmiş) PostgREST sorgu zinciri kullanılmaya devam eder.
  Map<String, dynamic> _searchProductsParams({
    String? query,
    String? groupId,
    required ProductFilters filters,
    required String sortColumn,
    required bool sortAscending,
  }) {
    return {
      'p_query': (query != null && query.trim().isNotEmpty) ? query.trim() : null,
      'p_group_id': (groupId != null && groupId.isNotEmpty) ? groupId : null,
      'p_status': filters.status,
      'p_sort_column': sortableColumns.contains(sortColumn) ? sortColumn : 'name',
      'p_sort_ascending': sortAscending,
      'p_barcode': filters.barcode,
      'p_stock_code': filters.stockCode,
      'p_unit': filters.unit,
      'p_group_name': filters.groupName,
      'p_parent_group_name': filters.parentGroupName,
      'p_stock_min': filters.stockMin,
      'p_stock_max': filters.stockMax,
      'p_critical_stock_min': filters.criticalStockMin,
      'p_critical_stock_max': filters.criticalStockMax,
      'p_vat_min': filters.vatMin,
      'p_vat_max': filters.vatMax,
      'p_purchase_min': filters.purchaseMin,
      'p_purchase_max': filters.purchaseMax,
      'p_price1_min': filters.price1Min,
      'p_price1_max': filters.price1Max,
      'p_price2_min': filters.price2Min,
      'p_price2_max': filters.price2Max,
    };
  }

  Future<List<Product>> fetchAll({
    String? query,
    String? groupId,
    ProductFilters? filters,
    String sortColumn = 'name',
    bool sortAscending = true,
  }) async {
    final sortCol = sortableColumns.contains(sortColumn) ? sortColumn : 'name';
    if (filters != null && filters.status != null) {
      const batch = 1000;
      final all = <Product>[];
      var page = 0;
      while (true) {
        final rows = await _client.rpc('search_products', params: {
          ..._searchProductsParams(query: query, groupId: groupId, filters: filters, sortColumn: sortCol, sortAscending: sortAscending),
          'p_limit': batch,
          'p_offset': page * batch,
        });
        final list = (rows as List).map((row) => Product.fromMap(Map<String, dynamic>.from(row as Map))).toList();
        all.addAll(list);
        if (list.length < batch) break;
        page++;
      }
      return all;
    }
    // PostgREST sunucu tarafı varsayılan olarak en fazla 1000 satır döndürür.
    // Tüm ürünleri almak için 1000'lik sayfalarla döngüsel çekeriz.
    const batch = 1000;
    final all = <Product>[];
    var page = 0;
    while (true) {
      var builder = _client.from('products').select('*, product_groups(name, parent_group:parent_group_id(name))');
      if (query != null && query.trim().isNotEmpty) {
        builder = builder.or(_buildSearchOr(query.trim()));
      }
      if (groupId != null && groupId.isNotEmpty) {
        builder = builder.eq('group_id', groupId);
      }
      if (filters != null) {
        builder = _applyColumnFilters(builder, filters);
      }
      final from = page * batch;
      final rows = await builder.order(sortCol, ascending: sortAscending).range(from, from + batch - 1);
      final list = (rows as List).map((row) => Product.fromMap(Map<String, dynamic>.from(row as Map))).toList();
      all.addAll(list);
      if (list.length < batch) break;
      page++;
    }
    return all;
  }

  Future<List<Product>> fetchPaged({
    String? query,
    String? groupId,
    ProductFilters? filters,
    String sortColumn = 'name',
    bool sortAscending = true,
    int page = 0,
    int pageSize = 50,
  }) async {
    final sortCol = sortableColumns.contains(sortColumn) ? sortColumn : 'name';
    if (filters != null && filters.status != null) {
      // +1 üst sınır: ekran "sonraki sayfa var mı" kontrolünü
      // `_products.length > kProductPageSize` ile yapıyor (bkz.
      // products_list_screen.dart `_hasMore`) — eski `.range()` deseniyle
      // aynı "1 fazla çek" yaklaşımı.
      final rows = await _client.rpc('search_products', params: {
        ..._searchProductsParams(query: query, groupId: groupId, filters: filters, sortColumn: sortCol, sortAscending: sortAscending),
        'p_limit': pageSize + 1,
        'p_offset': page * pageSize,
      });
      return (rows as List).map((row) => Product.fromMap(Map<String, dynamic>.from(row as Map))).toList();
    }
    var builder = _client.from('products').select('*, product_groups(name, parent_group:parent_group_id(name))');
    if (query != null && query.trim().isNotEmpty) {
      builder = builder.or(_buildSearchOr(query.trim()));
    }
    if (groupId != null && groupId.isNotEmpty) {
      builder = builder.eq('group_id', groupId);
    }
    if (filters != null) {
      builder = _applyColumnFilters(builder, filters);
    }
    final from = page * pageSize;
    final rows = await builder.order(sortCol, ascending: sortAscending).range(from, from + pageSize);
    return (rows as List).map((row) => Product.fromMap(Map<String, dynamic>.from(row as Map))).toList();
  }

  Future<Product?> fetchById(String id) async {
    final row = await _client.from('products').select('*, product_groups(name, parent_group:parent_group_id(name))').eq('id', id).maybeSingle();
    if (row == null) return null;
    return Product.fromMap(Map<String, dynamic>.from(row));
  }

  Future<Product?> fetchByBarcode(String barcode) async {
    final row = await _client.from('products').select('*, product_groups(name, parent_group:parent_group_id(name))').eq('barcode', barcode).maybeSingle();
    if (row == null) return null;
    final product = Product.fromMap(Map<String, dynamic>.from(row));
    // Eşlenik Barkod: bu satır bir gruba aitse, DÖNEN nesneyi grup toplamı
    // (stok = SUM) + grubun en son güncellenen satırının fiyat/alış bilgisiyle
    // override et — DB'ye YAZMA yok, yalnız satış/etiket ekranlarının okuduğu
    // değer grubu yansıtsın diye (bkz. 0021_equivalent_barcodes.sql).
    if (product.equivalentGroupId != null) {
      final aggregates = await fetchEquivalentAggregates([product.id]);
      final agg = aggregates[product.id];
      if (agg != null) {
        return product.copyWith(
          stockQuantity: agg.totalStock,
          price1: agg.groupPrice1,
          price2: agg.groupPrice2,
          purchasePrice: agg.groupPurchasePrice,
        );
      }
    }
    return product;
  }

  // Mobil "Yeni Ürün" ekranındaki "+ barkod üret" butonu — bugünün YYMMDD
  // önekiyle başlayan tüm barkodları döner, sıradaki boş XXX'i bulmak için
  // (bkz. product_form_screen.dart `nextBarcodeCandidate`).
  Future<Set<String>> fetchBarcodesWithPrefix(String prefix) async {
    final rows = await _client.from('products').select('barcode').ilike('barcode', '$prefix%');
    return {
      for (final row in (rows as List))
        if ((row as Map)['barcode'] != null) row['barcode'] as String,
    };
  }

  // Eşlenik Barkod: görüntülenen sayfadaki ürünler için grup toplamlarını
  // `product_equivalent_aggregate` view'ından (bkz. 0021_equivalent_barcodes.sql)
  // tek sorguda çeker — `fetchStatuses` ile BİREBİR aynı desen (id listesiyle
  // filtreli, ana ürün sorgusundan AYRI ikinci istek). Dönüş: product_id →
  // agregat (yalnız eşlenik gruba sahip ürünler için anahtar içerir).
  Future<Map<String, EquivalentAggregate>> fetchEquivalentAggregates(List<String> productIds) async {
    if (productIds.isEmpty) return {};
    try {
      final rows = await _client
          .from('product_equivalent_aggregate')
          .select()
          .inFilter('product_id', productIds);
      return {
        for (final row in (rows as List))
          (row as Map)['product_id'] as String:
              EquivalentAggregate.fromMap(Map<String, dynamic>.from(row)),
      };
    } catch (_) {
      // Agregat bilgisi ikincil — sessizce yoksay, liste yine gösterilir.
      return {};
    }
  }

  // Bir eşlenik barkod grubunun tüm üyelerini (ham satırlarıyla) döner —
  // Ürünler listesindeki "!" ikonu / ürün formundaki grup listesi bunu kullanır.
  // Sıralama: esas satır artık en son güncellenen (grubun "esas" satırı — bkz.
  // product_equivalent_aggregate view'ı, 0024 migration — 0022'deki "en yüksek
  // fiyat" kuralı geri alındı).
  Future<List<Product>> fetchGroupMembers(String groupId) async {
    final rows = await _client
        .from('products')
        .select('*, product_groups(name, parent_group:parent_group_id(name))')
        .eq('equivalent_group_id', groupId)
        .order('updated_at', ascending: false);
    return (rows as List).map((row) => Product.fromMap(Map<String, dynamic>.from(row as Map))).toList();
  }

  // İki ürünü eşlenik barkod olarak bağlar. Grup kuralları (KARAR):
  //   - ikisi de grupsuzsa → yeni grup id'si üretilip ikisine de yazılır
  //   - biri gruplu biri değilse → gruplu olmayan, diğerinin grubuna katılır
  //   - ikisi de gruplu ve FARKLI gruplardaysa → B'nin grubundaki TÜM satırlar
  //     A'nın grubuna taşınır (iki grup birleşir)
  //   - ikisi de aynı gruptaysa → no-op
  Future<void> linkEquivalentBarcode(String productIdA, String productIdB) async {
    if (productIdA == productIdB) return;
    final rows = await _client
        .from('products')
        .select('id, equivalent_group_id')
        .inFilter('id', [productIdA, productIdB]);
    final byId = {
      for (final row in (rows as List))
        (row as Map)['id'] as String: row['equivalent_group_id'] as String?,
    };
    final groupA = byId[productIdA];
    final groupB = byId[productIdB];

    if (groupA == null && groupB == null) {
      final newGroupId = const Uuid().v4();
      await _client
          .from('products')
          .update({'equivalent_group_id': newGroupId})
          .inFilter('id', [productIdA, productIdB]);
    } else if (groupA == null && groupB != null) {
      await _client.from('products').update({'equivalent_group_id': groupB}).eq('id', productIdA);
    } else if (groupA != null && groupB == null) {
      await _client.from('products').update({'equivalent_group_id': groupA}).eq('id', productIdB);
    } else if (groupA != groupB) {
      // B'nin grubundaki tüm satırları A'nın grubuna taşı (grupları birleştir).
      await _client.from('products').update({'equivalent_group_id': groupA}).eq('equivalent_group_id', groupB!);
    }
    // groupA == groupB (ikisi de aynı, null değil) → no-op.
  }

  // Bir ürünü eşlenik barkod grubundan çıkarır. Grupta tek satır kalırsa
  // (tek kişilik grup anlamsız) o satırın da grup bağlantısı temizlenir.
  Future<void> unlinkEquivalentBarcode(String productId) async {
    final row = await _client
        .from('products')
        .select('equivalent_group_id')
        .eq('id', productId)
        .maybeSingle();
    final groupId = row?['equivalent_group_id'] as String?;
    if (groupId == null) return;

    await _client.from('products').update({'equivalent_group_id': null}).eq('id', productId);

    final remaining = await _client
        .from('products')
        .select('id')
        .eq('equivalent_group_id', groupId);
    if ((remaining as List).length == 1) {
      final lastId = (remaining.first as Map)['id'] as String;
      await _client.from('products').update({'equivalent_group_id': null}).eq('id', lastId);
    }
  }

  // Liste Gir: birden çok barkodu tek sorguda arar (fetchStatuses'daki
  // inFilter deseninin aynısı) — N sıralı fetchByBarcode çağrısı yerine.
  Future<Map<String, Product>> fetchByBarcodes(List<String> barcodes) async {
    if (barcodes.isEmpty) return {};
    final rows = await _client
        .from('products')
        .select('*, product_groups(name, parent_group:parent_group_id(name))')
        .inFilter('barcode', barcodes);
    final result = <String, Product>{};
    for (final row in (rows as List)) {
      final product = Product.fromMap(Map<String, dynamic>.from(row as Map));
      if (product.barcode != null) result[product.barcode!] = product;
    }
    return result;
  }

  Future<List<Product>> fetchByGroup(String groupId) async {
    final rows = await _client.from('products').select('*, product_groups(name, parent_group:parent_group_id(name))').eq('group_id', groupId).order('quick_list_order', ascending: true).limit(100000);
    return (rows as List).map((row) => Product.fromMap(Map<String, dynamic>.from(row as Map))).toList();
  }

  Future<String> create(Product product) async {
    final row = await _client.from('products').insert(product.toInsertMap()).select('id').single();
    return row['id'] as String;
  }

  // Çevrimdışı oluşturulan ürünler için: id istemcide (UUID v4) üretilmiştir,
  // sunucuya AÇIKÇA gönderilir (normal `create()` DB varsayılanına bırakır).
  // `products.id uuid primary key default gen_random_uuid()` — açık id insert'i
  // migration gerektirmeden kabul eder. Yalnız product_sync_service.dart'taki
  // senkron kuyruğu tarafından çağrılır.
  Future<void> createWithId(Product product) async {
    await _client.from('products').insert({'id': product.id, ...product.toInsertMap()});
  }

  Future<void> update(String id, Product product) async {
    await _client.from('products').update(product.toInsertMap()).eq('id', id);
  }

  // Yalnızca satış fiyatını (price1) kalıcı olarak günceller — satış ekranındaki
  // "Fiyat1 yap" kontrolü kullanır (design-tokens §5, KARAR v1.6). PK: 'id'.
  Future<void> updatePrice1(String productId, num newPrice) async {
    await _client
        .from('products')
        .update({'price1': newPrice}).eq('id', productId);
  }

  // Yalnızca online mağaza görünürlüğünü değiştirir (Online Satış kontrol
  // paneli + ürün formundaki "Online Aç" anahtarı ortak metod) — updatePrice1
  // ile aynı hedefli-update deseni, diğer alanları etkilemez.
  Future<void> setOnlineActive(String productId, bool value) async {
    await _client
        .from('products')
        .update({'is_online_active': value}).eq('id', productId);
  }

  // Online Satış kontrol panelinde gösterilen, halihazırda mağazada aktif
  // ürünler listesi.
  Future<List<Product>> fetchOnlineActive() async {
    final rows = await _client
        .from('products')
        .select('*, product_groups(name, parent_group:parent_group_id(name))')
        .eq('is_online_active', true)
        .order('name');
    return (rows as List).map((row) => Product.fromMap(Map<String, dynamic>.from(row as Map))).toList();
  }

  Future<void> upsertByBarcode(Product product) async {
    if (product.barcode == null || product.barcode!.isEmpty) {
      await create(product);
      return;
    }
    final existing = await fetchByBarcode(product.barcode!);
    if (existing != null) {
      await update(existing.id, product);
    } else {
      await create(product);
    }
  }

  // Görüntülenen sayfadaki ürünler için "Durum" (Çok Satan/Tükendi/Pasif)
  // bilgisini `product_status` view'ından tek sorguda çeker (bkz.
  // 0016_product_status.sql). Dönüş: product_id → status ('cok_satan' |
  // 'tukendi' | 'pasif' | null).
  Future<Map<String, String?>> fetchStatuses(List<String> productIds) async {
    if (productIds.isEmpty) return {};
    final rows = await _client
        .from('product_status')
        .select('product_id, status')
        .inFilter('product_id', productIds);
    return {
      for (final row in (rows as List))
        (row as Map)['product_id'] as String: row['status'] as String?,
    };
  }

  Future<void> delete(String id) async {
    final deleted = await _client.from('products').delete().eq('id', id).select('id');
    if (deleted.isEmpty) throw Exception('Ürün silinemedi.');
  }

  Future<void> decrementStock(String productId, num quantity) async {
    await _client.rpc('decrement_product_stock', params: {'p_product_id': productId, 'p_quantity': quantity});
  }

  Future<void> incrementStock(String productId, num quantity) async {
    await _client.rpc('increment_product_stock', params: {'p_product_id': productId, 'p_quantity': quantity});
  }

  Future<String> uploadImage(String productId, Uint8List bytes, String fileExt) async {
    final path = 'products/$productId.$fileExt';
    await _client.storage.from('product-images').uploadBinary(path, bytes, fileOptions: const FileOptions(upsert: true));
    return _client.storage.from('product-images').getPublicUrl(path);
  }
}
