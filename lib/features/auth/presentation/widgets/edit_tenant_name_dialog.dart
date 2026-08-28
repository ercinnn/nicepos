import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_colors.dart';

/// Owner/admin'in kendi kiracısının (işletme) adını değiştirdiği diyalog —
/// `update_tenant_name` RPC'si (bkz. 0042 migration). Uygulama genelinde
/// "NicePOS" yerine gösterilen isim budur (bkz. app_scaffold.dart,
/// `currentTenantProvider`).
Future<void> showEditTenantNameDialog(BuildContext context, {required String currentName}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => _EditTenantNameDialog(currentName: currentName),
  );
}

class _EditTenantNameDialog extends StatefulWidget {
  final String currentName;
  const _EditTenantNameDialog({required this.currentName});

  @override
  State<_EditTenantNameDialog> createState() => _EditTenantNameDialogState();
}

class _EditTenantNameDialogState extends State<_EditTenantNameDialog> {
  late final _controller = TextEditingController(text: widget.currentName);
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'İşletme adı boş olamaz');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.rpc('update_tenant_name', params: {'p_name': name});
      if (mounted) Navigator.of(context).pop();
    } on PostgrestException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Kaydedilemedi: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('İşletme Adını Düzenle'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'İşletme / Mağaza Adı'),
              onSubmitted: (_) => _save(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: AppColors.danger)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('İptal'),
        ),
        ElevatedButton(
          onPressed: _loading ? null : _save,
          child: _loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Kaydet'),
        ),
      ],
    );
  }
}
