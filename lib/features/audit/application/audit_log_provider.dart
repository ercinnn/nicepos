import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/models/audit_log_entry.dart';
import '../data/repositories/audit_log_repository.dart';

part 'audit_log_provider.g.dart';

const int auditLogPageSize = 50;

@riverpod
AuditLogRepository auditLogRepository(AuditLogRepositoryRef ref) =>
    AuditLogRepository();

/// [page] (0 = ilk sayfa) için denetim kaydı listesi — Dashboard/Görevler
/// provider'larıyla AYNI KARAR: autoDispose, sayfaya her dönüşte taze sorgu.
@riverpod
Future<List<AuditLogEntry>> auditLogPage(AuditLogPageRef ref, int page) {
  final repo = ref.watch(auditLogRepositoryProvider);
  return repo.fetchPage(offset: page * auditLogPageSize, limit: auditLogPageSize);
}
