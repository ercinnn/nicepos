import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/concept_product.dart';

/// Konsept Ürünler (0067_concept_products.sql) — `concept_products` +
/// `concept_product_items` tabloları. Parçalar `products(*)` embed'iyle gelir.
class ConceptRepository {
  final SupabaseClient _client = Supabase.instance.client;

  static const _select = '*, concept_product_items(product_id, quantity, sort_order, '
      'products(*, product_groups(name, parent_group:parent_group_id(name))))';

  Future<List<ConceptProduct>> fetchAll() async {
    final rows = await _client
        .from('concept_products')
        .select(_select)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((row) => ConceptProduct.fromMap(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  Future<ConceptProduct?> fetchByBarcode(String barcode) async {
    final row = await _client
        .from('concept_products')
        .select(_select)
        .eq('barcode', barcode.trim().toUpperCase())
        .maybeSingle();
    if (row == null) return null;
    return ConceptProduct.fromMap(Map<String, dynamic>.from(row));
  }

  Future<Set<String>> fetchBarcodesWithPrefix(String prefix) async {
    final rows = await _client
        .from('concept_products')
        .select('barcode')
        .ilike('barcode', '$prefix%');
    return {for (final row in (rows as List)) (row as Map)['barcode'] as String};
  }

  /// Konsept + parça listesini TEK atomik RPC ile yazar (`save_concept_product`).
  /// [id] null → yeni konsept. Dönüş: konseptin id'si.
  Future<String> save({
    String? id,
    required String barcode,
    required String name,
    num? price,
    required List<ConceptProductItem> items,
  }) async {
    final result = await _client.rpc('save_concept_product', params: {
      'p_id': id,
      'p_barcode': barcode,
      'p_name': name,
      'p_price': price,
      'p_items': items
          .map((i) => {'product_id': i.productId, 'quantity': i.quantity})
          .toList(),
    });
    return result as String;
  }

  Future<void> delete(String id) async {
    await _client.from('concept_products').delete().eq('id', id);
  }
}
