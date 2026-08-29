import 'package:supabase_flutter/supabase_flutter.dart';

/// Çağıran kullanıcının kiracı id'sini döndürür — Storage path'lerini
/// (`<tenant_id>/...`) oluşturmak için kullanılır (bkz. Faz E, 0043 migration).
/// `memberships` RLS'i zaten `user_id = auth.uid()`'e daraltıldığından
/// filtresiz `select` tam olarak çağıranın kendi üyeliğini döndürür — tablo
/// INSERT'lerindeki `tenant_id default current_tenant_id()` deseninin
/// istemci tarafındaki karşılığı (Storage path'leri DB kolonu olmadığından
/// sunucu tarafı default'a güvenilemez, burada açıkça çözümlenir).
Future<String> currentTenantIdOrThrow(SupabaseClient client) async {
  final rows = await client.from('memberships').select('tenant_id').limit(1);
  if (rows.isEmpty) {
    throw Exception('Kiracı bulunamadı.');
  }
  return rows.first['tenant_id'] as String;
}
