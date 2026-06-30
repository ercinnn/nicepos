import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/product.dart';

class ProductRepository {
  final SupabaseClient _client = Supabase.instance.client;

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

  Future<List<Product>> fetchAll({String? query, String? groupId}) async {
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
      final from = page * batch;
      final rows = await builder.order('name').range(from, from + batch - 1);
      final list = (rows as List).map((row) => Product.fromMap(Map<String, dynamic>.from(row as Map))).toList();
      all.addAll(list);
      if (list.length < batch) break;
      page++;
    }
    return all;
  }

  Future<List<Product>> fetchPaged({String? query, String? groupId, int page = 0, int pageSize = 50}) async {
    var builder = _client.from('products').select('*, product_groups(name, parent_group:parent_group_id(name))');
    if (query != null && query.trim().isNotEmpty) {
      builder = builder.or(_buildSearchOr(query.trim()));
    }
    if (groupId != null && groupId.isNotEmpty) {
      builder = builder.eq('group_id', groupId);
    }
    final from = page * pageSize;
    final rows = await builder.order('name').range(from, from + pageSize);
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
    return Product.fromMap(Map<String, dynamic>.from(row));
  }

  Future<List<Product>> fetchByGroup(String groupId) async {
    final rows = await _client.from('products').select('*, product_groups(name, parent_group:parent_group_id(name))').eq('group_id', groupId).order('quick_list_order', ascending: true).limit(100000);
    return (rows as List).map((row) => Product.fromMap(Map<String, dynamic>.from(row as Map))).toList();
  }

  Future<String> create(Product product) async {
    final row = await _client.from('products').insert(product.toInsertMap()).select('id').single();
    return row['id'] as String;
  }

  Future<void> update(String id, Product product) async {
    await _client.from('products').update(product.toInsertMap()).eq('id', id);
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
