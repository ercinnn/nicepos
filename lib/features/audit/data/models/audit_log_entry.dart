/// Bir denetim kaydı satırı (`audit_log` tablosu, 0044 migration) — kalıcı/
/// geri alınamaz işlemler için kim-ne-zaman-ne kaydı. v1 kapsamı yalnız
/// "Satışı Sil" — bkz. `AuditLogRepository.log` çağrı noktaları.
class AuditLogEntry {
  final String id;
  final String? actorEmail;
  final String action;
  final String entityType;
  final String? entityId;
  final String summary;
  final DateTime createdAt;

  const AuditLogEntry({
    required this.id,
    this.actorEmail,
    required this.action,
    required this.entityType,
    this.entityId,
    required this.summary,
    required this.createdAt,
  });

  factory AuditLogEntry.fromMap(Map<String, dynamic> map) => AuditLogEntry(
        id: map['id'] as String,
        actorEmail: map['actor_email'] as String?,
        action: map['action'] as String,
        entityType: map['entity_type'] as String,
        entityId: map['entity_id'] as String?,
        summary: map['summary'] as String,
        createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
      );
}
