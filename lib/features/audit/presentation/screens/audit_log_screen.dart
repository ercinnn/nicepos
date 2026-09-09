import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/utils/formatters.dart';
import '../../../auth/application/auth_provider.dart';
import '../../application/audit_log_provider.dart';
import '../../data/models/audit_log_entry.dart';

/// Denetim Kaydı — kalıcı/geri alınamaz işlemlerin (v1: yalnız "Satışı Sil")
/// kim-ne-zaman-ne kaydı. Menüden zaten owner/admin'e daraltılır (bkz.
/// app_scaffold.dart `_NavItem.ownerOrAdminOnly`); bu ekran, Kasa ile AYNI
/// desende, doğrudan URL'e karşı ikinci savunma katmanını burada tutar.
class AuditLogScreen extends ConsumerStatefulWidget {
  const AuditLogScreen({super.key});

  @override
  ConsumerState<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends ConsumerState<AuditLogScreen> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final membership = ref.watch(currentMembershipProvider).valueOrNull;
    if (membership != null && !membership.isOwnerOrAdmin) {
      return const _AuditLogAccessDenied();
    }

    final entriesAsync = ref.watch(auditLogPageProvider(_page));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Denetim Kaydı', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSizes.space4),
        const Text(
          'Kalıcı/geri alınamaz işlemlerin kim-ne-zaman-ne kaydı (ör. Satışı Sil).',
          style: TextStyle(fontSize: 13, color: AppColors.textMuted),
        ),
        const SizedBox(height: AppSizes.space16),
        Expanded(
          child: entriesAsync.when(
            data: (entries) => entries.isEmpty && _page == 0
                ? const _EmptyState()
                : _AuditLogList(entries: entries),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, s) => Center(
              child: Text(
                // Migration henüz uygulanmadıysa (audit_log tablosu yok)
                // burası düşer — anlaşılır bir mesajla açıklanır.
                'Denetim kaydı yüklenemedi: $e',
                style: const TextStyle(color: AppColors.danger),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSizes.space8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: _page > 0 ? () => setState(() => _page--) : null,
              icon: const Icon(Icons.chevron_left),
              label: const Text('Önceki'),
            ),
            const SizedBox(width: AppSizes.space12),
            Text('Sayfa ${_page + 1}',
                style: const TextStyle(color: AppColors.textMuted)),
            const SizedBox(width: AppSizes.space12),
            OutlinedButton.icon(
              onPressed: entriesAsync.valueOrNull?.length == auditLogPageSize
                  ? () => setState(() => _page++)
                  : null,
              icon: const Icon(Icons.chevron_right),
              label: const Text('Sonraki'),
            ),
          ],
        ),
      ],
    );
  }
}

class _AuditLogList extends StatelessWidget {
  final List<AuditLogEntry> entries;

  const _AuditLogList({required this.entries});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppSizes.cardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: ListView.separated(
        itemCount: entries.length,
        separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.divider),
        itemBuilder: (context, i) {
          final e = entries[i];
          return ListTile(
            leading: const Icon(Icons.history, color: AppColors.textMuted, size: 20),
            title: Text(e.summary, style: const TextStyle(fontSize: 13.5)),
            subtitle: Text(
              '${e.actorEmail ?? 'bilinmeyen kullanıcı'} · ${formatDateTime(e.createdAt)}',
              style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
            ),
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(AppSizes.space24),
        child: Text(
          'Henüz bir kayıt yok. Kalıcı bir işlem (ör. Satışı Sil) yapıldığında burada görünür.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: AppColors.textMuted),
        ),
      ),
    );
  }
}

class _AuditLogAccessDenied extends StatelessWidget {
  const _AuditLogAccessDenied();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.space24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 40, color: AppColors.textMuted),
            const SizedBox(height: AppSizes.space12),
            const Text(
              'Bu ekrana erişim yetkiniz yok',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSizes.space4),
            const Text(
              'Denetim Kaydı yalnız işletme sahibi/yöneticisi tarafından görüntülenebilir.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
