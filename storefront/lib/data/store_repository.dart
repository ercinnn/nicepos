import 'package:supabase_flutter/supabase_flutter.dart';

import 'models/cart_item.dart';
import 'models/store_category.dart';
import 'models/store_product.dart';
import 'models/store_tenant.dart';

class StoreRepository {
  final SupabaseClient _client = Supabase.instance.client;

  // `store_tenants` (bkz. 0045_storefront_multi_tenant.sql) — anon'un
  // okuyabildiği tek dar view, storefront'un "hangi kiracıyım" sorusunu
  // slug'dan tenant_id'ye çevirir. `tenants` tablosunun kendisi anon'a
  // KAPALI (current_tenant_id() üyeliğe bağlı).
  Future<StoreTenant?> resolveTenant(String slug) async {
    final row = await _client
        .from('store_tenants')
        .select('id, name, slug, storefront_image_aspect')
        .eq('slug', slug)
        .maybeSingle();
    if (row == null) return null;
    return StoreTenant.fromMap(Map<String, dynamic>.from(row));
  }

  // Her sorgu `tenant_id` ile filtrelenir — `online_products`/`product_groups`
  // RLS'i anon'a TÜM kiracıların satırlarını açık bırakıyor (0040/0029),
  // izolasyon burada, istemci tarafında sağlanır (bkz. store_repository.dart
  // üstündeki not, tenant_resolver.dart).
  Future<List<StoreProduct>> fetchProducts({
    required String tenantId,
    String? query,
    String? groupId,
  }) async {
    var builder = _client
        .from('online_products')
        .select()
        .eq('tenant_id', tenantId);
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

  Future<StoreProduct?> fetchProductById(String id, {required String tenantId}) async {
    final row = await _client
        .from('online_products')
        .select()
        .eq('id', id)
        .eq('tenant_id', tenantId)
        .maybeSingle();
    if (row == null) return null;
    return StoreProduct.fromMap(Map<String, dynamic>.from(row));
  }

  // Tüm ürün grupları çekilir (bkz. 0029_online_categories_public_read.sql —
  // anon'a public SELECT açıldı). Kullanıcı ismi/hiyerarşi için ham liste —
  // "hangi kategoriler filtre olarak GÖSTERİLİR" kararı ayrı bir yerde
  // (bkz. fetchActiveCategoryIds + catalog_provider.dart
  // visibleCategoriesProvider) — bu metot filtrelemez.
  Future<List<StoreCategory>> fetchCategories({required String tenantId}) async {
    final rows = await _client
        .from('product_groups')
        .select('id, name, parent_group_id')
        .eq('tenant_id', tenantId)
        .order('name');
    return (rows as List)
        .map(
          (row) => StoreCategory.fromMap(Map<String, dynamic>.from(row as Map)),
        )
        .toList();
  }

  // Yalnız en az bir online-aktif ürünü OLAN kategori id'leri (kullanıcı
  // isteği: "sitede sadece online açık olan ürünlerin kategorileri
  // görünsün"). DB migration gerekmez — online_products zaten yalnız
  // is_online_active=true satırları döndürüyor, burada yalnız group_id
  // sütunu çekilip Set'e indirgeniyor.
  Future<Set<String>> fetchActiveCategoryIds(String tenantId) async {
    final rows = await _client
        .from('online_products')
        .select('group_id')
        .eq('tenant_id', tenantId);
    return (rows as List)
        .map((row) => (row as Map)['group_id'] as String?)
        .whereType<String>()
        .toSet();
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
