import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_colors.dart';

/// Owner/admin'in personel davet kodu ürettiği diyalog. Kod, `create_tenant_invite`
/// RPC'siyle (bkz. 0041 migration) üretilir — e-posta gönderimi YOK, kod elle
/// (WhatsApp vb.) iletilir; davet edilen kişi Kayıt Ol ekranında "Davet Kodum
/// Var" seçeneğiyle bu kodu girer.
Future<void> showStaffInviteDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => const _StaffInviteDialog(),
  );
}

class _StaffInviteDialog extends StatefulWidget {
  const _StaffInviteDialog();

  @override
  State<_StaffInviteDialog> createState() => _StaffInviteDialogState();
}

class _StaffInviteDialogState extends State<_StaffInviteDialog> {
  String _role = 'staff';
  bool _loading = false;
  String? _error;
  String? _generatedCode;

  Future<void> _generate() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await Supabase.instance.client
          .rpc('create_tenant_invite', params: {'p_role': _role});
      final row = result as Map<String, dynamic>;
      setState(() => _generatedCode = row['code'] as String);
    } on PostgrestException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Kod üretilemedi: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Personel Davet Et'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Yeni personelin kayıt sırasında gireceği tek kullanımlık bir kod üretilir.'),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _role,
              decoration: const InputDecoration(labelText: 'Rol'),
              items: const [
                DropdownMenuItem(value: 'staff', child: Text('Personel (staff)')),
                DropdownMenuItem(value: 'admin', child: Text('Yönetici (admin)')),
              ],
              onChanged: _generatedCode == null
                  ? (v) => setState(() => _role = v ?? 'staff')
                  : null,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: AppColors.danger)),
            ],
            if (_generatedCode != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.goldBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.goldBorder),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _generatedCode!,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 18),
                      tooltip: 'Kopyala',
                      onPressed: () =>
                          Clipboard.setData(ClipboardData(text: _generatedCode!)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Bu kodu personelinize iletin — Kayıt Ol ekranında "Davet Kodum Var" '
                'seçeneğiyle girip hesap oluşturabilirler. Kod 7 gün geçerlidir.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Kapat'),
        ),
        if (_generatedCode == null)
          ElevatedButton(
            onPressed: _loading ? null : _generate,
            child: _loading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Kod Oluştur'),
          ),
      ],
    );
  }
}
