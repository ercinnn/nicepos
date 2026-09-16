import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/ai_group_suggestion.dart';
import '../models/product_group.dart';

class ProductGroupRepository {
  final SupabaseClient _client = Supabase.instance.client;
  final Map<String, String> _nameToIdCache = {};

  Future<List<ProductGroup>> fetchAll() async {
    final rows = await _client.from('product_groups').select('*, parent_group:product_groups!parent_group_id(name), products(count)').order('name');
    return (rows as List).map((row) {
      final map = Map<String, dynamic>.from(row as Map);
      final rawParent = map['parent_group'];
      final parent = rawParent is Map
          ? Map<String, dynamic>.from(rawParent)
          : rawParent is List && rawParent.isNotEmpty
              ? Map<String, dynamic>.from(rawParent.first as Map)
              : null;
      final productsAgg = map['products'] as List?;
      final count = productsAgg != null && productsAgg.isNotEmpty ? (productsAgg.first['count'] as num?)?.toInt() ?? 0 : 0;
      return ProductGroup.fromMap({...map, 'parent_group_name': parent?['name'], 'product_count': count});
    }).toList();
  }

  Future<void> create(ProductGroup group) async {
    await _client.from('product_groups').insert(group.toInsertMap());
  }

  Future<void> update(String id, ProductGroup group) async {
    await _client.from('product_groups').update(group.toInsertMap()).eq('id', id);
  }

  Future<void> delete(String id) async {
    await _client.from('product_groups').delete().eq('id', id);
  }

  Future<String> findOrCreateByName(String name, {String? parentName}) async {
    final trimmed = name.trim();
    final cacheKey = '$trimmed|${parentName ?? ''}';
    if (_nameToIdCache.containsKey(cacheKey)) return _nameToIdCache[cacheKey]!;
    String? parentId;
    if (parentName != null && parentName.trim().isNotEmpty) {
      parentId = await findOrCreateByName(parentName.trim());
    }
    final existing = await _client.from('product_groups').select('id').eq('name', trimmed).maybeSingle();
    String id;
    if (existing != null) {
      id = existing['id'] as String;
    } else {
      final inserted = await _client.from('product_groups').insert({'name': trimmed, 'parent_group_id': parentId}).select('id').single();
      id = inserted['id'] as String;
    }
    _nameToIdCache[cacheKey] = id;
    return id;
  }

  // "AI ile Grupla": grubu boş ürünler için pg_trgm tabanlı k-NN
  // sınıflandırıcının (0063_product_group_suggestions.sql) önerilerini
  // getirir — harici bir API çağrısı yok, tamamen sunucu tarafında SQL RPC.
  Future<List<AiGroupSuggestion>> suggestGroupsForUnlabeledProducts({
    int k = 5,
    double minSimilarity = 0.35,
  }) async {
    final rows = await _client.rpc('suggest_product_groups', params: {
      'p_k': k,
      'p_min_similarity': minSimilarity,
    });
    return (rows as List)
        .map((r) => AiGroupSuggestion.fromMap(Map<String, dynamic>.from(r as Map)))
        .toList();
  }
}
