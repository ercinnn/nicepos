import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/audit_log_entry.dart';

/// `audit_log` tablosu (0044 migration, **Supabase SQL Editor'da elle
/// uygulanmış olmalı**) — kalıcı/geri alınamaz işlemler için kim-ne-zaman-ne
/// kaydı. `tenant_id`/`actor_user_id` sunucu tarafı DEFAULT ile dolar
/// (`current_tenant_id()`/`auth.uid()`), istemci hiç göndermez — diğer iş
/// tablolarıyla AYNI desen.
class AuditLogRepository {
  final SupabaseClient _client = Supabase.instance.client;

  /// Bir işlemi kaydeder. **İkincil bir yan etki** — asıl işlem (ör. satış
  /// silme) zaten tamamlanmış olur, log yazımı başarısız olsa bile (migration
  /// henüz uygulanmadıysa, RLS reddederse vb.) sessizce yutulur; asıl işlemi
  /// GERİ ALMAZ.
  Future<void> log({
    required String action,
    required String entityType,
    String? entityId,
    required String summary,
  }) async {
    try {
      await _client.from('audit_log').insert({
        'actor_email': _client.auth.currentUser?.email,
        'action': action,
        'entity_type': entityType,
        'entity_id': entityId,
        'summary': summary,
      });
    } catch (_) {}
  }

  /// Sayfalı liste — en yeni önce. Yalnız owner/admin okuyabilir (RLS).
  Future<List<AuditLogEntry>> fetchPage({
    required int offset,
    int limit = 50,
  }) async {
    final rows = await _client
        .from('audit_log')
        .select()
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
    return (rows as List)
        .map((r) => AuditLogEntry.fromMap(r as Map<String, dynamic>))
        .toList();
  }
}
