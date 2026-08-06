import 'package:supabase_flutter/supabase_flutter.dart';

import 'models/cart_item.dart';
import 'models/store_category.dart';
import 'models/store_product.dart';

class StoreRepository {
  final SupabaseClient _client = Supabase.instance.client;

  Future<List<StoreProduct>> fetchProducts({
    String? query,
    String? groupId,
  }) async {
    var builder = _client.from('online_products').select();
    if (query != null && query.trim().isNotEmpty) {
      final q = query.trim();
      builder = builder.or('name.ilike.%$q%,barcode.ilike.%$q%');
    }
    if (groupId != null && groupId.isNotEmpty) {
      builder = builder.eq('group_id', groupId);
    }
    final rows = await builder.order('name');
    return (rows as List)
        .map(
          (row) => StoreProduct.fromMap(Map<String, dynamic>.from(row as Map)),
        )
        .toList();
  }

  Future<StoreProduct?> fetchProductById(String id) async {
    final row = await _client
        .from('online_products')
        .select()
        .eq('id', id)
        .maybeSingle();
    if (row == null) return null;
    return StoreProduct.fromMap(Map<String, dynamic>.from(row));
  }

  // Tüm ürün grupları çekilir (bkz. 0029_online_categories_public_read.sql —
  // anon'a public SELECT açıldı). v1'de client tarafında ürünü olmayan
  // gruplar filtrelenmez — boş bir kategoriye tıklanırsa grid boş görünür.
  Future<List<StoreCategory>> fetchCategories() async {
    final rows = await _client
        .from('product_groups')
        .select('id, name, parent_group_id')
        .order('name');
    return (rows as List)
        .map(
          (row) => StoreCategory.fromMap(Map<String, dynamic>.from(row as Map)),
        )
        .toList();
  }

  // Misafir sipariş — sunucu tarafında fiyat/stok/aktiflik doğrulanır
  // (bkz. create_online_order RPC, 0028_online_satis.sql). Döner: order_code.
  Future<String> createOrder({
    required String customerName,
    required String customerPhone,
    String? customerEmail,
    required String shippingAddress,
    String? customerNote,
    required List<CartItem> items,
  }) async {
    final result = await _client.rpc(
      'create_online_order',
      params: {
        'p_customer_name': customerName,
        'p_customer_phone': customerPhone,
        'p_customer_email': customerEmail,
        'p_shipping_address': shippingAddress,
        'p_customer_note': customerNote,
        'p_items': items
            .map(
              (item) => {
                'product_id': item.product.id,
                'quantity': item.quantity,
              },
            )
            .toList(),
      },
    );
    return (result as Map)['order_code'] as String;
  }
}
